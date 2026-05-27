#!/usr/bin/env python3
"""
RevReady OBD2 Emulator — 2020 Honda CRF250R
Install: pip3 install pyobjc-framework-CoreBluetooth
Run:     python3 ~/obd_emulator.py
"""

import time, random, threading, objc
from Foundation import NSObject, NSRunLoop, NSDate, NSData, NSThread
import CoreBluetooth as CB

SERVICE_UUID = CB.CBUUID.UUIDWithString_("FFF0")
NOTIFY_UUID  = CB.CBUUID.UUIDWithString_("FFF1")
WRITE_UUID   = CB.CBUUID.UUIDWithString_("FFF2")

# Engine state
_rpm=1420; _coolant=25.0; _oil=22.0; _throttle=0.08
_battery=13.1; _seconds=int(47.3*3600); _tick=0
_notify_char=None

def engine_update():
    global _rpm,_coolant,_oil,_throttle,_battery,_seconds,_tick
    _tick+=1; _seconds+=1
    c=_tick%60
    t=0.08 if c<10 else 0.45 if c<16 else 0.72 if c<28 else 0.95 if c<32 else 0.55 if c<40 else 0.20 if c<46 else 0.08
    _throttle=max(0.05,min(1.0,_throttle+(t-_throttle)*0.3+random.uniform(-0.02,0.02)))
    tr=1420 if _throttle<0.12 else int(5800+_throttle*7200)
    _rpm=max(1380,min(13500,_rpm+int((min(13500,max(1380,tr))-_rpm)*0.25)+random.randint(-60,60)))
    wt=88.0+_rpm/13500.0*8
    if _coolant<wt: _coolant+=0.5
    _coolant=max(20,min(108,_coolant+random.uniform(-0.2,0.3)))
    _oil+=((_coolant+10)-_oil)*0.05
    _battery=max(12.0,min(14.8,_battery+random.uniform(-0.05,0.07)))

def engine_respond(cmd):
    cmd=cmd.strip().upper().replace('\r','').replace('\n','')
    if cmd in ('ATZ','ATE0','ATL0','ATSP0','ATH0'): return 'OK'
    if cmd=='ATRV': return f'{_battery:.1f}V'
    if cmd=='010C':
        v=int(_rpm*4); return f'41 0C {v>>8&0xFF:02X} {v&0xFF:02X}'
    if cmd=='0105': return f'41 05 {int(_coolant)+40:02X}'
    if cmd=='0111': return f'41 11 {int(_throttle*255):02X}'
    if cmd=='0142':
        v=int(_battery*1000); return f'41 42 {v>>8&0xFF:02X} {v&0xFF:02X}'
    if cmd=='015C': return f'41 5C {int(_oil)+40:02X}'
    if cmd=='011F': return f'41 1F {_seconds>>8&0xFF:02X} {_seconds&0xFF:02X}'
    return 'NO DATA'

class OBD2Delegate(NSObject):
    def init(self):
        self=objc.super(OBD2Delegate,self).init()
        return self

    def peripheralManagerDidUpdateState_(self,mgr):
        global _notify_char
        s={0:'unknown',1:'resetting',2:'unsupported',
           3:'unauthorized',4:'off',5:'on'}.get(mgr.state(),'?')
        print(f'\n  Bluetooth: {s}')
        if mgr.state()==5:
            nc=CB.CBMutableCharacteristic.alloc().initWithType_properties_value_permissions_(
                NOTIFY_UUID,CB.CBCharacteristicPropertyNotify,
                None,CB.CBAttributePermissionsReadable)
            _notify_char=nc
            wc=CB.CBMutableCharacteristic.alloc().initWithType_properties_value_permissions_(
                WRITE_UUID,
                CB.CBCharacteristicPropertyWrite|CB.CBCharacteristicPropertyWriteWithoutResponse,
                None,CB.CBAttributePermissionsWriteable)
            svc=CB.CBMutableService.alloc().initWithType_primary_(SERVICE_UUID,True)
            svc.setCharacteristics_([nc,wc])
            mgr.addService_(svc)
        elif mgr.state()==4:
            print('  Enable Bluetooth in System Settings')
        elif mgr.state()==3:
            print('  Allow Terminal Bluetooth: System Settings → Privacy → Bluetooth')

    def peripheralManager_didAddService_error_(self,mgr,svc,err):
        if err: print(f'  Error: {err}'); return
        mgr.startAdvertising_({
            CB.CBAdvertisementDataLocalNameKey:'RevReady-OBD2',
            CB.CBAdvertisementDataServiceUUIDsKey:[SERVICE_UUID]})

    def peripheralManagerDidStartAdvertising_error_(self,mgr,err):
        if err: print(f'  Ad error: {err}')
        else:
            print('  ✓ Broadcasting as RevReady-OBD2')
            print('  ✓ Open RevReady → Sensors → Scan → tap Rushans MacBook')
            print('-'*55)

    def peripheralManager_central_didSubscribeToCharacteristic_(self,mgr,central,char):
        print('\n  ✓ iPhone connected!')

    def peripheralManager_central_didUnsubscribeFromCharacteristic_(self,mgr,central,char):
        print('\n  iPhone disconnected')

    def peripheralManager_didReceiveWriteRequests_(self,mgr,reqs):
        for req in reqs:
            data=req.value()
            if data:
                cmd=bytes(data).decode('utf-8',errors='ignore').strip()
                resp=engine_respond(cmd)
                print(f'\n  ← {cmd:10s} → {resp}')
                rb=(resp+'\r\n>').encode('utf-8')
                ns=NSData.dataWithBytes_length_(rb,len(rb))
                if _notify_char is not None:
                    mgr.updateValue_forCharacteristic_onSubscribedCentrals_(
                        ns,_notify_char,None)
            mgr.respondToRequest_withResult_(req,0)

# Keep globals alive
_delegate=None
_manager=None

def run_ble():
    """Run BLE on its own thread with its own runloop"""
    global _delegate,_manager
    _delegate=OBD2Delegate.alloc().init()
    _manager=CB.CBPeripheralManager.alloc().initWithDelegate_queue_options_(
        _delegate,None,None)
    # Run this thread's runloop forever so callbacks fire
    while True:
        NSRunLoop.currentRunLoop().runUntilDate_(
            NSDate.dateWithTimeIntervalSinceNow_(0.05))

def engine_loop():
    while True:
        time.sleep(1); engine_update()
        print(f'\r  RPM:{_rpm:6d} | Coolant:{_coolant:.0f}°C | '
              f'Throttle:{_throttle*100:.0f}% | Batt:{_battery:.1f}V  ',
              end='',flush=True)

def main():
    print('='*55)
    print('  RevReady OBD2 Emulator — 2020 Honda CRF250R')
    print('='*55)
    print('  Initializing Bluetooth...')

    # BLE must run on main thread for CoreBluetooth on macOS
    threading.Thread(target=engine_loop,daemon=True).start()

    # Run BLE on main thread
    global _delegate,_manager
    _delegate=OBD2Delegate.alloc().init()
    _manager=CB.CBPeripheralManager.alloc().initWithDelegate_queue_options_(
        _delegate,None,None)

    try:
        while True:
            NSRunLoop.currentRunLoop().runUntilDate_(
                NSDate.dateWithTimeIntervalSinceNow_(0.05))
    except KeyboardInterrupt:
        print('\n\n  Stopped.')

if __name__=='__main__':
    main()
