# zc-apps

Small personal desktop apps, one folder per app. Each app is self-contained: its own code, build, `CHANGELOG.md` and, where it has them, `AGENTS.md` and `README.md`. Work on an app from inside its folder.

- `tierlist/`: Tier List ZC, a drag-and-drop tier list app with an agent-editable CLI. See `tierlist/AGENTS.md`.
- `cpu-bars/`: CPU Bars, a menu bar CPU monitor (SwiftUI `MenuBarExtra`).
- `record-mode/`: Record Mode, a menu bar toggle that switches the main display to a lighter mode for screen recording (SwiftUI `MenuBarExtra`).
- `facecam/`: Facecam, a menu bar webcam mirror in a floating, resizable window (AppKit `NSStatusItem`).

## Conventions

This repo is an index that holds independent apps. It is not a shared stack. Build each new app in whatever language, frameworks, project layout and build system suit that app best, and don't copy another app's structure just because it lives here. Follow the existing code only when you're working inside that app.

- Each app documents how to build it in its own `AGENTS.md` or `README.md`.
- Bundle identifiers are `com.zazencodes.<app>`.
- Add a new app as a folder with a `CHANGELOG.md` and an install script, and list it here and in `README.md`.

## Installing Apps

Alex runs these apps from `/Applications`, where Spotlight finds them. When a change to an app is finished and has passed testing, run that app's install script without being asked. It builds the app, replaces the copy in `/Applications` and launches it.

- `facecam/`, `cpu-bars/` and `record-mode/`: `./mac/install.sh`
- `tierlist/` stays in `build/`, because the app finds its repo and loads its UI from its own location.

Login items must point at the `/Applications` copy.

## Changelog

Each app has its own `<app>/CHANGELOG.md` (Keep a Changelog). Add an entry under `## [Unreleased]` for every user-facing change, in the subsections `### Breaking Changes`, `### Added`, `### Changed`, `### Fixed`, `### Removed`: one line, past tense, saying what changed for the user. Read the section first and append to existing subsections. Released sections are immutable.

## Releases

Each app is released on its own, as a tag `<app>/vX.Y.Z` with a GitHub release. From a clean, pushed `main`:

1. In `<app>/CHANGELOG.md`, rename `[Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` and add a fresh `## [Unreleased]` above it. If `<app>/README.md` has a release badge, set its version and link to the new tag. Commit as `Release <app> vX.Y.Z` and push.
2. `git tag -a <app>/vX.Y.Z -m "<app>/vX.Y.Z"` and `git push origin <app>/vX.Y.Z`.
3. `gh release create <app>/vX.Y.Z --title "<App Name> vX.Y.Z" --notes "<that version's CHANGELOG section>"`.

No prebuilt apps are attached; users build from source with the app's own build command.
