# Skilt Install Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `scripts/install-skilt.sh` so users can install `skilt` plus its bundled config into custom locations without manually setting `SKILT_CONFIG_DIR`.

**Architecture:** Keep the repository runtime untouched, but install a copied runtime under the chosen config root and generate a thin wrapper in the chosen bin directory. The wrapper fixes `SKILT_CONFIG_DIR` to the installed config bundle and delegates to the copied real script.

**Tech Stack:** Bash, `install`, `cp`, `mktemp`, existing shell regression tests.

---

## File Structure

- Create: `scripts/install-skilt.sh`
  - Parse `--bin-dir` and `--config-dir`
  - Prompt for missing values
  - Copy the runtime and generate the wrapper
- Modify: `scripts/test-skilt.sh`
  - Add installer coverage using temp directories
- Modify: `README.md`
  - Document installer usage and installed layout
- Modify: `README.zh-CN.md`
  - Mirror installer usage notes in Chinese

### Task 1: Add failing installer tests

**Files:**
- Modify: `scripts/test-skilt.sh`
- Test: `scripts/test-skilt.sh`

- [ ] **Step 1: Add an installer path helper**

Near the existing script constants, add:

```bash
INSTALL_SCRIPT="$SCRIPT_DIR/install-skilt.sh"
```

- [ ] **Step 2: Add a non-interactive install test**

Append:

```bash
test_install_script_copies_runtime_and_wrapper() {
  setup_fixture

  local bin_dir="$TEST_HOME/bin"
  local config_root="$TEST_HOME/config-root"

  "$INSTALL_SCRIPT" --bin-dir "$bin_dir" --config-dir "$config_root" >/tmp/skilt-install.out

  assert_exists "$bin_dir/skilt"
  assert_exists "$config_root/skilt/skilt"
  assert_exists "$config_root/skilt/gstack-skill-config/skills.tsv"
  grep -q "$config_root/skilt/gstack-skill-config" "$bin_dir/skilt" || fail "wrapper should embed installed config dir"
}
```

- [ ] **Step 3: Add an installed-runtime behavior test**

Append:

```bash
test_install_script_installed_wrapper_runs_with_installed_config() {
  setup_fixture

  local bin_dir="$TEST_HOME/bin"
  local config_root="$TEST_HOME/config-root"

  "$INSTALL_SCRIPT" --bin-dir "$bin_dir" --config-dir "$config_root" >/tmp/skilt-install-runtime.out

  cp "$TEST_CONFIG/agents.tsv" "$config_root/skilt/gstack-skill-config/agents.tsv"
  cp "$TEST_CONFIG/skills.tsv" "$config_root/skilt/gstack-skill-config/skills.tsv"
  cp "$TEST_CONFIG/modules.tsv" "$config_root/skilt/gstack-skill-config/modules.tsv"
  cp "$TEST_CONFIG/profiles.tsv" "$config_root/skilt/gstack-skill-config/profiles.tsv"

  "$bin_dir/skilt" list profiles --verbose >/tmp/skilt-installed-list.out

  grep -q $'^backend-indie\tLean backend-focused workflow with debugging, product, and ship support\\.$' /tmp/skilt-installed-list.out || fail "installed wrapper should use installed config bundle"
}
```

- [ ] **Step 4: Add an interactive prompt fallback test**

Append:

```bash
test_install_script_prompts_for_missing_directories() {
  setup_fixture

  local bin_dir="$TEST_HOME/prompt-bin"
  local config_root="$TEST_HOME/prompt-config"

  printf '%s\n%s\n' "$bin_dir" "$config_root" | "$INSTALL_SCRIPT" >/tmp/skilt-install-prompt.out

  assert_exists "$bin_dir/skilt"
  assert_exists "$config_root/skilt/gstack-skill-config/modules.tsv"
}
```

- [ ] **Step 5: Register the new tests and verify RED**

Add these calls near the bottom:

```bash
test_install_script_copies_runtime_and_wrapper
test_install_script_installed_wrapper_runs_with_installed_config
test_install_script_prompts_for_missing_directories
```

Run:

```bash
rtk ./scripts/test-skilt.sh
```

Expected:

- exit code is non-zero
- failure is `No such file or directory` for `scripts/install-skilt.sh`

### Task 2: Implement the installer

**Files:**
- Create: `scripts/install-skilt.sh`
- Test: `scripts/test-skilt.sh`

- [ ] **Step 1: Create the installer skeleton**

Create:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILT="$REPO_ROOT/skilt"
SOURCE_CONFIG_DIR="$REPO_ROOT/gstack-skill-config"

die() {
  echo "ERROR $*" >&2
  exit 1
}
```

- [ ] **Step 2: Add argument parsing and prompt fallback**

Add:

```bash
BIN_DIR=""
CONFIG_ROOT=""

prompt_if_empty() {
  local label="$1"
  local value="${2:-}"

  if [ -n "$value" ]; then
    printf '%s\n' "$value"
    return 0
  fi

  printf '%s: ' "$label" >&2
  IFS= read -r value || true
  [ -n "$value" ] || die "$label is required"
  printf '%s\n' "$value"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --bin-dir)
        shift
        [ "$#" -gt 0 ] || die "--bin-dir requires a value"
        BIN_DIR="$1"
        ;;
      --config-dir)
        shift
        [ "$#" -gt 0 ] || die "--config-dir requires a value"
        CONFIG_ROOT="$1"
        ;;
      -h|--help)
        cat <<'EOF'
Usage: scripts/install-skilt.sh [--bin-dir PATH] [--config-dir PATH]
EOF
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
    shift
  done
}
```

- [ ] **Step 3: Add copy and wrapper generation helpers**

Add:

```bash
write_wrapper() {
  local wrapper_path="$1"
  local real_skilt="$2"
  local installed_config_dir="$3"

  install -d "$(dirname "$wrapper_path")"
  cat >"$wrapper_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail

export SKILT_CONFIG_DIR="$installed_config_dir"
exec "$real_skilt" "\$@"
EOF
  chmod 755 "$wrapper_path"
}

install_runtime() {
  local bin_dir="$1"
  local config_root="$2"
  local install_root="$config_root/skilt"
  local real_skilt="$install_root/skilt"
  local installed_config_dir="$install_root/gstack-skill-config"

  [ -f "$SOURCE_SKILT" ] || die "missing source script: $SOURCE_SKILT"
  [ -d "$SOURCE_CONFIG_DIR" ] || die "missing source config dir: $SOURCE_CONFIG_DIR"

  install -d "$install_root"
  install -m 755 "$SOURCE_SKILT" "$real_skilt"
  rm -rf "$installed_config_dir"
  cp -R "$SOURCE_CONFIG_DIR" "$installed_config_dir"
  write_wrapper "$bin_dir/skilt" "$real_skilt" "$installed_config_dir"
}
```

- [ ] **Step 4: Add `main` and run GREEN**

Add:

```bash
main() {
  parse_args "$@"
  BIN_DIR="$(prompt_if_empty "Bin dir" "$BIN_DIR")"
  CONFIG_ROOT="$(prompt_if_empty "Config dir" "$CONFIG_ROOT")"
  install_runtime "$BIN_DIR" "$CONFIG_ROOT"
}

main "$@"
```

Run:

```bash
rtk ./scripts/test-skilt.sh
```

Expected:

- installer tests pass
- the existing `skilt` regression tests still pass

### Task 3: Document the installer

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`

- [ ] **Step 1: Add install-script usage to the English README**

Document:

```bash
./scripts/install-skilt.sh --bin-dir ~/scripts --config-dir ~/.config/skilt
```

and note that omitted arguments fall back to prompts.

- [ ] **Step 2: Add the same usage to the Chinese README**

Mirror the same command and behavior explanation in Chinese.

- [ ] **Step 3: Verify docs are aligned with behavior**

Check that the README examples match:

- wrapper path: `<bin-dir>/skilt`
- runtime path: `<config-dir>/skilt/skilt`
- config path: `<config-dir>/skilt/gstack-skill-config`

### Task 4: Final verification and commit

**Files:**
- Modify: `scripts/install-skilt.sh`
- Modify: `scripts/test-skilt.sh`
- Modify: `README.md`
- Modify: `README.zh-CN.md`

- [ ] **Step 1: Run the full verification commands**

Run:

```bash
rtk ./scripts/test-skilt.sh
```

Expected:

- exit code is zero
- final line is `All skilt tests passed`

- [ ] **Step 2: Spot-check the installer manually**

Run:

```bash
tmp_home="$(mktemp -d)"
tmp_bin="$tmp_home/bin"
tmp_config="$tmp_home/config"
rtk ./scripts/install-skilt.sh --bin-dir "$tmp_bin" --config-dir "$tmp_config"
HOME="$tmp_home" SKILT_GSTACK_SKILLS_DIR="$(mktemp -d)" "$tmp_bin/skilt" list skills --verbose
```

Expected:

- wrapper executes successfully
- output is the installed config inventory

- [ ] **Step 3: Commit the finished change**

Run:

```bash
git add scripts/install-skilt.sh scripts/test-skilt.sh README.md README.zh-CN.md docs/superpowers/specs/2026-06-01-skilt-install-script-design.md docs/superpowers/plans/2026-06-01-skilt-install-script.md
git commit -m "feat: add skilt installer"
```
