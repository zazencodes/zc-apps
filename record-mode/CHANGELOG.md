# Changelog

## [Unreleased]

### Added

- Added Record Mode, a menu bar toggle that switches the main display between 3008×1692 at 120 Hz and 1920×1080 (HiDPI) at 60 Hz for screen recording. Build it with `./mac/build.sh`
- Added `./mac/install.sh`, which builds Record Mode, installs it to `/Applications` so Spotlight finds it, and launches it
- Added automatic opening of `~/Movies/space-1080p.jpeg` when entering Record Mode
- Added a new ZazenCodes Chrome window on the current desktop with the newsletter, Agentic Coding Club, and fundamentals course when entering Record Mode
- Added `recordmode://on` and `recordmode://off` URLs so scripts can switch Record Mode with `open`
- Added a temporary log of mouse clicks, late pointer events, app switches and system load while Record Mode is on, in `~/Library/Logs/Record Mode/`, to track down pointer trouble while recording. It never reads the keyboard
