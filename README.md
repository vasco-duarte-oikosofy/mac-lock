# mac-lock

Locks your Mac's screen as soon as the lid is nearly closed — before macOS
puts the whole system to sleep.

## Why not just close the lid?

On Macs without an external display attached, closing the lid triggers
`AppleClamshellState` and macOS suspends the entire system almost
instantly. That's too fast for a simple polling script (or even a
kernel sleep-notification hook) to reliably lock the screen before the
process itself gets frozen. Waiting for the lid to be fully closed loses
the race.

This script sidesteps the race by watching the lid **angle** continuously
(not just open/closed) and locking the screen once the lid has closed
down to a configurable fraction of its fully-open angle — by default,
the last 30%, while it's still open enough that macOS hasn't started
suspending yet.

## Requirements

- A Mac with a lid angle sensor: MacBook Pro 16" (2019+, Intel) or any
  M-series MacBook Pro / MacBook Air (M2, 2022+). Desktop Macs and older
  MacBooks don't have this sensor.
- Xcode Command Line Tools (for `swiftc`) to build `lidangle` and `locker`.
- Accessibility permission granted to `locker` specifically (System
  Settings → Privacy & Security → Accessibility), since locking the
  screen posts the ⌃⌘Q keystroke via System Events. macOS ties this grant
  to the exact binary, not to the terminal app that launches it, so
  `locker` needs its own entry even if your terminal already has one.

## Setup

```sh
swiftc -O lidangle.swift -o lidangle
swiftc -O locker.swift -o locker
./mac-lock.sh
```

Grant Accessibility permission to `locker` when prompted (or add it
manually under System Settings → Privacy & Security → Accessibility —
you'll need to browse to the compiled `locker` binary), then re-run.

`locker` sends the ⌃⌘Q keystroke via an in-process `NSAppleScript` call
to System Events, rather than spawning `osascript` as a subprocess.
The subprocess approach adds 100-300ms of process-spawn overhead —
enough to lose the race against macOS's own clamshell-sleep transition
once the lid is nearly shut. Running `NSAppleScript` in-process avoids
the subprocess spawn; the remaining Apple Event IPC costs ~150ms, which
is acceptable because the script triggers at 30% lid opening — well
before clamshell sleep — giving the lock a comfortable head start.

An even earlier version used `CGEventPost` directly, but that proved
unreliable: events posted at the HID event tap (`cghidEventTap`) never
reach WindowServer's lock shortcut handler, and events at the session
tap (`cgSessionEventTap`) are silently dropped after the binary is
rebuilt (macOS invalidates the Accessibility grant tied to the old code
signature, yet `AXIsProcessTrusted()` still returns true, so the
failure is invisible). System Events' `keystroke` command posts through
the session event tap internally and reliably triggers the lock.

## Usage

```sh
./mac-lock.sh [poll_interval_seconds] [remaining_open_fraction]
```

- `poll_interval_seconds` — how often to sample the lid angle (default `0.2`)
- `remaining_open_fraction` — lock once the lid angle drops to this
  fraction of the fully-open baseline (default `0.30`, i.e. the last 30%
  of the closing motion)

The script tracks the widest angle it's seen as the "fully open"
baseline, so it adapts to how far you actually open the lid. It re-arms
once you reopen the lid past 40% of that baseline.

## Files

- `mac-lock.sh` — the watch loop
- `lidangle.swift` — reads the lid angle sensor via IOKit HID (usage
  page `0x0020`, usage `0x008A`) and prints the current angle in degrees
- `lidangle` — compiled binary (build it yourself; not committed, since
  it's a compiled artifact)
- `locker.swift` — posts the ⌃⌘Q lock-screen keystroke via in-process
  `NSAppleScript` (System Events `keystroke`)
- `locker` — compiled binary (build it yourself; not committed)

## Limitations

- Only works on Macs with the lid angle sensor listed above.
- Locking simulates the Lock Screen keyboard shortcut (⌃⌘Q) — if that
  shortcut has been remapped or disabled (e.g. by an MDM profile), this
  won't work.
