# What follows the pointer is drawn apart from finished marks

## Decision

The canvas draws finished shapes only. Anything that changes as the pointer moves has a small view of its own above them: the line being drawn, a stroke settling into its guided shape, and the badge by the pointer. Following the pointer redraws those and never the finished shapes. When the drawing changes, the canvas redraws only where a shape was added, removed or changed.

## Why

Pretty Draw is used while recording, with the Mac already busy. Drawing the live line on the canvas itself redrew every finished mark whose bounds it crossed on every pointer event, so an arrow inside a box redrew the box each frame, and each update of a display-sized layer copies the whole layer. Stalls on the main thread merge pointer events, which showed up as broken freehand lines.

## Rejected

- **One canvas that redraws the changed area.** Simple, and the cost above: time per frame grew with how much was already drawn.
- **A display-sized view for the live line.** Keeps finished marks out of the redraw but still copies a full-screen layer on every pointer event. The live views are only as big as what they show.
