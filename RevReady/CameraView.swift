import SwiftUI
import PhotosUI

struct CameraView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var showPicker   = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showTip      = true
    let max = 5

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(spacing: 0) {
                    partTabs
                    // FEATURE 1: Photo tip card
                    if showTip { tipCard }
                    if appState.capturedPhotos.isEmpty { dropZone } else { photoGrid; addMoreRow }
                    accuracyTip
                    if let err = appState.errorMessage { errorCard(err) }
                    analyzeBtn
                }
            }
        }
        .background(Color.motoBg.ignoresSafeArea())
        .photosPicker(isPresented: $showPicker, selection: $pickerItems,
                      maxSelectionCount: max - appState.capturedPhotos.count, matching: .images)
        .onChange(of: pickerItems) { _, items in Task { await loadPhotos(items) } }
        .onChange(of: appState.selectedPart) { _, _ in showTip = true }
    }

    // MARK: Nav
    var navBar: some View {
        HStack {
            Button { appState.navigate(to: .dashboard) } label: {
                Image(systemName: "arrow.left").font(.system(size: 16, weight: .bold)).foregroundColor(.motoText)
                    .frame(width: 36, height: 36).background(Color.motoCard).clipShape(Circle())
                    .overlay(Circle().stroke(Color.motoBorder, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Visual Scan").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(.white)
                Text(appState.selectedBikeString).font(.system(size: 11, design: .monospaced)).foregroundColor(.motoMuted)
            }.padding(.leading, 4)
            Spacer()
            Text("\(appState.capturedPhotos.count)/\(max)")
                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.motoOrange)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.motoOrange.opacity(0.1)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.motoOrange.opacity(0.3), lineWidth: 1))
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
    }

    // MARK: Part tabs
    var partTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BikePart.allCases, id: \.self) { part in
                    Button { withAnimation(.easeInOut(duration: 0.15)) { appState.selectedPart = part } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: part.icon).font(.system(size: 11, weight: .bold))
                            Text(part.rawValue).font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(appState.selectedPart == part ? .white : .motoMuted)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(appState.selectedPart == part ? Color.motoOrange : Color.motoCard)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke(appState.selectedPart == part ? Color.motoOrange : Color.motoBorder, lineWidth: 1))
                    }
                }
            }.padding(.horizontal, 16)
        }.padding(.bottom, 10)
    }

    // MARK: FEATURE 1 — Tip card
    var tipCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 18)).foregroundColor(.motoOrange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("Photo tip · \(appState.selectedPart.rawValue)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.motoOrange)
                Text(appState.selectedPart.photoTip)
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(.motoText).lineSpacing(3)
            }
            Spacer(minLength: 0)
            Button { withAnimation { showTip = false } } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundColor(.motoMuted)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.motoOrange.opacity(0.06)).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoOrange.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: Drop zone
    var dropZone: some View {
        Button { showPicker = true } label: {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.motoOrange.opacity(0.1)).frame(width: 72, height: 72)
                    Image(systemName: "camera.viewfinder").font(.system(size: 30)).foregroundColor(.motoOrange)
                }
                VStack(spacing: 6) {
                    Text("Photograph your \(appState.selectedPart.rawValue.lowercased())")
                        .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white).multilineTextAlignment(.center)
                    Text("Tap to choose from library")
                        .font(.system(size: 12, design: .monospaced)).foregroundColor(.motoMuted)
                    Text("Up to \(max) photos · JPG · PNG · HEIC")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoDim)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40)
            .background(Color.motoSurface).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(Color.motoBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
        }
        .padding(.horizontal, 16).padding(.bottom, 14)
    }

    var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(appState.capturedPhotos) { photo in
                PhotoThumbView(photo: photo) { appState.capturedPhotos.removeAll { $0.id == photo.id } }
            }
            if appState.capturedPhotos.count < max {
                Button { showPicker = true } label: {
                    RoundedRectangle(cornerRadius: 12).fill(Color.motoSurface)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Image(systemName: "plus").font(.system(size: 22)).foregroundColor(.motoDim))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.motoBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 3])))
                }
            }
        }.padding(.horizontal, 16).padding(.bottom, 10)
    }

    var addMoreRow: some View {
        HStack {
            Text("\(appState.capturedPhotos.count) photo\(appState.capturedPhotos.count != 1 ? "s" : "") selected")
                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
            Spacer()
            if appState.capturedPhotos.count < max {
                Button { showPicker = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("Add more").font(.system(size: 12, weight: .bold, design: .monospaced))
                    }.foregroundColor(.motoOrange)
                }
            }
        }.padding(.horizontal, 16).padding(.bottom, 14)
    }

    func errorCard(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Color(hex: "#ef4444"))
            Text(msg).font(.system(size: 12, design: .monospaced)).foregroundColor(Color(hex: "#ff6b6b"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#1a0a0a")).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#3a1a1a"), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    // MARK: Accuracy tip
    var accuracyTip: some View {
        let count = appState.capturedPhotos.count
        let tips: [(icon: String, text: String)] = [
            ("arrow.triangle.2.circlepath.camera", "Multiple angles = higher accuracy"),
            ("light.max", "Good lighting reveals leaks & cracks"),
            ("camera.macro", "Get close — zoom in on problem areas"),
            ("rectangle.3.group", "Cover engine, exhaust, chain & forks"),
        ]
        let highlighted = count == 0 ? tips :
                          count == 1 ? [tips[0], tips[1]] :
                          count == 2 ? [tips[0]] : []

        return Group {
            if count < 3 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 11)).foregroundColor(.motoOrange)
                        Text("FOR A MORE ACCURATE SCORE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.motoOrange)
                        Spacer()
                        // Score meter showing improvement potential
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(i < min(count + 1, 5) ? Color.motoOrange : Color.motoBorder)
                                    .frame(width: 10, height: 14)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(highlighted.isEmpty ? [tips[0]] : highlighted, id: \.text) { tip in
                            HStack(spacing: 8) {
                                Image(systemName: tip.icon)
                                    .font(.system(size: 12)).foregroundColor(.motoOrange)
                                    .frame(width: 20)
                                Text(tip.text)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.motoText)
                            }
                        }
                    }
                    // Photo count nudge
                    if count < 3 {
                        Text(count == 0 ? "Aim for 3–5 photos from different angles for best results." :
                             count == 1 ? "Good start — add \(3 - count) more photos from different angles." :
                                          "One more photo will improve accuracy.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.motoMuted)
                            .lineSpacing(2)
                    }
                }
                .padding(14)
                .background(Color.motoOrange.opacity(0.05))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.motoOrange.opacity(0.2), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
    }

    var analyzeBtn: some View {
        let ready = !appState.capturedPhotos.isEmpty
        return Button { Task { await appState.runAnalysis() } } label: {
            HStack(spacing: 10) {
                Image(systemName: "brain").font(.system(size: 17, weight: .bold))
                Text(ready
                     ? "Analyze \(appState.capturedPhotos.count) Photo\(appState.capturedPhotos.count != 1 ? "s" : "") with AI"
                     : "Add Photos to Analyze")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
            }
            .foregroundColor(ready ? .white : .motoMuted)
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(ready ? Color.motoOrange : Color.motoCard).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ready ? Color.clear : Color.motoBorder, lineWidth: 1))
        }
        .disabled(!ready).padding(.horizontal, 16).padding(.bottom, 40)
        .animation(.easeInOut(duration: 0.2), value: ready)
    }

    func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

            // Check raw file size — warn if over 10MB
            let tenMB = 10 * 1024 * 1024
            if data.count > tenMB {
                await MainActor.run {
                    appState.errorMessage = "Image is too large (\(data.count / (1024*1024))MB). Please use a photo under 10MB."
                }
                continue
            }

            guard let img = UIImage(data: data) else { continue }
            let photo = CapturedPhoto(image: img, part: appState.selectedPart)
            await MainActor.run {
                if appState.capturedPhotos.count < max {
                    appState.capturedPhotos.append(photo)
                    appState.errorMessage = nil
                }
            }
        }
        await MainActor.run { pickerItems = [] }
    }
}

struct PhotoThumbView: View {
    let photo: CapturedPhoto; let onRemove: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo.image).resizable().scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity).aspectRatio(1, contentMode: .fill)
                .clipped().cornerRadius(12)
            Text(photo.part.rawValue.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced)).foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.motoOrange.opacity(0.9)).cornerRadius(6).padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .black)).foregroundColor(.white)
                    .frame(width: 20, height: 20).background(Color.black.opacity(0.75)).clipShape(Circle())
            }.padding(5)
        }
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.motoOrange, lineWidth: 1.5))
    }
}

#Preview { CameraView().environmentObject(AppStateManager()) }
