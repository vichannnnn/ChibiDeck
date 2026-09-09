import Foundation
import IOKit.hid
import PanelCore
import os

let touchLog = Logger(subsystem: "me.himaa.chibideck", category: "touch")

/// Plan 3 §5.1: one `IOHIDManager` matching the Edge's HID interfaces (vendor 0x27C0, product 0x0859), driven on
/// a private queue, opened with seize so macOS stops treating the touch surface as a mouse; falls back to a shared
/// open (taps then also move the cursor). Reports go through `TouchReportParser`; every `TouchEvent` reaches
/// `onEvent` on the reader's queue. `start`/`stop` are called on the main thread; the parser lives on the queue.
final class HIDTouchReader {
    enum Mode: Equatable {
        case seized
        case sharedCursor
        case failed(IOReturn)
    }

    private(set) var mode: Mode?
    /// `onEvent` is called on the reader's queue, never on the main thread; hop before touching the model.
    /// `onModeChange` is called synchronously from `start()`, so it runs on whatever thread called `start()`.
    var onEvent: (@Sendable (TouchEvent) -> Void)?
    var onModeChange: (@Sendable (Mode) -> Void)?

    private let queue = DispatchQueue(label: "me.himaa.chibideck.touch", qos: .userInteractive)
    private var manager: IOHIDManager?
    private let parser = TouchReportParser()

    func start() {
        guard manager == nil else { return }
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(m, [kIOHIDVendorIDKey: XeneonEdgeDevice.vendorID,
                                          kIOHIDProductIDKey: XeneonEdgeDevice.productID] as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputReportCallback(m, { context, result, _, _, reportID, report, length in
            guard result == kIOReturnSuccess, let context, length > 0 else { return }
            let reader = Unmanaged<HIDTouchReader>.fromOpaque(context).takeUnretainedValue()
            reader.handle(reportID: Int(reportID), bytes: Array(UnsafeBufferPointer(start: report, count: length)))
        }, context)
        // IOKit invokes the cancel handler after `IOHIDManagerCancel`; the closure keeps the manager alive until then.
        IOHIDManagerSetCancelHandler(m) { _ = m }
        IOHIDManagerSetDispatchQueue(m, queue)
        // Open BEFORE Activate: activation activates every already-present device, and Open then registers the
        // report callback on each one, which IOKit rejects with "Device has already been activated" (SIGTRAP).
        // A device that arrives later is registered before its own activation, so only the present-at-launch
        // case crashed. Verified on the Edge 2026-09-07.
        let seized = IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        let mode: Mode
        if seized == kIOReturnSuccess {
            mode = .seized
        } else {
            let plain = IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
            mode = plain == kIOReturnSuccess ? .sharedCursor : .failed(plain)
            touchLog.error("seize failed (\(seized)); plain open \(plain == kIOReturnSuccess ? "ok" : "failed (\(plain))", privacy: .public)")
        }
        IOHIDManagerActivate(m)
        manager = m
        self.mode = mode
        touchLog.info("touch reader started: \(String(describing: mode), privacy: .public)")
        onModeChange?(mode)
    }

    func stop() {
        guard let m = manager else { return }
        manager = nil
        mode = nil
        IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerCancel(m)
        queue.async { [parser] in parser.reset() }
        touchLog.info("touch reader stopped")
    }

    private func handle(reportID: Int, bytes: [UInt8]) {
        if let event = parser.parse(reportID: reportID, bytes: bytes, time: ProcessInfo.processInfo.systemUptime) {
            onEvent?(event)
        }
    }
}
