#!/usr/bin/env bash
# Pre-PR health check: format then lint.
# Not run on CI (yet) — agents and humans are expected to run this before opening a PR.
# See CLAUDE.md.

set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-fix}"  # fix (default) | check

if ! command -v swiftformat >/dev/null; then
  echo "swiftformat not installed. brew install swiftformat" >&2
  exit 1
fi
if ! command -v swiftlint >/dev/null; then
  echo "swiftlint not installed. brew install swiftlint" >&2
  exit 1
fi

case "$MODE" in
  fix)
    echo "==> swiftformat (write)"
    swiftformat .
    echo "==> swiftlint --fix"
    swiftlint --fix --quiet
    echo "==> swiftlint"
    swiftlint --quiet
    ;;
  check)
    echo "==> swiftformat --lint"
    swiftformat --lint .
    echo "==> swiftlint --strict"
    swiftlint --strict --quiet
    ;;
  *)
    echo "usage: $0 [fix|check]" >&2
    exit 2
    ;;
esac

echo "==> lint OK"
