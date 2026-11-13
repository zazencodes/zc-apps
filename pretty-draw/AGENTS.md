# AGENTS.md

Pretty Draw: beautiful screen annotations for macOS 14+. A menu bar app: ⌃B covers every display with a canvas for rectangles, arrows, guided freehand and text, and ⌃B or Esc clears it away. Alex's replacement for Presentify, to be sold on the Mac App Store later as a separate project.

## Project Instructions

- Read `docs/SCOPE.md` before changing behavior. It is the agreed vision and scope: what's in, what's deliberately out, the keys and the defaults. Update it when the scope changes.
- Keys match Presentify's, so Alex never relearns them. Don't add or rebind annotation keys without asking.
- Built-in defaults must suit anyone (Classic palette, fonts that ship with macOS). Alex's own setup is data in his preferences: the custom `ZazenCodes` palette (ID `zazencodes`, values in `docs/SCOPE.md`), his custom fonts and his last-used tool, color and sizes. Don't ship personal settings as code.
- Keep it App Store-ready: no permission prompts, sandbox-compatible APIs only (Carbon hot key, `SMAppService`, `UserDefaults`, system fonts), no network.

## Commands and Layout

- `swift test`: unit tests. `./build.sh`: `build/Pretty Draw.app`, ID `com.zazencodes.prettydraw`, signed with the Apple Development identity (`PRETTY_DRAW_SIGN_IDENTITY=-` for ad hoc). `./install.sh`: replace `/Applications/Pretty Draw.app` and launch it.
- `swift run pretty-draw-render gallery <dir>`: renders the real drawing code to PNGs: `smoothing.png` (raw input under guided strokes), `styles.png` (every line style side by side), `interface.png` (toolbar per tool, the font list and the shortcut sheet) and `icon.png`.
- `Sources/PrettyDrawKit`:
  - `Model/`: palettes, tools and size steps, line styles, the key map, the undoable `Drawing`, `Preferences`.
  - `Geometry/`: `GuidedStroke` (freehand smoothing, hook trimming, loop closing, pull toward a clean sweep or ellipse), `HandDrawn` (the hand-drawn style's ink and sketched shapes, varied by each mark's seed) and `MarkRenderer`.
  - `Overlay/`: `AnnotationSession` owns a session: canvases, gestures, text editing, toolbar, sheet. `CanvasView` draws one display's finished shapes and holds the views for what follows the pointer, `TextMarkView` is both finished and edited text.
  - `App/`, `Settings/`, `Fonts/`, `Dev/` (sample strokes and the renderer).
- Validate changes with `swift test` and `./build.sh`. For visual changes, render the gallery and look at it. Pointer and keyboard behavior needs the real app.

## Important Details

- Overlay and toolbar panels are non-activating: annotating never switches away from the app in front. Menus open below the overlay's window level, so a click on one lands on the canvas instead. Anything that pops up while annotating, like the font list, is a panel above the toolbar. Text editing commands (⌘C/V/X/A/Z) are handled in `TextMarkView.performKeyEquivalent`, since the app isn't active while annotating.
- macOS reserves ⌃↓ for App Exposé by default, so ⌃↓ only reaches a text label once that system shortcut is turned off in System Settings → Keyboard → Keyboard Shortcuts → Mission Control.
- Guidance thresholds in `GuidedStroke` are tuned against `SampleStrokes`. After changing them, run the tests and re-render `smoothing.png`.
- `Preferences` stores structured values as JSON strings (`defaults read com.zazencodes.prettydraw`). Invalid stored values fail loudly at launch.
- Drawing with the keyboard and pointer from scripts: send keys to the process with `CGEvent.postToPid`. Mouse events must be posted globally to reach the overlay.

## Decisions

Read these before changing the area they cover, and write a new one whenever a decision is made (`adr` skill).

- Hand-drawn ink is filled a short stretch at a time, because filling a whole line at once is very slow: `docs/adr/2026-11-13-hand-drawn-ink-is-filled-a-short-stretch-at-a-time.md`
- The live line, a settling stroke and the pointer badge have views of their own, so following the pointer never redraws finished marks: `docs/adr/2026-11-13-what-follows-the-pointer-is-drawn-apart-from-finished-marks.md`

## Changelog and Releases

Follow the zc-apps conventions in the root `AGENTS.md`: `CHANGELOG.md` under `## [Unreleased]`, tags `pretty-draw/vX.Y.Z`. `VERSION` sets the bundle version.
