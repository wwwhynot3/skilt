# skilt install script

## Goal

Add a Unix-friendly installer that copies `skilt` and its bundled
`gstack-skill-config/` to user-chosen locations, so the installed command works
without requiring manual `SKILT_CONFIG_DIR` setup.

## User-facing behavior

The repository continues to support direct clone-and-run usage:

- `./skilt status`
- `./skilt use backend-indie`

In addition, the repository gains an installer entrypoint:

- `./scripts/install-skilt.sh --bin-dir ~/scripts --config-dir ~/.config/skilt`

If either directory is omitted, the installer prompts interactively:

- `Bin dir:`
- `Config dir:`

The installer copies files by default. It does not create symlinks unless that
is added in a future change.

## Installed layout

Given:

- `--bin-dir /some/bin`
- `--config-dir /some/config-root`

The installer produces:

- `/some/bin/skilt` as a generated wrapper script
- `/some/config-root/skilt/skilt` as the real copied CLI
- `/some/config-root/skilt/gstack-skill-config/` as the copied config bundle

The wrapper exports:

- `SKILT_CONFIG_DIR=/some/config-root/skilt/gstack-skill-config`

and then `exec`s the real script at:

- `/some/config-root/skilt/skilt`

This keeps the user-facing executable path simple while allowing the runtime
config location to differ from the executable directory.

## Installer behavior

The installer:

- validates that `skilt` and `gstack-skill-config/` exist in the repository
- creates destination directories when needed
- overwrites a previous installed copy in the target locations
- writes the wrapper with executable permissions
- copies the real script with executable permissions
- copies the config tree recursively

The installer does not modify shell rc files or PATH settings.

## Runtime compatibility

The installed wrapper must not change existing runtime behavior other than
setting `SKILT_CONFIG_DIR`. Specifically:

- direct repository execution still uses `./gstack-skill-config/` by default
- installed execution resolves config from the wrapper-provided environment
- `SKILT_GSTACK_SKILLS_DIR` remains user-configurable after installation

## Error handling

Failures should be explicit and actionable:

- missing required repository files: installer exits with `ERROR ...`
- empty input after prompting: installer exits with `ERROR ...`
- failed copy or directory creation: installer exits non-zero from shell

The installer does not need partial rollback. A failed rerun should be able to
overwrite the destination cleanly.

## Testing

Regression coverage should prove:

- non-interactive install copies the real script and config bundle
- the generated wrapper points at the selected config root
- the installed command works with a fixture config and prints expected output
- prompting mode succeeds when directories are provided via stdin

## Documentation

Update the repository docs to describe:

- `scripts/install-skilt.sh`
- `--bin-dir` and `--config-dir`
- prompt fallback when arguments are omitted
- the installed wrapper/config layout at a high level
