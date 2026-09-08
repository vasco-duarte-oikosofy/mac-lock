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
the last 10%, while it's still open enough that macOS hasn't started
suspending yet.

## Requirements

- A Mac with a lid angle sensor: MacBook Pro 16" (2019+, Intel) or any
  M-series MacBook Pro / MacBook Air (M2, 2022+). Desktop Macs and older
  MacBooks don't have this sensor.
- Xcode Command Line Tools (for `swiftc`) to build `lidangle`.
- Accessibility permission granted to whatever terminal app runs the
  script (System Settings → Privacy & Security → Accessibility), since
  locking the screen simulates the ⌃⌘Q keystroke via System Events.

## Setup

```sh
swiftc -O lidangle.swift -o lidangle
./mac-lock.sh
```

Grant Accessibility permission to your terminal app when prompted (or
add it manually under System Settings → Privacy & Security →
Accessibility), then re-run.

## Usage

```sh
./mac-lock.sh [poll_interval_seconds] [remaining_open_fraction]
```

- `poll_interval_seconds` — how often to sample the lid angle (default `0.2`)
- `remaining_open_fraction` — lock once the lid angle drops to this
  fraction of the fully-open baseline (default `0.10`, i.e. the last 10%
  of the closing motion)

The script tracks the widest angle it's seen as the "fully open"
baseline, so it adapts to how far you actually open the lid. It re-arms
once you reopen the lid past 20% of that baseline.

## Files

- `mac-lock.sh` — the watch loop
- `lidangle.swift` — reads the lid angle sensor via IOKit HID (usage
  page `0x0020`, usage `0x008A`) and prints the current angle in degrees
- `lidangle` — compiled binary (build it yourself; not committed, since
  it's a compiled artifact)

## Limitations

- Only works on Macs with the lid angle sensor listed above.
- Locking simulates the Lock Screen keyboard shortcut (⌃⌘Q) — if that
  shortcut has been remapped or disabled (e.g. by an MDM profile), this
  won't work.
