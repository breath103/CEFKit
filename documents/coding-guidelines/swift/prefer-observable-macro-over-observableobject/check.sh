#!/usr/bin/env bash
# Flag any use of the legacy Combine-based observation API in Swift files.
# Trips on: ObservableObject conformance, @Published, @ObservedObject,
# @StateObject, @EnvironmentObject.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

files=$(find Sources Examples -name '*.swift' \
  -not -path '*/.build/*' \
  -not -path '*/build/*' \
  -not -path '*/vendor/*' \
  -not -path '*/artifacts/*' 2>/dev/null || true)

# Pattern matches:
#   : ObservableObject              (conformance, possibly mid-list)
#   @Published
#   @ObservedObject
#   @StateObject
#   @EnvironmentObject
pattern='(: *ObservableObject|, *ObservableObject|@Published|@ObservedObject|@StateObject|@EnvironmentObject)'

hits=""
for f in $files; do
  matches=$(grep -nE "$pattern" "$f" || true)
  if [[ -n "$matches" ]]; then
    while IFS= read -r line; do
      hits+="$f:$line"$'\n'
    done <<< "$matches"
  fi
done

if [[ -n "$hits" ]]; then
  echo "$hits"
  echo "→ Use @Observable (Observation framework). See rule.md for the carve-outs."
  exit 1
fi
