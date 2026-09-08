import Cocoa

// Posts the Lock Screen keyboard shortcut (^⌘Q) via an in-process
// NSAppleScript that tells System Events to send the keystroke.
//
// An earlier version used CGEventPost directly, but events posted at the
// HID event tap (cghidEventTap) never reach WindowServer's lock shortcut
// handler, and events at the session tap (cgSessionEventTap) are silently
// dropped after the binary is rebuilt (macOS invalidates the Accessibility
// grant tied to the old code signature, yet AXIsProcessTrusted() still
// returns true, so the failure is invisible). System Events' keystroke
// command posts through the session event tap internally and reliably
// triggers the lock.
//
// The earlier osascript subprocess approach added 100-300ms of process
// spawn overhead. Running NSAppleScript in-process avoids the subprocess
// spawn; the remaining Apple Event IPC costs ~150ms, which is acceptable
// because the script triggers at 10% lid opening — well before clamshell
// sleep — giving the lock a comfortable head start.
//
// Requires Accessibility permission for THIS binary specifically (macOS
// ties the grant to the exact executable, not to the parent shell/terminal):
// System Settings -> Privacy & Security -> Accessibility -> add `locker`.

guard AXIsProcessTrusted() else {
    FileHandle.standardError.write("error: locker is not trusted for Accessibility. Add it under System Settings -> Privacy & Security -> Accessibility.\n".data(using: .utf8)!)
    exit(1)
}

let script = NSAppleScript(source: """
tell application "System Events" to keystroke "q" using {control down, command down}
""")
var error: NSDictionary?
script?.executeAndReturnError(&error)

if let error = error {
    FileHandle.standardError.write("error: AppleScript failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}