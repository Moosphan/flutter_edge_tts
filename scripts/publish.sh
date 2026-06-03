#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRY_RUN_ONLY=0
SKIP_CHECKS=0
ALLOW_DIRTY=0
AUTO_CONFIRM=0
PUBLISH_PROXY=""

print_usage() {
  cat <<'EOF'
Usage: ./scripts/publish.sh [options]

Options:
  --dry-run-only     Run checks and `flutter pub publish --dry-run` only.
  --skip-checks      Skip `flutter analyze` and `flutter test`.
  --allow-dirty      Allow publishing from a dirty git worktree.
  --yes              Skip the final publish confirmation prompt.
  --proxy URL        Use a proxy for Google OAuth and pub.dev requests.
  --help             Show this help message.

Examples:
  ./scripts/publish.sh
  ./scripts/publish.sh --dry-run-only
  ./scripts/publish.sh --proxy http://127.0.0.1:7890
EOF
}

log() {
  printf '\n[%s] %s\n' "$1" "$2"
}

fail() {
  printf '\n[error] %s\n' "$1" >&2
  exit 1
}

confirm() {
  local prompt="$1"
  local answer
  read -r -p "$prompt [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run-only)
      DRY_RUN_ONLY=1
      ;;
    --skip-checks)
      SKIP_CHECKS=1
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      ;;
    --yes)
      AUTO_CONFIRM=1
      ;;
    --proxy)
      [[ $# -ge 2 ]] || fail "--proxy requires a value."
      PUBLISH_PROXY="$2"
      shift
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
  shift
done

cd "$ROOT_DIR"

command -v flutter >/dev/null 2>&1 || fail "Flutter is not installed or not in PATH."
command -v git >/dev/null 2>&1 || fail "Git is not installed or not in PATH."

if [[ ! -f pubspec.yaml ]]; then
  fail "pubspec.yaml not found. Run this script inside the flutter_edge_tts repository."
fi

if [[ "$ALLOW_DIRTY" -ne 1 ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    fail "Git worktree is dirty. Commit or stash changes, or rerun with --allow-dirty."
  fi
fi

if [[ -n "$PUBLISH_PROXY" ]]; then
  export HTTP_PROXY="$PUBLISH_PROXY"
  export HTTPS_PROXY="$PUBLISH_PROXY"
  export ALL_PROXY="$PUBLISH_PROXY"
  export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost}"
  log info "Using proxy: $PUBLISH_PROXY"
fi

if [[ -n "${PUB_HOSTED_URL:-}" ]]; then
  log info "Temporarily ignoring PUB_HOSTED_URL=${PUB_HOSTED_URL} for official pub.dev publishing."
fi

if [[ -n "${FLUTTER_STORAGE_BASE_URL:-}" ]]; then
  log info "Temporarily ignoring FLUTTER_STORAGE_BASE_URL=${FLUTTER_STORAGE_BASE_URL} for official pub.dev publishing."
fi

if [[ "$SKIP_CHECKS" -ne 1 ]]; then
  log step "Running flutter analyze"
  flutter analyze

  log step "Running flutter test"
  flutter test
fi

log step "Running flutter pub publish --dry-run"
env -u PUB_HOSTED_URL -u FLUTTER_STORAGE_BASE_URL flutter pub publish --dry-run

if [[ "$DRY_RUN_ONLY" -eq 1 ]]; then
  log done "Dry run finished successfully."
  exit 0
fi

if [[ "$AUTO_CONFIRM" -ne 1 ]]; then
  if ! confirm "Dry run passed. Publish flutter_edge_tts to pub.dev now?"; then
    log info "Publish cancelled."
    exit 0
  fi
fi

log step "Publishing to pub.dev"
env -u PUB_HOSTED_URL -u FLUTTER_STORAGE_BASE_URL flutter pub publish

log done "Publish command completed."
