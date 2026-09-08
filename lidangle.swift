import Foundation
import IOKit.hid

func findHIDDevice(usagePage: Int, usage: Int) -> IOHIDDevice? {
    guard let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone)) as IOHIDManager? else {
        return nil
    }
    let matching: [String: Any] = [
        kIOHIDDeviceUsagePageKey as String: usagePage,
        kIOHIDDeviceUsageKey as String: usage,
    ]
    IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
        return nil
    }
    guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, let device = deviceSet.first else {
        return nil
    }
    return device
}

guard let device = findHIDDevice(usagePage: 0x0020, usage: 0x008A) else {
    FileHandle.standardError.write("no lid angle sensor found\n".data(using: .utf8)!)
    exit(1)
}

guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
    FileHandle.standardError.write("failed to open device\n".data(using: .utf8)!)
    exit(1)
}

var report = [UInt8](repeating: 0, count: 8)
var length = CFIndex(report.count)
let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)

guard result == kIOReturnSuccess, length >= 3 else {
    FileHandle.standardError.write("failed to read report\n".data(using: .utf8)!)
    exit(1)
}

let rawValue = UInt16(report[2]) << 8 | UInt16(report[1])
print(rawValue)
