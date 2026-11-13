# AGENTS.md

Record Mode: a menu bar toggle that switches the main display to a lighter mode for screen recording and back. The Swift files in `mac/` are compiled together with `swiftc`; there is no package.

## Commands

- `./mac/build.sh`: `build/Record Mode.app`, ID `com.zazencodes.recordmode`, ad hoc signed. `./mac/install.sh`: replace `/Applications/Record Mode.app` and launch it.
- `open recordmode://on` and `open recordmode://off` switch the mode from scripts.

## Important Details

- Turning the mode on changes the display's resolution, rearranges Alex's windows and opens a Chrome window and an image. Ask before switching it to test something.
- `mac/InputLog.swift` is temporary. It logs mouse clicks, late pointer events, app switches and system load to `~/Library/Logs/Record Mode/` while the mode is on, to track down pointer trouble while recording. Remove it, its two calls in `main.swift` and its changelog entry when Alex says that's solved. The research is in the business vault: `~/obsidian/StarvaldDemelain/ZazenCodes/Notes/2026-11-13 - Screen Recording Pointer and Lag Investigation.md`.

## Decisions

Read these before changing the area they cover, and write a new one whenever a decision is made (`adr` skill).

- Record Mode runs the display at 60 Hz, because recordings are 60 fps: `docs/adr/2026-11-13-record-mode-runs-the-display-at-60-hz.md`
- Record Mode leaves apps and coding agents alone; the `recording-prep` skill quiets the Mac for a recording: `docs/adr/2026-11-13-record-mode-leaves-apps-and-agents-alone.md`

## Changelog and Releases

Follow the zc-apps conventions in the root `AGENTS.md`: `CHANGELOG.md` under `## [Unreleased]`, tags `record-mode/vX.Y.Z`.
