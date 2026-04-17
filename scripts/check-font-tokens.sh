#!/usr/bin/env bash
# check-font-tokens.sh
#
# Enforces the design-system font rules:
#   1. No `.font(.system(size:`        anywhere in app code
#   2. No bare `.fontWeight(`          anywhere in app code
#   3. No `.figtree(` / `.outfit(`     anywhere in app code (use tokens)
#
# Playgrounds, the token definition file itself, and worktrees are exempt.
#
# Exit codes: 0 = clean, 1 = violations found.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXCLUDES=(
  --exclude-dir=".build"
  --exclude-dir="DerivedData"
  --exclude-dir=".claude"
  --exclude-dir="Pods"
  --exclude="*.playground"
  --exclude="AppFont.swift"
  --exclude="AppAppearance.swift"
)

SCAN_PATH="ModelRunner"

status=0

# Matches lines that are wholly a comment (optional leading whitespace then //).
# Doesn't catch trailing comments, but trailing `// don't use .fontWeight` is
# rare enough that we can fix it by hand if it triggers a false positive.
COMMENT_LINE_RE=':[[:space:]]*[0-9]+:[[:space:]]*//'

check() {
  local label="$1"
  local pattern="$2"
  local hits
  hits=$(grep -RInE "$pattern" "${EXCLUDES[@]}" "$SCAN_PATH" --include='*.swift' | grep -vE "$COMMENT_LINE_RE" || true)
  if [[ -n "$hits" ]]; then
    echo "❌ $label"
    echo "$hits"
    echo
    status=1
  fi
}

check "Banned: .font(.system(size:)) — use .appBody / .appCaption / .iconMD etc." \
      '\.font\(\.system\(size:'

check "Banned: bare .fontWeight(...) — weight lives inside the token" \
      '\.fontWeight\('

check "Banned: .figtree(...) / .outfit(...) — use .appBody / .appHeadline etc." \
      '\.(figtree|outfit)\('

if [[ $status -eq 0 ]]; then
  echo "✅ font tokens clean"
fi

exit $status
