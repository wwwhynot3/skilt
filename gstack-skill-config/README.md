# skilt

`skilt` manages which gstack skills are visible to local coding agents. It reduces context load by moving skill entry points between each agent's enabled skills directory and a disabled directory.

The command is intentionally short:

```bash
./skilt status
./skilt count
./skilt diff
./skilt use backend-indie -n
./skilt use backend-indie
./skilt off ios
./skilt on design
./skilt reset
./skilt doctor
```

## Commands

Preview a change without moving files:

```bash
./skilt use backend-indie -n
./skilt off design -n
```

Inspect totals and current differences:

```bash
./skilt count
./skilt diff
./skilt diff -a codex
```

Apply a role or stage profile:

```bash
./skilt use backend-indie
./skilt use springboot-work
./skilt use idea-stage
./skilt use gui-stage
./skilt use tui-stage
./skilt use release-stage
```

Enable or disable a functional module:

```bash
./skilt on design
./skilt off ios
./skilt on web-qa
./skilt off model-benchmark
```

Enable or disable one skill directly. Every skill automatically has an implicit self-module:

```bash
./skilt on design-html
./skilt off benchmark-models
```

Reset everything:

```bash
./skilt all-on
./skilt all-off
./skilt reset
```

`reset` is an alias for `all-on`: it restores every configured skill from disabled directories.

## Count And Diff

`count` prints:

- configured skill total from `skills.tsv`
- installed gstack item total, including the root `gstack`
- installed non-root skill total
- enabled and disabled counts for each selected agent

`diff` prints:

- configured skills that are not installed locally
- installed items that are not in `skills.tsv`
- enabled skill names by agent
- disabled skill names by agent

This is useful when `all-on` output feels inconsistent with the skill total. `all-on` only prints actual moves, while `diff` shows the full current state.

Limit an operation to one agent:

```bash
./skilt use backend-indie -a codex
./skilt off design -a claude
./skilt on web-qa -a opencode
```

List configured entities:

```bash
./skilt list agents|modules|profiles|skills [--verbose]
./skilt list agents
./skilt list modules
./skilt list profiles
./skilt list skills
./skilt list profiles --verbose
```

Verbose mode prints `name<TAB>description` for `skills`, `modules`, and `profiles`:

```bash
./skilt list modules --verbose
```

Validate the configuration and local install:

```bash
./skilt doctor
```

## Configuration Files

All configuration lives in this directory.

`agents.tsv` defines each coding agent:

```text
agent   enabled_dir                 disabled_dir                         entry_style
codex   ~/.codex/skills             ~/.codex/skills.disabled/gstack      gstack-prefix
claude  ~/.claude/skills            ~/.claude/skills.disabled/gstack     plain
```

`entry_style` controls how a logical skill name maps to an installed entry:

- `gstack-prefix`: `investigate` maps to `gstack-investigate`.
- `plain`: `investigate` maps to `investigate`.

`skills.tsv` is the full known gstack skill inventory. `doctor` compares it with the local gstack install and reports missing entries.

Schema:

```text
skill	description
```

`modules.tsv` maps functional modules to skills:

```text
module      skill         description
design      design-html   Product, UX, and interface design workflows.
design      design-review Product, UX, and interface design workflows.
ios         ios-qa        iOS implementation, review, and QA workflows.
```

`profiles.tsv` maps roles or project stages to modules:

```text
profile         module      description
backend-indie   core-debug  Lean backend-focused profile with debugging, review, docs, and release support.
backend-indie   product     Lean backend-focused profile with debugging, review, docs, and release support.
gui-stage       design      GUI-building profile with product, backend, web QA, and design support.
```

Repeated `module` or `profile` keys must repeat the exact same description string on every row so `doctor` and `list --verbose` stay deterministic.

## How It Works

`skilt` does not edit gstack source files. It only moves the agent-visible entry point.

For Codex and OpenCode, most entries are symlinks:

```text
~/.codex/skills/gstack-investigate
~/.config/opencode/skills/gstack-investigate
```

For Claude Code, entries are usually directories containing a linked `SKILL.md`:

```text
~/.claude/skills/investigate/SKILL.md
```

When disabling a skill, `skilt` moves that entry to the agent's disabled directory. When enabling it, `skilt` moves it back. It does not follow symlinks, so the gstack install under `~/gstack` is left untouched.

## Doctor Checks

`./skilt doctor` checks:

- `skills.tsv` contains no duplicate skills.
- `skills.tsv` descriptions are present and non-blank.
- `modules.tsv` descriptions are present and non-blank.
- `profiles.tsv` descriptions are present and non-blank.
- Repeated module rows reuse the same description text.
- Repeated profile rows reuse the same description text.
- `modules.tsv` does not reference unknown skills.
- `profiles.tsv` does not reference unknown modules.
- Installed gstack skills are present in `skills.tsv`.
- Configured skills exist in the local install when the install directory is available.
- Each skill has a functional module binding beyond its implicit self-module.
- An agent does not have the same skill in both enabled and disabled locations.

Warnings are used for quality issues that still allow operation, such as a skill only having its implicit self-module. Errors fail the command.

## Adding a New Agent

Add one row to `agents.tsv`:

```text
pi  ~/.pi/skills  ~/.pi/skills.disabled/gstack  gstack-prefix
```

Then check:

```bash
./skilt list agents
./skilt doctor
```

## Adding a New Module or Profile

To add a module, edit `modules.tsv`:

```text
security-hardening  cso     Security review and hardening workflows.
security-hardening  review  Security review and hardening workflows.
```

To add a profile, edit `profiles.tsv`:

```text
security-pass  security-hardening  Security-focused release profile with review and health checks.
security-pass  core-health         Security-focused release profile with review and health checks.
```

Then preview:

```bash
./skilt use security-pass -n
```
