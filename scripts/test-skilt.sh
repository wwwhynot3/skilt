#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../skilt"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_exists() {
  [ -e "$1" ] || [ -L "$1" ] || fail "expected path to exist: $1"
}

assert_missing() {
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "expected path to be missing: $1"
}

make_link() {
  local path="$1"
  local target="$2"
  mkdir -p "$(dirname "$path")" "$target"
  ln -s "$target" "$path"
}

make_claude_skill() {
  local root="$1"
  local name="$2"
  local target="$3"
  mkdir -p "$root/$name" "$target/$name"
  ln -s "$target/$name/SKILL.md" "$root/$name/SKILL.md"
}

setup_fixture() {
  TEST_HOME="$(mktemp -d)"
  TEST_CONFIG="$(mktemp -d)"
  TEST_GSTACK="$(mktemp -d)"
  export HOME="$TEST_HOME"
  export SKILT_CONFIG_DIR="$TEST_CONFIG"
  export SKILT_GSTACK_SKILLS_DIR="$TEST_GSTACK"

  mkdir -p "$HOME/.codex/skills" "$HOME/.claude/skills" "$HOME/.config/opencode/skills"
  mkdir -p "$HOME/source/codex" "$HOME/source/claude" "$HOME/source/opencode"

  cat >"$TEST_CONFIG/agents.tsv" <<'EOF'
# agent	enabled_dir	disabled_dir	entry_style
codex	~/.codex/skills	~/.codex/skills.disabled/gstack	gstack-prefix
claude	~/.claude/skills	~/.claude/skills.disabled/gstack	plain
opencode	~/.config/opencode/skills	~/.config/opencode/skills.disabled/gstack	gstack-prefix
EOF

  cat >"$TEST_CONFIG/skills.tsv" <<'EOF'
# skill	description
investigate	Investigate code paths and isolate likely root causes.
design-html	Create or refine HTML-first interface designs.
ios-qa	Review iOS flows and QA edge cases.
office-hours	Generate product-facing guidance for stakeholder discussions.
ship	Drive release and deployment execution steps.
EOF

  cat >"$TEST_CONFIG/modules.tsv" <<'EOF'
# module	skill	description
core	investigate	Core debugging and diagnosis workflows.
design	design-html	Design-oriented skills for UI and review work.
ios	ios-qa	iOS-focused implementation and QA support.
product	office-hours	Product planning and stakeholder communication support.
deploy	ship	Deployment and release execution skills.
EOF

  cat >"$TEST_CONFIG/profiles.tsv" <<'EOF'
# profile	module	description
backend-indie	core	Lean backend-focused workflow with debugging, product, and ship support.
backend-indie	product	Lean backend-focused workflow with debugging, product, and ship support.
backend-indie	deploy	Lean backend-focused workflow with debugging, product, and ship support.
gui-stage	core	GUI-building workflow with product and design support.
gui-stage	product	GUI-building workflow with product and design support.
gui-stage	design	GUI-building workflow with product and design support.
EOF

  for skill in investigate design-html ios-qa office-hours ship; do
    mkdir -p "$TEST_GSTACK/gstack-$skill"
    touch "$TEST_GSTACK/gstack-$skill/SKILL.md"
  done
  mkdir -p "$TEST_GSTACK/gstack"
  touch "$TEST_GSTACK/gstack/SKILL.md"

  for skill in gstack-investigate gstack-design-html gstack-ios-qa gstack-office-hours gstack-ship; do
    make_link "$HOME/.codex/skills/$skill" "$HOME/source/codex/$skill"
    make_link "$HOME/.config/opencode/skills/$skill" "$HOME/source/opencode/$skill"
  done

  for skill in investigate design-html ios-qa office-hours ship; do
    make_claude_skill "$HOME/.claude/skills" "$skill" "$HOME/source/claude"
  done
}

test_dry_run_does_not_move_entries() {
  setup_fixture

  "$SCRIPT" use backend-indie -n >/tmp/skilt-dry-run.out

  assert_exists "$HOME/.codex/skills/gstack-design-html"
  assert_exists "$HOME/.config/opencode/skills/gstack-design-html"
  assert_exists "$HOME/.claude/skills/design-html"
  assert_missing "$HOME/.codex/skills.disabled/gstack/gstack-design-html"
}

test_use_profile_moves_unknown_profile_skills_off_and_keeps_profile_modules() {
  setup_fixture

  "$SCRIPT" use backend-indie >/tmp/skilt-use.out

  assert_exists "$HOME/.codex/skills/gstack-investigate"
  assert_exists "$HOME/.codex/skills/gstack-office-hours"
  assert_exists "$HOME/.codex/skills/gstack-ship"
  assert_missing "$HOME/.codex/skills/gstack-design-html"
  assert_exists "$HOME/.codex/skills.disabled/gstack/gstack-design-html"
  assert_exists "$HOME/.codex/skills.disabled/gstack/gstack-ios-qa"

  assert_exists "$HOME/.config/opencode/skills/gstack-investigate"
  assert_missing "$HOME/.config/opencode/skills/gstack-design-html"
  assert_exists "$HOME/.config/opencode/skills.disabled/gstack/gstack-design-html"

  assert_exists "$HOME/.claude/skills/investigate"
  assert_exists "$HOME/.claude/skills/office-hours"
  assert_missing "$HOME/.claude/skills/design-html"
  assert_exists "$HOME/.claude/skills.disabled/gstack/design-html"
}

test_module_on_off_uses_explicit_and_implicit_modules() {
  setup_fixture

  "$SCRIPT" off design --agent codex >/tmp/skilt-off-design.out
  assert_missing "$HOME/.codex/skills/gstack-design-html"
  assert_exists "$HOME/.codex/skills.disabled/gstack/gstack-design-html"

  "$SCRIPT" on design-html --agent codex >/tmp/skilt-on-self-module.out
  assert_exists "$HOME/.codex/skills/gstack-design-html"
  assert_missing "$HOME/.codex/skills.disabled/gstack/gstack-design-html"
}

test_all_on_all_off_and_reset() {
  setup_fixture

  "$SCRIPT" all-off --agent codex >/tmp/skilt-all-off.out
  assert_missing "$HOME/.codex/skills/gstack-investigate"
  assert_missing "$HOME/.codex/skills/gstack-ship"
  assert_exists "$HOME/.codex/skills.disabled/gstack/gstack-investigate"
  assert_exists "$HOME/.codex/skills.disabled/gstack/gstack-ship"

  "$SCRIPT" all-on --agent codex >/tmp/skilt-all-on.out
  assert_exists "$HOME/.codex/skills/gstack-investigate"
  assert_exists "$HOME/.codex/skills/gstack-ship"

  "$SCRIPT" all-off --agent codex >/tmp/skilt-reset-prep.out
  "$SCRIPT" reset --agent codex >/tmp/skilt-reset.out
  assert_exists "$HOME/.codex/skills/gstack-investigate"
  assert_exists "$HOME/.codex/skills/gstack-ship"
}

test_doctor_validates_config_and_missing_functional_module() {
  setup_fixture

  "$SCRIPT" doctor >/tmp/skilt-doctor-ok.out
  grep -q "doctor ok" /tmp/skilt-doctor-ok.out || fail "doctor should pass valid fixture"

  printf 'orphan\tAd-hoc skill without an explicit functional module.\n' >>"$TEST_CONFIG/skills.tsv"
  mkdir -p "$TEST_GSTACK/gstack-orphan"
  touch "$TEST_GSTACK/gstack-orphan/SKILL.md"

  "$SCRIPT" doctor >/tmp/skilt-doctor-warn.out
  grep -q "WARN skill orphan only has implicit self-module" /tmp/skilt-doctor-warn.out || fail "doctor should warn about missing functional module"

  printf 'broken-module\tmissing-skill\tBroken module that points at an unknown skill.\n' >>"$TEST_CONFIG/modules.tsv"
  if "$SCRIPT" doctor >/tmp/skilt-doctor-error.out; then
    fail "doctor should fail on module referencing unknown skill"
  fi
  grep -q "ERROR modules.tsv references unknown skill: missing-skill" /tmp/skilt-doctor-error.out || fail "doctor should report unknown skill"
}

test_doctor_rejects_skill_without_description() {
  setup_fixture

  printf 'malformed-skill\n' >>"$TEST_CONFIG/skills.tsv"
  mkdir -p "$TEST_GSTACK/gstack-malformed-skill"
  touch "$TEST_GSTACK/gstack-malformed-skill/SKILL.md"

  if "$SCRIPT" doctor >/tmp/skilt-doctor-skill-description-error.out; then
    fail "doctor should fail on skills missing descriptions"
  fi

  grep -q "^ERROR skills.tsv missing description for skill: malformed-skill$" /tmp/skilt-doctor-skill-description-error.out || fail "doctor should report missing skill descriptions"
}

test_doctor_rejects_skill_with_blank_description() {
  setup_fixture

  printf 'blank-skill\t\n' >>"$TEST_CONFIG/skills.tsv"
  mkdir -p "$TEST_GSTACK/gstack-blank-skill"
  touch "$TEST_GSTACK/gstack-blank-skill/SKILL.md"

  if "$SCRIPT" doctor >/tmp/skilt-doctor-blank-skill-description-error.out; then
    fail "doctor should fail on blank skill descriptions"
  fi

  grep -q "^ERROR skills.tsv missing description for skill: blank-skill$" /tmp/skilt-doctor-blank-skill-description-error.out || fail "doctor should report blank skill descriptions"
}

test_doctor_rejects_module_without_description() {
  setup_fixture

  printf 'truncated-module\tinvestigate\n' >>"$TEST_CONFIG/modules.tsv"

  if "$SCRIPT" doctor >/tmp/skilt-doctor-module-description-error.out; then
    fail "doctor should fail on modules missing descriptions"
  fi

  grep -q "^ERROR modules.tsv missing description for module: truncated-module$" /tmp/skilt-doctor-module-description-error.out || fail "doctor should report missing module descriptions"
}

test_doctor_rejects_module_with_blank_description() {
  setup_fixture

  printf 'blank-module\tinvestigate\t\n' >>"$TEST_CONFIG/modules.tsv"

  if "$SCRIPT" doctor >/tmp/skilt-doctor-blank-module-description-error.out; then
    fail "doctor should fail on blank module descriptions"
  fi

  grep -q "^ERROR modules.tsv missing description for module: blank-module$" /tmp/skilt-doctor-blank-module-description-error.out || fail "doctor should report blank module descriptions"
}

test_doctor_rejects_profile_without_description() {
  setup_fixture

  printf 'truncated-profile\tcore\n' >>"$TEST_CONFIG/profiles.tsv"

  if "$SCRIPT" doctor >/tmp/skilt-doctor-profile-description-error.out; then
    fail "doctor should fail on profiles missing descriptions"
  fi

  grep -q "^ERROR profiles.tsv missing description for profile: truncated-profile$" /tmp/skilt-doctor-profile-description-error.out || fail "doctor should report missing profile descriptions"
}

test_doctor_rejects_profile_with_blank_description() {
  setup_fixture

  printf 'blank-profile\tcore\t\n' >>"$TEST_CONFIG/profiles.tsv"

  if "$SCRIPT" doctor >/tmp/skilt-doctor-blank-profile-description-error.out; then
    fail "doctor should fail on blank profile descriptions"
  fi

  grep -q "^ERROR profiles.tsv missing description for profile: blank-profile$" /tmp/skilt-doctor-blank-profile-description-error.out || fail "doctor should report blank profile descriptions"
}

test_list_commands_include_config_entities() {
  setup_fixture

  "$SCRIPT" list agents >/tmp/skilt-list-agents.out
  "$SCRIPT" list modules >/tmp/skilt-list-modules.out
  "$SCRIPT" list profiles >/tmp/skilt-list-profiles.out
  "$SCRIPT" list skills >/tmp/skilt-list-skills.out

  cat >/tmp/skilt-list-agents.expected <<'EOF'
claude
codex
opencode
EOF
  cmp -s /tmp/skilt-list-agents.out /tmp/skilt-list-agents.expected || fail "agents list should keep the current single-column output"

  cat >/tmp/skilt-list-modules.expected <<'EOF'
core
deploy
design
design-html
investigate
ios
ios-qa
office-hours
product
ship
EOF
  cmp -s /tmp/skilt-list-modules.out /tmp/skilt-list-modules.expected || fail "modules list should keep the current explicit and implicit module output"

  cat >/tmp/skilt-list-profiles.expected <<'EOF'
backend-indie
gui-stage
EOF
  cmp -s /tmp/skilt-list-profiles.out /tmp/skilt-list-profiles.expected || fail "profiles list should keep the current single-column output"

  cat >/tmp/skilt-list-skills.expected <<'EOF'
design-html
investigate
ios-qa
office-hours
ship
EOF
  cmp -s /tmp/skilt-list-skills.out /tmp/skilt-list-skills.expected || fail "skills list should keep the current single-column output"
}

test_list_verbose_prints_descriptions() {
  setup_fixture

  "$SCRIPT" list skills --verbose >/tmp/skilt-list-skills-verbose.out
  "$SCRIPT" list skills -v >/tmp/skilt-list-skills-short-verbose.out
  "$SCRIPT" list modules --verbose >/tmp/skilt-list-modules-verbose.out
  "$SCRIPT" list modules -v >/tmp/skilt-list-modules-short-verbose.out
  "$SCRIPT" list profiles --verbose >/tmp/skilt-list-profiles-verbose.out
  "$SCRIPT" list profiles -v >/tmp/skilt-list-profiles-short-verbose.out

  cat >/tmp/skilt-list-skills-verbose.expected <<'EOF'
design-html	Create or refine HTML-first interface designs.
investigate	Investigate code paths and isolate likely root causes.
ios-qa	Review iOS flows and QA edge cases.
office-hours	Generate product-facing guidance for stakeholder discussions.
ship	Drive release and deployment execution steps.
EOF
  cmp -s /tmp/skilt-list-skills-verbose.out /tmp/skilt-list-skills-short-verbose.out || fail "skills verbose flag spellings should produce identical output"
  sort /tmp/skilt-list-skills-verbose.out >/tmp/skilt-list-skills-verbose.sorted
  sort /tmp/skilt-list-skills-verbose.expected >/tmp/skilt-list-skills-verbose.expected.sorted
  cmp -s /tmp/skilt-list-skills-verbose.sorted /tmp/skilt-list-skills-verbose.expected.sorted || fail "skills verbose list should match the full described skill set"

  cat >/tmp/skilt-list-modules-verbose.expected <<'EOF'
core	Core debugging and diagnosis workflows.
design	Design-oriented skills for UI and review work.
design-html	Create or refine HTML-first interface designs.
deploy	Deployment and release execution skills.
investigate	Investigate code paths and isolate likely root causes.
ios	iOS-focused implementation and QA support.
ios-qa	Review iOS flows and QA edge cases.
office-hours	Generate product-facing guidance for stakeholder discussions.
product	Product planning and stakeholder communication support.
ship	Drive release and deployment execution steps.
EOF
  cmp -s /tmp/skilt-list-modules-verbose.out /tmp/skilt-list-modules-short-verbose.out || fail "modules verbose flag spellings should produce identical output"
  sort /tmp/skilt-list-modules-verbose.out >/tmp/skilt-list-modules-verbose.sorted
  sort /tmp/skilt-list-modules-verbose.expected >/tmp/skilt-list-modules-verbose.expected.sorted
  cmp -s /tmp/skilt-list-modules-verbose.sorted /tmp/skilt-list-modules-verbose.expected.sorted || fail "modules verbose list should match the full explicit and implicit module set"

  cat >/tmp/skilt-list-profiles-verbose.expected <<'EOF'
backend-indie	Lean backend-focused workflow with debugging, product, and ship support.
gui-stage	GUI-building workflow with product and design support.
EOF
  cmp -s /tmp/skilt-list-profiles-verbose.out /tmp/skilt-list-profiles-short-verbose.out || fail "profiles verbose flag spellings should produce identical output"
  cmp -s /tmp/skilt-list-profiles-verbose.out /tmp/skilt-list-profiles-verbose.expected || fail "profiles verbose list should print each logical profile once with descriptions"
}

test_list_verbose_rejects_agents() {
  setup_fixture

  if "$SCRIPT" list agents --verbose >/tmp/skilt-list-agents-verbose.out 2>&1; then
    fail "agents verbose list should be rejected"
  fi

  grep -q "^ERROR list --verbose only supports modules profiles skills$" /tmp/skilt-list-agents-verbose.out || fail "agents verbose rejection should explain supported entities"

  if "$SCRIPT" list agents -v >/tmp/skilt-list-agents-short-verbose.out 2>&1; then
    fail "agents short verbose list should be rejected"
  fi

  grep -q "^ERROR list --verbose only supports modules profiles skills$" /tmp/skilt-list-agents-short-verbose.out || fail "agents short verbose rejection should explain supported entities"
}

test_list_verbose_errors_when_skill_description_is_missing() {
  setup_fixture

  printf 'malformed-skill\n' >>"$TEST_CONFIG/skills.tsv"

  if "$SCRIPT" list skills --verbose >/tmp/skilt-list-skills-missing-description.out 2>&1; then
    fail "skills verbose list should fail when a description is missing"
  fi

  grep -q "^ERROR missing description for skill: malformed-skill$" /tmp/skilt-list-skills-missing-description.out || fail "skills verbose list should report missing skill descriptions"

  if "$SCRIPT" list skills -v >/tmp/skilt-list-skills-missing-description-short.out 2>&1; then
    fail "skills short verbose list should fail when a description is missing"
  fi

  grep -q "^ERROR missing description for skill: malformed-skill$" /tmp/skilt-list-skills-missing-description-short.out || fail "skills short verbose list should report missing skill descriptions"
}

test_list_verbose_errors_when_skill_description_is_blank() {
  setup_fixture

  printf 'blank-skill\t\n' >>"$TEST_CONFIG/skills.tsv"

  if "$SCRIPT" list skills --verbose >/tmp/skilt-list-skills-blank-description.out 2>&1; then
    fail "skills verbose list should fail when a description is blank"
  fi

  grep -q "^ERROR missing description for skill: blank-skill$" /tmp/skilt-list-skills-blank-description.out || fail "skills verbose list should report blank skill descriptions"

  if "$SCRIPT" list skills -v >/tmp/skilt-list-skills-blank-description-short.out 2>&1; then
    fail "skills short verbose list should fail when a description is blank"
  fi

  grep -q "^ERROR missing description for skill: blank-skill$" /tmp/skilt-list-skills-blank-description-short.out || fail "skills short verbose list should report blank skill descriptions"
}

test_list_verbose_errors_when_module_description_is_missing() {
  setup_fixture

  printf 'malformed-module\tinvestigate\t\n' >>"$TEST_CONFIG/modules.tsv"

  if "$SCRIPT" list modules --verbose >/tmp/skilt-list-modules-missing-description.out 2>&1; then
    fail "modules verbose list should fail when a description is missing"
  fi

  grep -q "^ERROR missing description for module: malformed-module$" /tmp/skilt-list-modules-missing-description.out || fail "modules verbose list should report missing module descriptions"

  if "$SCRIPT" list modules -v >/tmp/skilt-list-modules-missing-description-short.out 2>&1; then
    fail "modules short verbose list should fail when a description is missing"
  fi

  grep -q "^ERROR missing description for module: malformed-module$" /tmp/skilt-list-modules-missing-description-short.out || fail "modules short verbose list should report missing module descriptions"
}

test_list_verbose_errors_when_module_description_row_is_truncated() {
  setup_fixture

  printf 'truncated-module\tinvestigate\n' >>"$TEST_CONFIG/modules.tsv"

  if "$SCRIPT" list modules --verbose >/tmp/skilt-list-modules-truncated-description.out 2>&1; then
    fail "modules verbose list should fail when the description column is missing"
  fi

  grep -q "^ERROR missing description for module: truncated-module$" /tmp/skilt-list-modules-truncated-description.out || fail "modules verbose list should report truncated module descriptions"

  if "$SCRIPT" list modules -v >/tmp/skilt-list-modules-truncated-description-short.out 2>&1; then
    fail "modules short verbose list should fail when the description column is missing"
  fi

  grep -q "^ERROR missing description for module: truncated-module$" /tmp/skilt-list-modules-truncated-description-short.out || fail "modules short verbose list should report truncated module descriptions"
}

test_list_verbose_errors_when_profile_description_is_missing() {
  setup_fixture

  printf 'malformed-profile\tcore\t\n' >>"$TEST_CONFIG/profiles.tsv"

  if "$SCRIPT" list profiles --verbose >/tmp/skilt-list-profiles-missing-description.out 2>&1; then
    fail "profiles verbose list should fail when a description is missing"
  fi

  grep -q "^ERROR missing description for profile: malformed-profile$" /tmp/skilt-list-profiles-missing-description.out || fail "profiles verbose list should report missing profile descriptions"

  if "$SCRIPT" list profiles -v >/tmp/skilt-list-profiles-missing-description-short.out 2>&1; then
    fail "profiles short verbose list should fail when a description is missing"
  fi

  grep -q "^ERROR missing description for profile: malformed-profile$" /tmp/skilt-list-profiles-missing-description-short.out || fail "profiles short verbose list should report missing profile descriptions"
}

test_list_verbose_errors_when_profile_description_row_is_truncated() {
  setup_fixture

  printf 'truncated-profile\tcore\n' >>"$TEST_CONFIG/profiles.tsv"

  if "$SCRIPT" list profiles --verbose >/tmp/skilt-list-profiles-truncated-description.out 2>&1; then
    fail "profiles verbose list should fail when the description column is missing"
  fi

  grep -q "^ERROR missing description for profile: truncated-profile$" /tmp/skilt-list-profiles-truncated-description.out || fail "profiles verbose list should report truncated profile descriptions"

  if "$SCRIPT" list profiles -v >/tmp/skilt-list-profiles-truncated-description-short.out 2>&1; then
    fail "profiles short verbose list should fail when the description column is missing"
  fi

  grep -q "^ERROR missing description for profile: truncated-profile$" /tmp/skilt-list-profiles-truncated-description-short.out || fail "profiles short verbose list should report truncated profile descriptions"
}

test_doctor_rejects_inconsistent_module_descriptions() {
  setup_fixture

  printf 'design\tship\tConflicting module description for review coverage.\n' >>"$TEST_CONFIG/modules.tsv"

  if "$SCRIPT" doctor >/tmp/skilt-doctor-module-description-conflict.out; then
    fail "doctor should fail on inconsistent module descriptions"
  fi

  grep -q "^ERROR modules.tsv has inconsistent descriptions for module: design$" /tmp/skilt-doctor-module-description-conflict.out || fail "doctor should report module description conflicts"
}

test_doctor_rejects_inconsistent_profile_descriptions() {
  setup_fixture

  printf 'backend-indie\tdesign\tConflicting profile description for review coverage.\n' >>"$TEST_CONFIG/profiles.tsv"

  if "$SCRIPT" doctor >/tmp/skilt-doctor-profile-description-conflict.out; then
    fail "doctor should fail on inconsistent profile descriptions"
  fi

  grep -q "^ERROR profiles.tsv has inconsistent descriptions for profile: backend-indie$" /tmp/skilt-doctor-profile-description-conflict.out || fail "doctor should report profile description conflicts"
}

test_count_reports_config_install_and_agent_totals() {
  setup_fixture

  "$SCRIPT" count >/tmp/skilt-count.out

  grep -q "^configured_skills=5$" /tmp/skilt-count.out || fail "count should report configured skill total"
  grep -q "^installed_skills=6$" /tmp/skilt-count.out || fail "count should include gstack root in installed total"
  grep -q "^installed_non_root_skills=5$" /tmp/skilt-count.out || fail "count should report installed non-root skills"
  grep -q "^claude[[:space:]]*enabled=5 disabled=0$" /tmp/skilt-count.out || fail "count should report claude totals"
  grep -q "^codex[[:space:]]*enabled=5 disabled=0$" /tmp/skilt-count.out || fail "count should report codex totals"
  grep -q "^opencode[[:space:]]enabled=5 disabled=0$" /tmp/skilt-count.out || fail "count should report opencode totals"
}

test_diff_reports_config_install_and_agent_lists() {
  setup_fixture

  "$SCRIPT" off design-html --agent codex >/tmp/skilt-diff-prep.out
  "$SCRIPT" diff --agent codex >/tmp/skilt-diff.out

  grep -q "^configured_not_installed:$" /tmp/skilt-diff.out || fail "diff should include configured_not_installed header"
  grep -q "^  (none)$" /tmp/skilt-diff.out || fail "diff should print none for empty sections"
  grep -q "^installed_not_configured:$" /tmp/skilt-diff.out || fail "diff should include installed_not_configured header"
  grep -q "^  gstack$" /tmp/skilt-diff.out || fail "diff should report gstack root as installed but not configured"
  grep -q "^enabled_by_agent:$" /tmp/skilt-diff.out || fail "diff should include enabled_by_agent header"
  grep -q "^  codex: investigate, ios-qa, office-hours, ship$" /tmp/skilt-diff.out || fail "diff should list enabled codex skills"
  grep -q "^disabled_by_agent:$" /tmp/skilt-diff.out || fail "diff should include disabled_by_agent header"
  grep -q "^  codex: design-html$" /tmp/skilt-diff.out || fail "diff should list disabled codex skills"
}

test_dry_run_does_not_move_entries
test_use_profile_moves_unknown_profile_skills_off_and_keeps_profile_modules
test_module_on_off_uses_explicit_and_implicit_modules
test_all_on_all_off_and_reset
test_doctor_validates_config_and_missing_functional_module
test_doctor_rejects_skill_without_description
test_doctor_rejects_skill_with_blank_description
test_doctor_rejects_module_without_description
test_doctor_rejects_module_with_blank_description
test_doctor_rejects_profile_without_description
test_doctor_rejects_profile_with_blank_description
test_list_commands_include_config_entities
test_list_verbose_prints_descriptions
test_list_verbose_rejects_agents
test_list_verbose_errors_when_skill_description_is_missing
test_list_verbose_errors_when_skill_description_is_blank
test_list_verbose_errors_when_module_description_is_missing
test_list_verbose_errors_when_module_description_row_is_truncated
test_list_verbose_errors_when_profile_description_is_missing
test_list_verbose_errors_when_profile_description_row_is_truncated
test_doctor_rejects_inconsistent_module_descriptions
test_doctor_rejects_inconsistent_profile_descriptions
test_count_reports_config_install_and_agent_totals
test_diff_reports_config_install_and_agent_lists

echo "All skilt tests passed"
