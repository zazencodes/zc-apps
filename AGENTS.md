# zc-apps

Small personal desktop apps, one folder per app. Each app is self-contained: its own `AGENTS.md`/`README.md` (where it has them), code, and build.

- `tierlist/`: Tier List ZC, a drag-and-drop tier list app with an agent-editable CLI. See `tierlist/AGENTS.md`.

## Conventions

- Platform code lives in `<app>/<platform>/` (today only `mac/`), with a `build.sh` that builds the app into `<app>/build/`. Swift apps build with the Command Line Tools, no Xcode project.
- Bundle identifiers are `com.zazencodes.<app>`.
- Releases are per-app tags `<app>/vMAJOR.MINOR.PATCH`.
