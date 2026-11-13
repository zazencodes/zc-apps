# Changelog

## [Unreleased]

### Added

- Added Pretty Draw, screen annotation for recordings: ⌃B covers every display for drawing rectangles, arrows, freehand lines and text, and ⌃B or Esc clears it away
- Added bringing back the last drawing: ⌘Z at the start of a session restores what was on screen when the previous one ended
- Added guided freehand drawing: strokes are smoothed as you draw, release flicks are trimmed, nearly straight lines become clean sweeps and loops close into smooth ellipses. Hold ⇧ for a straight line
- Added text labels with a font list in the toolbar: standard fonts that come with every Mac, plus custom fonts added in Settings from any installed font. Return and ⇧Return start a new line, ⌃↓ opens a line below, and Esc or a click elsewhere finishes. Click text to edit it, drag it to move it
- Added Presentify's keys: 1–5 for colors, F, A, R and T for tools, [ and ] for line width and text size, ⌘Z and ⇧⌘Z for undo and redo, ⌫ to clear and / for a sheet of every shortcut
- Added a Close loops switch in the toolbar for the freehand tool: switch it off to keep loops open as drawn
- Added a Show toolbar setting, for annotating by keys alone with nothing on screen but the drawing
- Added line styles for freehand lines, arrows and rectangles, picked in the toolbar for each tool on its own: Clean, and Hand-drawn, with marker ink that tapers and swells, rectangles whose sides cross at the corners, arrows with an open head, and loops that overlap where they close
- Added five-color palettes: Classic, Pastel and Neon built in, plus custom palettes that can be duplicated, renamed, recolored and deleted in Settings
- Added a draggable toolbar with the palette, tools, size (marking the default) and font, and a badge by the pointer showing the current tool and color
- Added Settings for the annotate shortcut, Open at login, palettes and custom fonts, and `./install.sh`, which builds Pretty Draw and installs it to `/Applications`

### Fixed

- Fixed drawing freezing and freehand lines breaking up while hand-drawn rectangles and other long hand-drawn lines were on screen
