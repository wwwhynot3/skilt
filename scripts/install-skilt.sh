#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILT="$REPO_ROOT/skilt"
SOURCE_CONFIG_DIR="$REPO_ROOT/gstack-skill-config"

BIN_DIR=""
CONFIG_ROOT=""

die() {
  echo "ERROR $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/install-skilt.sh [--bin-dir PATH] [--config-dir PATH]

Options:
  --bin-dir PATH     Directory that will receive the generated skilt wrapper.
  --config-dir PATH  Directory that will receive the copied skilt runtime.

If either option is omitted, the installer prompts for it.
EOF
}

expand_path() {
  local path="$1"

  case "$path" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${path#~/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

prompt_if_empty() {
  local label="$1"
  local value="${2:-}"

  if [ -n "$value" ]; then
    expand_path "$value"
    return 0
  fi

  printf '%s: ' "$label" >&2
  IFS= read -r value || true
  [ -n "$value" ] || die "$label is required"
  expand_path "$value"
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
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
    shift
  done
}

ensure_sources() {
  [ -f "$SOURCE_SKILT" ] || die "missing source script: $SOURCE_SKILT"
  [ -d "$SOURCE_CONFIG_DIR" ] || die "missing source config dir: $SOURCE_CONFIG_DIR"
}

prepare_dir() {
  local path="$1"
  install -d "$path"
  cd "$path" && pwd
}

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

  install -d "$install_root"
  install -m 755 "$SOURCE_SKILT" "$real_skilt"
  rm -rf "$installed_config_dir"
  cp -R "$SOURCE_CONFIG_DIR" "$installed_config_dir"
  write_wrapper "$bin_dir/skilt" "$real_skilt" "$installed_config_dir"
}

main() {
  parse_args "$@"
  ensure_sources

  BIN_DIR="$(prompt_if_empty "Bin dir" "$BIN_DIR")"
  CONFIG_ROOT="$(prompt_if_empty "Config dir" "$CONFIG_ROOT")"

  BIN_DIR="$(prepare_dir "$BIN_DIR")"
  CONFIG_ROOT="$(prepare_dir "$CONFIG_ROOT")"

  install_runtime "$BIN_DIR" "$CONFIG_ROOT"
}

main "$@"
