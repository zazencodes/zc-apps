# Hand-drawn ink is filled a short stretch at a time

## Decision

A hand-drawn line's ink is many overlapping circles and bands. It is handed to the renderer as a list of paths, each covering a short stretch of the line, and each path is filled on its own.

## Why

Core Graphics takes time that grows with the square of how many overlapping shapes share a fill. A long, nearly horizontal line filled in one go took hundreds of milliseconds: a 768×486 pt rectangle took 400 ms per redraw at 2x, and the app stopped answering the pointer for over a second with many rectangles on screen. Filled in short stretches the same rectangle takes about 6 ms.

The stretches hold the same circles and bands as before, so the ink's shape is unchanged. Edges differ by about one alpha level in 255 on average, only where two stretches meet.

## Rejected

- **One path for the whole line.** Exact edges, and the slowness above. Don't merge the stretches back together.
- **Every circle and band filled on its own.** The fastest, about 2.5 ms for the same rectangle, but every edge pixel is blended twice, which roughens edges visibly when zoomed in.
- **A single outline around the ink.** Fast and exact where it works, but an outline offset from the centerline folds over itself on turns tighter than the line is wide, which is the case the circles and bands exist to handle.
