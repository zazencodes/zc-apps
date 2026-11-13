# Pretty Draw: Vision and Scope

**Pretty Draw: beautiful screen annotations for macOS.**

Press ⌃B and draw over anything on screen. Press ⌃B again and it's all gone. Pretty Draw is for screen recordings, demos and live teaching, where a clean rectangle, arrow, underline or label points the viewer at the right thing.

This document is the agreed initial scope, written on 2026-11-11. The scope can change over time; update this file when it does.

## Origin

Alex has used Presentify 7.2.1 (Mac App Store) for screen annotation. Pretty Draw replaces it on his Mac, keeping only the features he uses, with the same keys and his current settings. Anything he doesn't use stays out.

Pretty Draw will later be sold on the Mac App Store, next to Pretty Keys. The store version will be a separate project. This one is built so that move is easy (see [App Store readiness](#app-store-readiness)). It also shapes the defaults: built-in settings suit anyone, and Alex's personal setup (ZazenCodes palette and custom fonts) lives in his own preferences.

## Annotating

- **⌃B** starts and ends annotating. It's a global shortcut that can be changed in Settings.
- **Esc** ends annotating too. It backs out one step at a time: a drag in progress, the shortcut sheet or the font list closes first, and text being typed is finished first.
- Annotations cover every display. The rest of the Mac stays where it was, and drawing doesn't switch apps.
- Ending a session clears the screen. Each session starts blank, and **⌘Z** brings back what was on screen when the last one ended.
- The selected tool, color, line width, line styles, text size and font carry over from one session to the next.

## Tools

| Key | Tool | Behaviour |
| --- | --- | --- |
| R | Rectangle | Drag from corner to corner. |
| A | Arrow | Drag from tail to tip. The head scales with the line width. |
| F | Freehand | Guided drawing: smoothed as you draw (see below). Hold ⇧ for a straight line. |
| T | Text | Click to type in place (see below). |

### Guided freehand

Freehand strokes are smoothed while you draw. Hand jitter disappears, so underlines come out as clean sweeps. When a stroke comes back around to where it started, letting go closes it into a smooth, round loop with any overshoot trimmed, so circling something looks deliberate. This is the **Close loops** switch in the toolbar, shown with the freehand tool and on by default. Switched off, loops stay open as drawn, overshoot included, and are still smoothed. Small hooks at the start and end of a stroke are removed. It should feel fun, and make drawings look better than the hand that drew them.

### Line styles

Freehand lines, arrows and rectangles come in two styles, picked with the style keys in the toolbar. Each of the three tools has its own style: making rectangles hand-drawn leaves freehand and arrows as they were. Each key shows the current tool drawn in that style. Every mark keeps the style it was drawn in, so switching changes only what's drawn next.

- **Clean**, the default: even lines with round caps and joins. Rectangles get softly rounded outer corners, and arrows a straight shaft with an open head of two arms, rounded at the tip and ends.
- **Hand-drawn**: marker ink that is a touch thinner where the pen lands, tapers as it lifts and swells slowly along the way. Rectangle sides bow slightly and run past the corners. Arrows get a gently bowed shaft and an open head of two flicks. A closed loop carries on a little past its start, the way a pen does.

Guided freehand smoothing is the same in both styles. The hand-drawn wobble is different for every mark and never changes once it's drawn.

### Text

Text should feel smooth and look good:

- With the text tool, click and start typing at that spot. There's no placeholder and no box, only a caret in the text color.
- **Return** and **⇧Return** start a new line. **⌃↓** opens a new line below the current one.
- **Esc** or clicking elsewhere finishes the text.
- Click existing text to edit it. Drag it to move it.
- With the text tool, the toolbar's font button opens the font list. Picking a font changes the text being typed and is used for new text.
- The font list holds the **standard fonts**, which come with every Mac and are always there (Avenir Next Demi Bold, Helvetica Neue Bold, Menlo Bold, Georgia Bold), and **custom fonts**, which come first. Custom fonts are added in Settings from any font installed on the Mac, and can be reordered and removed.
- Alex's custom fonts: **Switzer**, **DejaVuSansM Nerd Font Mono** (monospace), **Geist Serif Heart** (Vercel's Geist with hearts as dots), **SnowCrash Sans**.

## Keys

These are the same as Presentify's, so nothing needs relearning.

| Key | Action |
| --- | --- |
| ⌃B | Start or end annotating (global) |
| Esc | End annotating. While typing, finish the text |
| 1–5 | Choose palette color 1–5 |
| F, A, R, T | Freehand, Arrow, Rectangle, Text |
| [ and ] | Thinner or thicker line. With the text tool, smaller or larger text |
| ⌫ | Clear all annotations |
| ⌘Z, ⇧⌘Z | Undo, redo. ⌘Z at the start of a session brings back the last drawing |
| / | Show or hide the shortcut sheet |
| ⇧ held | Straight line while drawing freehand |

## Line width and text size

- Defaults: **11 pt line width** and **40 pt text**. These are Alex's current Presentify settings.
- **[ ]** step away from the default in either direction. The toolbar shows the current size and marks the default, so the default is always visible. Clicking the size returns to it.

## Colors and palettes

- A palette has five colors, picked with keys 1–5 or from the toolbar.
- Built-in palettes suit anyone. **Classic** is the default for new installs.
- Custom palettes can be created, renamed, edited and deleted in Settings. Built-ins can be duplicated as a starting point.
- Alex's configuration has a custom palette named **ZazenCodes**, selected. It is the five favorite colors from his Presentify setup, in Display P3:

| # | Color | Display P3 (r, g, b) | P3 hex |
| --- | --- | --- | --- |
| 1 | Lavender | 0.8288, 0.7047, 0.9788 | #D3B4FA |
| 2 | Pink | 0.9249, 0.5250, 0.7600 | #EC86C2 |
| 3 | Mint | 0.6464, 1.0000, 0.7414 | #A5FFBD |
| 4 | Coral | 0.9209, 0.4096, 0.3830 | #EB6862 |
| 5 | White | 0.9932, 0.9932, 0.9932 | #FDFDFD |

Colors are always fully opaque. There are no opacity controls.

## Toolbar

A compact toolbar sits at the top center while annotating, styled to match Pretty Keys: dark bar, keycap buttons. The selected tool and options are lighter grey keys, so the only color on the bar is the palette. It shows the five colors, the four tools with their keys, the size, the tool's options and a close button. The options are the line styles for freehand, arrow and rectangle, plus the Close loops switch for freehand, and the font for text. The options take the same width for every tool, so the bar doesn't change size or shift as the tool changes; the font button shows the font's family name to fit. The bar can be dragged anywhere and remembers where it was. A small badge next to the cursor shows the current tool and color.

**Show toolbar** in Settings hides the bar for anyone who'd rather work by keys alone. The screen then shows only what's drawn and the pointer badge. It's a Settings option only, never on the bar itself.

## App basics

- Lives in `/Applications`, found in Spotlight as "Pretty Draw", menu bar app with no Dock icon.
- Launch at login, switched on in Settings.
- Opening it from Spotlight while it's running opens Settings.

## Out of scope

These Presentify features are deliberately left out:

- Circle/ellipse tool, highlighter, opacity controls, random colors, whiteboard, touch drawing, filled shapes (⌥), auto-erase (⌃), select-and-delete (⌘), interactive mode (fn), saved sessions.
- Cursor highlight, spotlight and zoom, screenshots.

## App Store readiness

- Needs no special permission: the global shortcut uses Carbon hot keys, which work in the sandbox without Accessibility or Input Monitoring. Drawing needs no screen recording.
- Uses only sandbox-compatible APIs: `SMAppService` for launch at login, `UserDefaults` for settings, fonts installed on the system, no network.
- Built-in defaults suit anyone. Personal configuration is data in preferences, not code.
- A Swift package with a testable `PrettyDrawKit` library and a thin app executable, like Pretty Keys, so an Xcode app target can wrap it later.
