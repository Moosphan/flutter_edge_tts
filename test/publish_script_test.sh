#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_BIN="$TMP_DIR/bin"
CALL_LOG="$TMP_DIR/flutter-calls.log"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/flutter" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALL_LOG"
EOF
cat > "$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "status --porcelain" ]]; then
  exit 0
fi
exit 0
EOF
cat > "$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$FAKE_BIN/nc" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAKE_BIN"/*

export CALL_LOG
PATH="$FAKE_BIN:$PATH" bash "$ROOT_DIR/scripts/publish.sh" \
  --skip-checks \
  --yes \
  --proxy http://127.0.0.1:7897

grep -Fx 'pub publish --dry-run' "$CALL_LOG"
grep -Fx 'pub publish --force' "$CALL_LOG"

grep -Fq './scripts/publish.sh --dry-run-only' "$ROOT_DIR/README.md"
grep -Fq './scripts/publish.sh --yes' "$ROOT_DIR/README.md"
grep -Fxq '  flutter_edge_tts: ^0.0.3' "$ROOT_DIR/README.md"
grep -Fq './scripts/publish.sh --dry-run-only' "$ROOT_DIR/README.zh-CN.md"
grep -Fq './scripts/publish.sh --yes' "$ROOT_DIR/README.zh-CN.md"
grep -Fxq '  flutter_edge_tts: ^0.0.3' "$ROOT_DIR/README.zh-CN.md"

printf 'publish script regression test passed\n'
