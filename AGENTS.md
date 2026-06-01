# Repository Guidelines

## Project Structure & Module Organization

`skilt` is a single Bash CLI at the repo root. Its configuration lives in `gstack-skill-config/`, where `agents.tsv`, `skills.tsv`, `modules.tsv`, and `profiles.tsv` define agent mappings and profile composition. Tests live in `scripts/test-skilt.sh` and build isolated temp fixtures instead of touching a real local skill install. `gstack_introduce.md` is reference documentation; `.agents/` and `.codex/` are local tooling metadata and are not part of the runtime surface.

## Build, Test, and Development Commands

Run the CLI directly:

- `./skilt status` shows the current enabled/disabled state.
- `./skilt count` summarizes configured and installed skill totals.
- `./skilt diff -a codex` compares config vs. one agent’s current state.
- `./skilt use backend-indie -n` previews profile changes without moving files.
- `./skilt doctor` validates TSV integrity and local install assumptions.
- `./scripts/test-skilt.sh` runs the regression suite end to end.

## Coding Style & Naming Conventions

Keep shell changes POSIX-leaning Bash with `set -euo pipefail`. Follow the existing style: lowercase `snake_case` function names, short helper functions, and 2-space indentation inside blocks. Prefer explicit error messages through `die()` and `warn()`. In TSV files, keep tab-separated columns, lowercase kebab-case identifiers such as `backend-indie` or `design-html`, and add comments only when they clarify non-obvious mappings.

## Testing Guidelines

Add or extend `test_*` functions in `scripts/test-skilt.sh` for each behavior change, then run the full script. Tests should use the fixture helpers already in place (`setup_fixture`, `make_link`, `make_claude_skill`) and assert both enabled and disabled paths where relevant. Cover dry-run behavior for move logic changes.

## Commit & Pull Request Guidelines

Git history is minimal and currently starts with `Initial skilt import`, so prefer short imperative subjects going forward, for example `Add release-stage profile` or `Fix doctor module validation`. PRs should state the user-facing behavior change, list the TSV files touched, and include relevant command output such as `./skilt doctor` or a dry-run example. Screenshots are usually unnecessary for this repo.

## Configuration & Safety Notes

Prefer changing `gstack-skill-config/*.tsv` over editing live skill installs under `$HOME`. Use `SKILT_CONFIG_DIR` and `SKILT_GSTACK_SKILLS_DIR` when testing against fixtures or alternate installs.
