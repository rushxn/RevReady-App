import UIKit
import Foundation

class AnthropicService {
    static let apiKey: String = {
        if let key = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String,
           !key.isEmpty, key != "paste_your_key_here" { return key }
        return "YOUR_API_KEY_HERE"
    }()
    static let endpoint = "https://api.anthropic.com/v1/messages"
    static let modelChain = ["claude-haiku-4-5", "claude-sonnet-4-6", "claude-opus-4-5"]
    static let maxRetriesPerModel = 3
    static let baseDelaySecs = 1.5

    // MARK: - Visual scan
    static func analyzeBike(
        photos: [CapturedPhoto], bikeModel: String,
        progressCallback: @escaping (Int) -> Void,
        retryCallback: @escaping (String, Int, Double) -> Void = { _,_,_ in }
    ) async throws -> DiagnosticResult {
        progressCallback(0)
        var blocks: [[String: Any]] = []
        for (i, p) in photos.enumerated() {
            // Anthropic API hard limit: 5MB per image (base64 encoded)
            // base64 is ~33% larger than raw, so target 3.5MB raw to be safe
            let targetBytes = 3_500_000
            var imageData: Data?
            var image = p.image

            // First try downscaling if image is very large
            let maxDimension: CGFloat = 2048
            let size = image.size
            if size.width > maxDimension || size.height > maxDimension {
                let scale = maxDimension / max(size.width, size.height)
                let newSize = CGSize(width: size.width * scale, height: size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                if let resized = UIGraphicsGetImageFromCurrentImageContext() { image = resized }
                UIGraphicsEndImageContext()
            }

            // Then compress until under limit
            for quality in [0.8, 0.6, 0.4, 0.2] {
                if let d = image.jpegData(compressionQuality: quality) {
                    if d.count <= targetBytes || quality == 0.2 {
                        imageData = d
                        break
                    }
                }
            }
            guard let d = imageData else { continue }
            blocks.append(["type":"image","source":["type":"base64","media_type":"image/jpeg","data":d.base64EncodedString()]])
            progressCallback(Int(Double(i+1)/Double(photos.count)*25))
        }

        // VALIDATION: Check if images are actually motorcycle/bike related
        progressCallback(28)
        if !blocks.isEmpty {
            try await validateBikeImages(blocks: blocks)
        }

        progressCallback(35)
        let partList = photos.map { $0.part.rawValue }.joined(separator: ", ")
        blocks.append(["type":"text","text":visualPrompt(bike: bikeModel, parts: partList, count: photos.count)])
        return try await callAPI(blocks: blocks, progressCallback: progressCallback, retryCallback: retryCallback, maxTokens: 1500)
    }

    // Quick validation call — checks if image shows motorcycle/bike parts
    private static func validateBikeImages(blocks: [[String: Any]]) async throws {
        var validationBlocks = blocks
        validationBlocks.append([
            "type": "text",
            "text": """
            Look at the image(s). Answer with ONLY one of these exact responses:
            - "VALID" if the image shows a motorcycle, dirtbike, ATV, or any motorcycle component (engine, chain, tire, fork, exhaust, frame, suspension, brake, sprocket, wheel, handlebars, etc.)
            - "INVALID: [reason]" if the image does NOT show any motorcycle or motorcycle part (e.g. "INVALID: shows a car", "INVALID: shows a person", "INVALID: shows food")
            Nothing else. No explanation. Just VALID or INVALID: reason.
            """
        ])
        guard let url = URL(string: endpoint) else { throw AnthropicError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": modelChain[0],
            "max_tokens": 50,
            "messages": [["role": "user", "content": validationBlocks]]
        ])
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else { return } // if validation fails, proceed anyway

        let result = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if result.hasPrefix("INVALID") {
            let reason = text.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            let msg = reason.isEmpty
                ? "This doesn't look like a motorcycle or bike part. Please take a photo of your bike and try again."
                : "This image doesn't appear to show a motorcycle or bike part (\(reason)). Please submit a photo of your bike."
            throw AnthropicError.notBike(msg)
        }
    }

    // MARK: - Symptom diagnosis
    static func diagnoseSymptom(
        symptom: String, bikeModel: String, additionalContext: String,
        progressCallback: @escaping (Int) -> Void
    ) async throws -> SymptomDiagnosisResult {
        progressCallback(10)
        let prompt = symptomPrompt(symptom: symptom, bike: bikeModel, context: additionalContext)
        let blocks: [[String: Any]] = [["type":"text","text":prompt]]
        let raw = try await callAPIRaw(blocks: blocks, progressCallback: progressCallback, maxTokens: 1500)
        progressCallback(95)
        return try parseSymptomResult(raw)
    }

    // MARK: - Chat mechanic
    static func chatMechanic(
        messages: [[String: String]], bikeModel: String
    ) async throws -> String {
        let system = "You are an expert dirtbike mechanic with 20+ years experience specializing in \(bikeModel). Give concise, practical advice. Ask clarifying questions when needed. Be specific with part names, measurements, and procedures."
        guard let url = URL(string: endpoint) else { throw AnthropicError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": modelChain[0], "max_tokens": 800,
            "system": system, "messages": messages
        ])
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
              let content = json["content"] as? [[String:Any]],
              let text = content.first?["text"] as? String else { throw AnthropicError.parseError("Bad response") }
        return text
    }

    // MARK: - Core API call returning DiagnosticResult
    private static func callAPI(
        blocks: [[String: Any]], progressCallback: @escaping (Int) -> Void,
        retryCallback: @escaping (String, Int, Double) -> Void, maxTokens: Int
    ) async throws -> DiagnosticResult {
        let raw = try await callAPIRaw(blocks: blocks, progressCallback: progressCallback,
                                       retryCallback: retryCallback, maxTokens: maxTokens)
        return try parseDiagnosticResult(raw)
    }

    private static func callAPIRaw(
        blocks: [[String: Any]], progressCallback: @escaping (Int) -> Void,
        retryCallback: @escaping (String, Int, Double) -> Void = { _,_,_ in }, maxTokens: Int
    ) async throws -> String {
        var lastErr: Error = AnthropicError.unknown
        for model in modelChain {
            let body: [String: Any] = ["model": model, "max_tokens": maxTokens,
                                        "messages": [["role": "user", "content": blocks]]]
            for attempt in 0..<maxRetriesPerModel {
                do { return try await performRaw(body: body, progressCallback: progressCallback) }
                catch AnthropicError.overloaded {
                    let delay = baseDelaySecs * pow(2.0, Double(attempt))
                    if maxRetriesPerModel - attempt - 1 > 0 {
                        retryCallback(model, attempt, delay)
                        progressCallback(50 + attempt * 3)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        lastErr = AnthropicError.overloaded
                    } else { break }
                } catch { throw error }
            }
        }
        throw lastErr
    }

    private static func performRaw(body: [String: Any], progressCallback: @escaping (Int) -> Void) async throws -> String {
        guard let url = URL(string: endpoint) else { throw AnthropicError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 90
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        progressCallback(65)

        // Slow connection detection — warn after 15s, timeout at 90s
        let slowWarningTask = Task {
            try await Task.sleep(nanoseconds: 15_000_000_000)
            progressCallback(-1) // special code for slow connection warning
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        slowWarningTask.cancel()

        progressCallback(85)
        guard let http = response as? HTTPURLResponse else { throw AnthropicError.apiError("No response") }
        if http.statusCode != 200 {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String:Any])
                .flatMap { $0["error"] as? [String:Any] }.flatMap { $0["message"] as? String } ?? "HTTP \(http.statusCode)"
            if http.statusCode == 529 || msg.lowercased().contains("overload") { throw AnthropicError.overloaded }
            if http.statusCode == 401 { throw AnthropicError.apiError("Invalid API key — open AnthropicService.swift and replace YOUR_API_KEY_HERE") }
            throw AnthropicError.apiError(msg)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
              let blocks = json["content"] as? [[String:Any]],
              let text = blocks.first?["text"] as? String
        else { throw AnthropicError.parseError("Unexpected format") }
        progressCallback(95)
        return text
    }

    // MARK: - Prompts
    private static func visualPrompt(bike: String, parts: String, count: Int) -> String {
        """
        You are a professional dirtbike mechanic with 20+ years experience doing a comprehensive visual inspection of a \(bike).
        You have \(count) photo(s) showing: \(parts).

        STEP 1 — COMPREHENSIVE VISUAL SCAN
        Examine every pixel. Apply ALL of the following inspection criteria to every visible component. Flag subtle issues — not just catastrophic ones. A trained mechanic notices small things.

        ── DRIVE CHAIN ──
        - SLACK: Any droop or catenary curve between sprockets = excess slack. Even subtle looseness = flag "Chain slack"
        - RUST: Any brown/orange on links, pins, rollers, or side plates. Light surface rust = Low. Heavy rust/pitting = Medium/High
        - KINKS: Any link that looks stiff, bent, or doesn't follow the curve of the others
        - O-RINGS: Missing, cracked, or extruded o-rings visible between side plates
        - WEAR: Side plates look thin or narrowed. Rollers look flat/oval not round. Chain looks stretched
        - MASTER LINK: Clip present, facing correct direction (open end away from travel direction)
        - LUBE: Chain looks dry, white/grey residue = old dried lube. No lube visible = flag it

        ── CHAIN SLIDER & GUIDE ──
        - SWINGARM SLIDER: Deep grooves worn through the rubber/plastic slider on the swingarm = chain eating into metal. Flag immediately
        - CHAIN GUIDE: Plastic guide beneath rear sprocket — deep grooves, cracks, missing sections = High severity
        - Any metal-on-metal contact marks on swingarm from chain contact

        ── SPROCKETS ──
        - SHARK FIN TEETH: Teeth should be symmetrical triangles. Hooked, pointed, or asymmetric teeth = worn sprocket
        - MISSING TEETH: Any gaps in the tooth pattern
        - EDGE WEAR: Teeth worn more on one side
        - REAR SPROCKET: Check for cupping — concave wear pattern on tooth faces

        ── FORK SEALS & SUSPENSION ──
        - FORK SEAL LEAKS: Oil residue, wet streaks, or staining below the dust seal/wiper on fork tubes. Even a small oil film = flag "Leaking fork seal"
        - FORK TUBE CONDITION: Scratches, pitting, corrosion, or nicks on chrome/anodized surface — these destroy seals
        - FORK TUBE STRAIGHTNESS: Any visible bend or kink
        - REAR SHOCK: Oil residue around shaft seal, blown/collapsed shock (bike sits low at rear)
        - LINKAGE: Corrosion or damage on suspension linkage bearings

        ── COOLANT SYSTEM ──
        - COOLANT LEAKS: White crusty residue, green/orange staining around radiator, hose connections, water pump, or cylinder head = coolant leak
        - RADIATOR: Bent fins, cracks, any staining around seams
        - HOSES: Cracking, bulging, soft spots, clamp corrosion
        - OVERFLOW BOTTLE: Level visible? Discolored coolant?

        ── ENGINE OIL ──
        - OIL LEAKS: Dark brown/black staining around crankcase seams, base gasket, valve cover, oil filter, drain plug
        - OILY EXHAUST RESIDUE: Black oily buildup where header meets cylinder = burning oil, possible ring wear or valve guide seals
        - CRANKCASE CONDITION: Any weeping or seepage around case bolts

        ── EXHAUST ──
        - HEADER PIPE: Blue heat discoloration normal. Black sooty residue at joint = exhaust leak. Dents reduce flow
        - SILENCER: Rust through, dents, loose packing (rattling sound indicator), mounting brackets cracked
        - EXHAUST GASKET: White powdery residue or carbon buildup at header-to-cylinder joint = blown gasket

        ── BRAKES ──
        - BRAKE PADS: Visible pad thickness through caliper window or between rotor and caliper. Thin = flag
        - ROTOR: Grooves, scoring, hot spots (blue discoloration), warping, cracks near mounting holes
        - BRAKE FLUID RESERVOIR: Cloudy, dark brown, or opaque fluid visible through reservoir window = contaminated. Should be clear/light yellow
        - BRAKE LINES: Cracking, abrasion, any fluid weeping at banjo bolts

        ── CLUTCH ──
        - CLUTCH FLUID RESERVOIR (hydraulic): Cloudy, dark, discolored fluid = contaminated. Reservoir window should be clear
        - CLUTCH LEVER: Cracked, bent, pivot bolt missing/loose
        - CLUTCH CABLE (if cable operated): Fraying at ends, kinking, lack of lube

        ── TIRES & WHEELS ──
        - KNOB CONDITION: Knobs torn, missing, or rounded flat = worn tire
        - TIRE CUPPING: Uneven wear — scalloped/cupped pattern on knobs or center = alignment or pressure issue
        - SIDEWALL: Cracks, cuts, bulges, or embedded debris
        - RIM CONDITION: Dents, cracks, out-of-round
        - SPOKES: Count visible spokes for missing ones. Loose spokes cause vibration and rim failure
        - SPOKE TENSION: Any spokes visibly looser than others (different angle at nipple)
        - NIPPLES: Corroded or rounded nipple heads

        ── FRAME & WELDS ──
        - CRACKS AROUND WELDS: Hairline cracks radiating from weld points on frame — especially at steering head, swingarm pivot, footpeg mounts, subframe junction
        - FRAME TUBES: Dents, bends, or deformation
        - SUBFRAME: Cracks at junction with main frame, bent tubes
        - FOOTPEG MOUNTS: Cracked welds from hard landings

        ── CONTROLS & ERGONOMICS ──
        - HANDLEBARS: Bent, cracked clamps, bar end missing
        - LEVERS: Cracked, bent, pivot worn
        - GRIPS: Torn, slipping, missing lock wire on throttle side
        - THROTTLE: Visible freeplay, cable routing looks kinked
        - FOOTPEGS: Bent, missing teeth, spring broken (peg doesn't spring back)

        ── AIR FILTER & INTAKE ──
        - AIR FILTER: Dirty, torn, oil-saturated if visible through airbox
        - AIRBOX BOOT: Cracks, tears, loose clamps at carb/TB connection

        ── FASTENERS & HARDWARE ──
        - MISSING BOLTS: Any obvious missing fasteners on engine cases, bodywork, frame
        - STRIPPED HEADS: Rounded bolt heads indicate over-torquing or previous struggle
        - CORROSION ON BOLTS: Surface rust on exposed fasteners

        STEP 2 — SUBTLE ISSUE MANDATE
        You MUST flag subtle issues. Examples of what to catch:
        - Chain looks slightly loose but not extremely = "Chain slack — Low"
        - Light rust on chain = "Chain surface rust — Low"
        - Fork tube has a small scratch = "Fork tube scratch — Low"
        - Brake fluid looks slightly dark = "Brake fluid contamination — Low"
        - Grooves in chain slider even if bike still rideable = "Chain slider wear — Medium"
        - Any asymmetry or abnormality in any component = flag it
        Do NOT only flag obvious failures. Flag anything a mechanic would note.

        STEP 3 — SCORING
        Start at 100. Deduct per finding:
          High severity: -15 to -25
          Medium severity: -8 to -14
          Low severity: -2 to -7
          Poor photo quality penalty: -5 to -10
        Clean bike with no issues = 90-100. Multiple issues = proportionally lower. Do NOT default to 70-75.

        STEP 4 — Output ONLY this JSON. No markdown, no preamble, no explanation:
        {
          "healthScore": <integer 0-100>,
          "summary": "<2-3 specific sentences about what you found — name the actual issues seen>",
          "urgency": "<Ride now | Ride with caution | Do not ride>",
          "photoQuality": "<Good | Limited | Poor>",
          "findings": [
            {
              "name": "<specific issue name — e.g. 'Chain slack', 'Leaking fork seal', 'Worn chain slider', 'Dark brake fluid'>",
              "part": "<part name>",
              "severity": "<High | Medium | Low>",
              "description": "<what you see in the photo and the mechanical consequence>",
              "action": "<specific repair step and time estimate>",
              "diyCost": "<cost range string or null>",
              "shopCost": "<cost range string or null>",
              "canDIY": <true or false>
            }
          ]
        }

        ABSOLUTE RULES:
        - findings = [] ONLY if you genuinely see zero issues
        - If chain is visible, ALWAYS assess slack, rust, wear, and slider
        - If fork tubes visible, ALWAYS check for seal oil and tube condition
        - canDIY = boolean only, never string
        - diyCost and shopCost = strings or null, never omitted
        - Flag subtle real issues — never invent issues not visible
        """
    }

    private static func symptomPrompt(symptom: String, bike: String, context: String) -> String {
        """
        You are an expert dirtbike mechanic. A \(bike) has this symptom: "\(symptom)". Additional context: "\(context)".
        Return ONLY valid JSON with probable causes ranked by likelihood:
        {"symptom":"\(symptom)","immediateAction":"What to do right now.","safeToRide":false,"causes":[{"cause":"Clogged pilot jet","likelihood":70,"description":"Detail.","difficulty":"Easy","estimatedCost":"$5–20","toolsNeeded":["Carb tool","Spray cleaner"],"safeToRide":true}]}
        likelihood sums to 100. difficulty: "Easy"|"Moderate"|"Hard"|"Expert". At least 3 causes. Order by likelihood desc.
        """
    }

    // MARK: - Parsers
    private static func parseDiagnosticResult(_ raw: String) throws -> DiagnosticResult {
        try decode(raw, as: DiagnosticResult.self)
    }
    private static func parseSymptomResult(_ raw: String) throws -> SymptomDiagnosisResult {
        try decode(raw, as: SymptomDiagnosisResult.self)
    }
    private static func decode<T: Decodable>(_ raw: String, as type: T.Type) throws -> T {
        // Extract JSON object — find first { and last } to handle preamble/postamble text
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown fences anywhere in the string
        s = s.replacingOccurrences(of: "```json", with: "")
        s = s.replacingOccurrences(of: "```", with: "")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract just the JSON object — from first { to last }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            s = String(s[start...end])
        }

        guard let d = s.data(using: .utf8) else {
            throw AnthropicError.parseError("UTF-8 encoding failed")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: d)
        } catch {
            // Log the raw response to help debug future issues
            let preview = String(s.prefix(300))
            throw AnthropicError.parseError("JSON decode failed: \(error.localizedDescription)\n\nResponse: \(preview)")
        }
    }
}

enum AnthropicError: LocalizedError {
    case invalidURL, overloaded, apiError(String), parseError(String), unknown
    case notBike(String)      // image doesn't appear to be a bike/part
    case slowConnection       // request taking unusually long
    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid API URL."
        case .overloaded:       return "All Claude models are overloaded. Wait 1–2 minutes and try again."
        case .apiError(let m):  return m
        case .parseError(let m):return "Parse error: \(m)"
        case .unknown:          return "Unknown error. Please try again."
        case .notBike(let m):   return m
        case .slowConnection:   return "Your connection is slow — results may take longer than usual. Please wait."
        }
    }
}
