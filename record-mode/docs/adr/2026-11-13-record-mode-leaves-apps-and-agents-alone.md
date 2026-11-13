# Record Mode leaves apps and agents alone

## Decision

Record Mode changes the display and opens what a recording needs. It does not quit apps, and it does not slow, pause or otherwise touch coding agents or their jobs.

Quieting the Mac for a recording is the `recording-prep` skill's job: an agent looks at what is running at that moment, asks Alex and closes what he picks. Alex manages agents by hand.

## Why

Alex decided this on 2026-11-13, during the investigation into pointer trouble while recording. A list of apps built into the button would reflect what happened to be open on the day it was written. What should close depends on what is open and what the video needs, which is a judgment for the agent and Alex at the time.

## Rejected

- **A fixed list of apps that Record Mode quits and reopens.** See above.
- **Slowing agents in other tmux sessions while the mode is on.** Putting their processes in the background band confines them to the efficiency cores, about 5x slower in a test, with nothing disconnected, and it reverses cleanly without admin rights. Alex chose to leave agents alone; ask him before building it.
- **Freezing them until the mode turns off.** Also reversible, but no work gets done and a long freeze can drop a session's connection.
