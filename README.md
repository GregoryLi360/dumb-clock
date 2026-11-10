<p align="center"><img src="assets/AppIcon.png" width="128" alt="stopwatch icon"></p>

<h1 align="center">stopwatch</h1>
<p align="center">A little time. Nothing else.</p>

A small, transparent stopwatch and countdown timer for macOS. Native Swift and AppKit. No accounts, subscriptions, analytics, network access, or runtime dependencies.

## Install

Download the latest **stopwatch DMG** from [Releases](https://github.com/GregoryLi360/dumb-clock/releases), open it, and drag **stopwatch** into **Applications**.

**Requires macOS 13 Ventura or later.** The app runs natively on Apple Silicon and Intel Macs.

Releases are ad-hoc signed, **not Apple-notarized**. If macOS blocks the downloaded app, use **System Settings → Privacy & Security → Open Anyway** after attempting to open it. No system-wide security changes are needed.

## Use

- **Stopwatch / Timer** switches modes. Each keeps its own time.
- **Play / Pause** starts or pauses. **Reset** stops and resets the selected mode.
- **Clock / #** switches between analog and digital views. Both modes have hour, minute, and second hands plus an `HH:MM:SS` display.
- **Timer editing:** click a digit while stopped or paused. The block highlight shows exactly what typing will replace. Left/right skip colons; deletion zeroes digits without removing positions. Up/down adjusts the selected unit. Selecting all highlights digits only.
- **Drag a timer hand** to set its unit. Click elsewhere on the dial to set minutes. Dragging across 12 carries into the next unit. Editing is disabled while running.
- **Pin** keeps the window on top; unpin restores normal window stacking. Hovering a pinned icon shows a slash; an unpinned icon stays outlined and brightens.
- **×** hides the window. Use the menu bar icon to show it again or quit.

| Shortcut | Action |
| --- | --- |
| Space | Start / pause; silence a finished timer |
| Return | Apply a duration and start |
| R | Reset |
| ⌘Q | Quit |

At zero, the countdown shows its window and repeats the system Glass sound until stopped. Hidden timers continue running. Time includes sleep, but an alert waits until the Mac wakes. Quitting clears active sessions. Mode, view, duration, pin state, and window placement are remembered.

Starting, pausing, resuming, and resetting keep the layout fixed. Switching digital/analog view intentionally changes the window height.

## Build

Install Apple's Command Line Tools or Xcode, then:

```sh
./scripts/test.sh
./build.sh
open "build/stopwatch.app"
```

`build.sh` creates a universal app bundle. To create the release installer:

```sh
./scripts/package.sh
```

Packaging uses `dmgbuild`; see the script for its pinned development dependency. The app itself has no third-party dependencies. `./scripts/render-assets.sh` regenerates the icon and installer artwork using native AppKit tools.

An optional tag-triggered release workflow is included at `docs/release-workflow.yml.example`. It is a template, not an active GitHub Action. Releases can be built locally with the scripts above and uploaded using `gh release create`. Build output belongs in Releases, not Git history.

## License

[MIT](LICENSE).
