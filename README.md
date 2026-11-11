# Smart Island

A thin clock that sits right under the MacBook notch, so you can check the time while looking at the camera in Zoom.

- Shows only on the MacBook's built-in screen, never on an external monitor.
- Stays visible on every desktop and over full-screen apps.
- Merges into the notch: solid black across the menu bar, with a dark Liquid Glass strip below that fades out (switch to solid black with **Glass Style**).
- Clicks pass through to the window underneath; hold ⌘ and drag to move the island (⌘ double-click, or **Reset Position**, to snap it back).
- Menu bar icon (clock): Show Clock, 24-Hour Time, Show Seconds, Glass Style, Reset Position, Launch at Login, Quit.

## Requirements

- macOS 14 Sonoma or later
- Xcode 15+ or the Xcode Command Line Tools (`xcode-select --install`)

## Build and run

```sh
./scripts/build-app.sh            # builds "build/Smart Island.app"
./scripts/build-app.sh --install  # also copies it to /Applications and launches it
```

Launch at Login works best when the app is in `/Applications`, so use `--install` for everyday use.

For development you can also run `swift run`, or open `Package.swift` in Xcode and press Run. (Launch at Login only works from the built `.app`.)

## Tweaking the size

The strip's height, corner radii, glass tint and fade, font size, move modifier and fallback width are in `IslandMetrics` in `Sources/SmartIsland/ClockView.swift`.
