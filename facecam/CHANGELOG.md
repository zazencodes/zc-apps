# Changelog

## [Unreleased]

### Added

- Added Facecam, a menu bar webcam mirror: click the icon to show or hide a floating, resizable window of your camera for screen recording. Build it with `./mac/build.sh`
- Added `./mac/install.sh`, which builds Facecam, installs it to `/Applications` so Spotlight finds it, and launches it

### Changed

- Opening Facecam from Spotlight, Finder or `open` now shows the camera window, whether or not the app is already running. It stays hidden when the app starts at login
