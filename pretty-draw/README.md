# Pretty Draw

Beautiful screen annotations for macOS.

Press **⌃B** and draw over anything on screen: rectangles, arrows, freehand lines that smooth themselves as you draw, and text in your own fonts. Press ⌃B or Esc and it's all gone, until ⌘Z next time brings it back. Made for screen recordings, demos and live teaching.

- **Guided freehand.** Hand jitter disappears as you draw. Underlines come out as clean sweeps, and a loop drawn around something closes into a smooth ellipse.
- **Line styles.** Clean, even lines, or hand-drawn marker ink with sketched rectangles and open arrowheads. Freehand, arrows and rectangles each keep their own style, picked in the toolbar.
- **Text that feels right.** Click and type. Pick from standard fonts, or add any font on your Mac in Settings. Click text to edit it, drag it to move it.
- **Palettes.** Five colors on keys 1–5. Use a built-in palette or make your own.
- **Keyboard first.** Every tool and size has a key. Press / while annotating to see them all, or hide the toolbar in Settings and work by keys alone.

| Key | Action |
| --- | --- |
| ⌃B | Start or end annotating |
| Esc | End annotating (while typing, finish the text) |
| F, A, R, T | Freehand, arrow, rectangle, text |
| 1–5 | Palette colors |
| [ and ] | Thinner or thicker line (smaller or larger text with the text tool) |
| ⌘Z, ⇧⌘Z | Undo, redo. ⌘Z at the start brings back the last drawing |
| ⌫ | Clear everything |
| / | Show every shortcut |

## Build

Needs macOS 14 and the Xcode Command Line Tools.

```sh
./install.sh   # builds, installs to /Applications and launches
./build.sh     # builds build/Pretty Draw.app only
swift test
```

Turn on **Open at login** in Settings to have it ready after every restart.
