#!/usr/bin/env bash
# Flag Swift files that declare more than one top-level type (class/struct/
# enum/actor/protocol). Top-level = the declaration starts in column 0.
# main.swift is exempt — entry-point statements live there, but it should
# still declare zero top-level types (the rule covers that via the same check).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

# Find .swift files under Sources/ and Examples/, excluding generated/vendored trees.
files=$(find Sources Examples -name '*.swift' \
  -not -path '*/.build/*' \
  -not -path '*/build/*' \
  -not -path '*/vendor/*' \
  -not -path '*/artifacts/*' 2>/dev/null || true)

violations=""
for f in $files; do
  base=$(basename "$f")
  # Count top-level type declarations (must start in column 0).
  # Matches: [public/internal/private/fileprivate/open] [final] class|struct|enum|actor|protocol Name
  count=$(grep -cE '^(public |internal |private |fileprivate |open )?(final |indirect )?(class|struct|enum|actor|protocol) [A-Z]' "$f" || true)

  if [[ "$base" == "main.swift" ]]; then
    # main.swift: zero top-level types.
    if [[ "$count" -gt 0 ]]; then
      lines=$(grep -nE '^(public |internal |private |fileprivate |open )?(final |indirect )?(class|struct|enum|actor|protocol) [A-Z]' "$f")
      violations+="$f: main.swift should declare no top-level types\n$lines\n"
    fi
    continue
  fi

  if [[ "$count" -gt 1 ]]; then
    lines=$(grep -nE '^(public |internal |private |fileprivate |open )?(final |indirect )?(class|struct|enum|actor|protocol) [A-Z]' "$f")
    violations+="$f: $count top-level types (expected 1)\n$lines\n"
  fi
done

if [[ -n "$violations" ]]; then
  echo -e "$violations"
  echo "→ One top-level type per file. Split or move helpers into the same type's extension."
  echo "  Carve-outs: tightly coupled private helpers, a small model+store pair (see rule.md)."
  exit 1
fi
