# skilt `list --verbose` descriptions

## Goal

Add a `--verbose` mode to `skilt list` so `skills`, `modules`, and `profiles`
can show human-readable descriptions alongside their identifiers, without
changing the existing default output.

## User-facing behavior

`skilt list <entity>` keeps its current output:

- `skilt list skills` prints skill identifiers only
- `skilt list modules` prints module identifiers only
- `skilt list profiles` prints profile identifiers only

`skilt list <entity> --verbose` prints one record per line in tab-separated
format:

- `skilt list skills --verbose` prints `skill<TAB>description`
- `skilt list modules --verbose` prints `module<TAB>description`
- `skilt list profiles --verbose` prints `profile<TAB>description`

Descriptions may be longer than a short label, but they must remain single-line
text. `skilt` will not wrap or truncate them. Users can format the output with
external terminal tools if desired.

`agents` are excluded from this change. `skilt list agents --verbose` is not
part of the scope.

## Configuration changes

The configuration files gain description columns:

- `skills.tsv`: `skill<TAB>description`
- `modules.tsv`: `module<TAB>skill<TAB>description`
- `profiles.tsv`: `profile<TAB>module<TAB>description`

For `modules.tsv` and `profiles.tsv`, the same logical identifier appears on
multiple rows. All rows for the same module or profile must carry the same
description. The CLI will use the first matching description when printing
verbose output.

Existing command behavior that depends on the first one or two columns must
continue to work unchanged. New description columns are additive metadata only.

## Parsing and validation

The current helpers that read identifiers and relationships continue to read the
same key columns and ignore trailing description columns.

New description lookup helpers will:

- read the first matching description for a given skill, module, or profile
- treat missing descriptions as configuration errors instead of silently
  printing empty text

`doctor` will add description consistency checks:

- each `skill` row must contain a description
- all rows for the same `module` must use the same description
- all rows for the same `profile` must use the same description

If a duplicate module or profile carries conflicting descriptions, `doctor`
fails with a specific error.

## CLI shape

Argument parsing changes only for `list`:

- `skilt list agents|modules|profiles|skills`
- `skilt list agents|modules|profiles|skills --verbose`
- `skilt list agents|modules|profiles|skills -v`

The option order does not need to be fully general. Supporting the entity
followed by an optional verbosity flag is sufficient for this change.

`agents --verbose` may either be rejected with a clear error or behave the same
as non-verbose output. Rejecting it is preferred because it makes the supported
surface explicit.

## Testing

Regression coverage will include:

- default `list` output is unchanged
- verbose `skills`, `modules`, and `profiles` output includes descriptions
- `list agents --verbose` returns the documented error behavior
- `doctor` fails when one module uses conflicting descriptions across rows
- `doctor` fails when one profile uses conflicting descriptions across rows

## Documentation

Update these surfaces:

- `skilt -h` usage text
- repository README usage examples
- configuration file examples showing the new description columns
