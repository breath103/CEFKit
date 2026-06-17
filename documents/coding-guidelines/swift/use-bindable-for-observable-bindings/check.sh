#!/usr/bin/env bash
# Flag hand-rolled Binding(get:set:) closures in SwiftUI views.
# These are almost always a missing @Bindable on an @Observable model.
# Carve-out: a computed/derived binding is legitimate — review by hand.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

files=$(find Sources Examples -name '*.swift' \
  -not -path '*/.build/*' \
  -not -path '*/build/*' \
  -not -path '*/vendor/*' \
  -not -path '*/artifacts/*' 2>/dev/null || true)

hits=""
for f in $files; do
  # Match `Binding(` on a line that also opens with get: on the next few
  # lines. Simpler heuristic: any `Binding(\n*\s*get:` — grep multi-line via -Pz.
  if grep -PzoH '(?s)Binding\s*\(\s*\n?\s*get\s*:' "$f" >/dev/null 2>&1; then
    line=$(grep -nE 'Binding\s*\($' "$f" || grep -nE 'Binding\s*\(\s*get:' "$f" || true)
    hits+="$f: $line"$'\n'
  fi
done

if [[ -n "$hits" ]]; then
  echo "$hits"
  echo "→ Prefer @Bindable var model: ... and \$model.property. See rule.md for the computed-binding carve-out."
  exit 1
fi
