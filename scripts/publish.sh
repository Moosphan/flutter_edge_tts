#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRY_RUN_ONLY=0
SKIP_CHECKS=0
ALLOW_DIRTY=0
AUTO_CONFIRM=0
PUBLISH_PROXY=""
ENV_UNSET_ARGS=()

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
  ./scripts/publish.sh --proxy <your-proxy-url>
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

detect_macos_proxy() {
  command -v scutil >/dev/null 2>&1 || return 1

  local proxy_info http_enabled http_host http_port https_enabled https_host https_port
  proxy_info="$(scutil --proxy 2>/dev/null || true)"
  [[ -n "$proxy_info" ]] || return 1

  http_enabled="$(printf '%s\n' "$proxy_info" | awk '/HTTPEnable/ {print $3; exit}')"
  http_host="$(printf '%s\n' "$proxy_info" | awk '/HTTPProxy/ {print $3; exit}')"
  http_port="$(printf '%s\n' "$proxy_info" | awk '/HTTPPort/ {print $3; exit}')"
  https_enabled="$(printf '%s\n' "$proxy_info" | awk '/HTTPSEnable/ {print $3; exit}')"
  https_host="$(printf '%s\n' "$proxy_info" | awk '/HTTPSProxy/ {print $3; exit}')"
  https_port="$(printf '%s\n' "$proxy_info" | awk '/HTTPSPort/ {print $3; exit}')"

  if [[ "${https_enabled:-0}" == "1" && -n "${https_host:-}" && -n "${https_port:-}" ]]; then
    printf 'http://%s:%s\n' "$https_host" "$https_port"
    return 0
  fi

  if [[ "${http_enabled:-0}" == "1" && -n "${http_host:-}" && -n "${http_port:-}" ]]; then
    printf 'http://%s:%s\n' "$http_host" "$http_port"
    return 0
  fi

  return 1
}

setup_publish_env() {
  ENV_UNSET_ARGS=(
    -u PUB_HOSTED_URL
    -u FLUTTER_STORAGE_BASE_URL
  )

  if [[ -z "$PUBLISH_PROXY" ]]; then
    PUBLISH_PROXY="$(detect_macos_proxy || true)"
    if [[ -n "$PUBLISH_PROXY" ]]; then
      log info "Detected macOS system proxy: $PUBLISH_PROXY"
    fi
  fi

  if [[ -n "$PUBLISH_PROXY" ]]; then
    export HTTP_PROXY="$PUBLISH_PROXY"
    export HTTPS_PROXY="$PUBLISH_PROXY"
    export ALL_PROXY="$PUBLISH_PROXY"
    export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost}"
    log info "Using proxy: $PUBLISH_PROXY"
  else
    ENV_UNSET_ARGS+=(
      -u HTTP_PROXY
      -u HTTPS_PROXY
      -u ALL_PROXY
      -u http_proxy
      -u https_proxy
      -u all_proxy
    )
  fi
}

validate_proxy() {
  [[ -n "$PUBLISH_PROXY" ]] || return 0

  local proxy_host proxy_port remainder
  remainder="${PUBLISH_PROXY#*://}"
  proxy_host="${remainder%%:*}"
  proxy_port="${remainder##*:}"

  if [[ -z "$proxy_host" || -z "$proxy_port" || "$proxy_host" == "$proxy_port" ]]; then
    fail "Invalid proxy URL: $PUBLISH_PROXY"
  fi

  if ! nc -z "$proxy_host" "$proxy_port" >/dev/null 2>&1; then
    fail "Proxy is not reachable at $proxy_host:$proxy_port. Check your local proxy app and port."
  fi
}

check_pub_connectivity() {
  local curl_cmd=(curl -I --max-time 15 https://pub.dev)
  if [[ -n "$PUBLISH_PROXY" ]]; then
    curl_cmd+=(--proxy "$PUBLISH_PROXY")
  fi

  if ! "${curl_cmd[@]}" >/dev/null 2>&1; then
    if [[ -n "$PUBLISH_PROXY" ]]; then
      fail "Unable to reach pub.dev through proxy $PUBLISH_PROXY."
    fi
    fail "Unable to reach pub.dev directly. If your network needs a proxy, rerun with --proxy <your-proxy-url>"
  fi
}

run_pub_command() {
  env "${ENV_UNSET_ARGS[@]}" flutter pub "$@"
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

if [[ -n "${PUB_HOSTED_URL:-}" ]]; then
  log info "Temporarily ignoring PUB_HOSTED_URL=${PUB_HOSTED_URL} for official pub.dev publishing."
fi

if [[ -n "${FLUTTER_STORAGE_BASE_URL:-}" ]]; then
  log info "Temporarily ignoring FLUTTER_STORAGE_BASE_URL=${FLUTTER_STORAGE_BASE_URL} for official pub.dev publishing."
fi

setup_publish_env
validate_proxy
check_pub_connectivity

if [[ "$SKIP_CHECKS" -ne 1 ]]; then
  log step "Running flutter analyze"
  flutter analyze

  log step "Running flutter test"
  flutter test
fi

log step "Running flutter pub publish --dry-run"
run_pub_command publish --dry-run

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
run_pub_command publish

log done "Publish command completed."
