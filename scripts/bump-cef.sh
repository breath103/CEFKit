#!/usr/bin/env bash
# scripts/bump-cef.sh — full pipeline for updating CEF to a new version.
#
# What it does:
#   1. Verifies the new CEF version exists on cef-builds.spotifycdn.com
#   2. Updates CEF_VERSION in scripts/fetch-cef.sh
#   3. Re-fetches the CEF binary distribution into vendor/cef/
#   4. Re-vendors Sources/ChromiumWrapper/include/ and libcef_dll/ from the new tarball
#      (this is the part that MUST be in lockstep with the framework binary —
#       header API changes mean wrapper sources won't compile against an old vendored copy)
#   5. Rebuilds artifacts/CEF.xcframework.zip
#   6. Computes the new sha256
#   7. Updates Package.swift binaryTarget URL + checksum to the new tag
#   8. Tells you what to commit + tag + release
#
# Usage:
#   ./scripts/bump-cef.sh <CEF_VERSION> <NEW_TAG>
#
#   CEF_VERSION example: 145.0.5+gabc1234+chromium-145.0.7600.100
#                        (copy-paste from https://cef-builds.spotifycdn.com)
#   NEW_TAG     example: v0.2.0
#
# Pre-conditions:
#   - You're on a clean checkout (no uncommitted changes)
#   - You're on main and origin/main is up to date
#   - Homebrew has cmake + ninja available (CMakeLists requires them)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CEF_VERSION="${1:-}"
NEW_TAG="${2:-}"
PLATFORM="macosarm64"

if [[ -z "$CEF_VERSION" || -z "$NEW_TAG" ]]; then
  echo "usage: $0 <CEF_VERSION> <NEW_TAG>" >&2
  echo "  example: $0 145.0.5+gabc1234+chromium-145.0.7600.100 v0.2.0" >&2
  exit 1
fi

if ! [[ "$NEW_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: NEW_TAG must look like v0.2.0" >&2
  exit 1
fi

# Refuse to run with uncommitted changes — bumping touches Package.swift, the
# wrapper sources, fetch-cef.sh, and the framework artifact. You want one
# clean commit per bump.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "error: working tree has uncommitted changes. commit or stash first." >&2
  exit 1
fi

if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
  echo "error: must run on main. you are on $(git rev-parse --abbrev-ref HEAD)." >&2
  exit 1
fi

if git rev-parse --verify --quiet "$NEW_TAG" >/dev/null; then
  echo "error: tag $NEW_TAG already exists locally" >&2
  exit 1
fi

# 1. Verify the version + tarball exist
URL="https://cef-builds.spotifycdn.com/cef_binary_${CEF_VERSION//+/%2B}_${PLATFORM}.tar.bz2"
echo "==> verifying CEF $CEF_VERSION exists at $URL"
if ! curl --output /dev/null --silent --head --fail "$URL"; then
  echo "error: CEF tarball not found at $URL" >&2
  echo "       check the version string at https://cef-builds.spotifycdn.com/index.html" >&2
  exit 1
fi

# 2. Update fetch-cef.sh's pinned version
echo "==> patching scripts/fetch-cef.sh"
sed -i '' -E "s|^CEF_VERSION=.*|CEF_VERSION=\"$CEF_VERSION\"|" scripts/fetch-cef.sh
grep '^CEF_VERSION=' scripts/fetch-cef.sh

# 3. Re-fetch the CEF binary distribution (drops vendor/cef/ entirely first)
echo "==> wiping vendor/cef/ and re-fetching"
rm -rf vendor/cef
./scripts/fetch-cef.sh

# 4. Re-vendor wrapper sources + headers. This is the part that's easy to
#    forget — and silently wrong if you skip it (vtable layouts drift).
echo "==> re-vendoring Sources/ChromiumWrapper/{include,libcef_dll}"
rm -rf Sources/ChromiumWrapper/include Sources/ChromiumWrapper/libcef_dll
cp -R vendor/cef/include    Sources/ChromiumWrapper/include
cp -R vendor/cef/libcef_dll Sources/ChromiumWrapper/libcef_dll

# 5. Rebuild the xcframework + zip
echo "==> rebuilding artifacts/CEF.xcframework"
rm -rf artifacts/CEF.xcframework artifacts/CEF.xcframework.zip
./scripts/build-cef-artifacts.sh
( cd artifacts && ditto -c -k --sequesterRsrc --keepParent "CEF.xcframework" "CEF.xcframework.zip" )

# 6. Compute checksum
NEW_CHECKSUM=$(shasum -a 256 artifacts/CEF.xcframework.zip | awk '{print $1}')
echo "==> new zip sha256: $NEW_CHECKSUM"

# 7. Patch Package.swift binaryTarget URL + checksum
echo "==> patching Package.swift binaryTarget"
PYTHONIOENCODING=utf-8 python3 - <<PY
import re, pathlib
p = pathlib.Path("Package.swift")
s = p.read_text()
# Replace the URL + checksum lines inside the CCEF binaryTarget block.
s = re.sub(
    r'url:\s*"https://github\.com/[^"]+/CEF\.xcframework\.zip"',
    f'url: "https://github.com/breath103/CEFKit/releases/download/{"$NEW_TAG"}/CEF.xcframework.zip"',
    s, count=1)
s = re.sub(
    r'checksum:\s*"[0-9a-f]{64}"',
    f'checksum: "{"$NEW_CHECKSUM"}"',
    s, count=1)
p.write_text(s)
PY
grep -E "url:|checksum:" Package.swift | head -4

# 8. Verify everything builds against the new headers
echo "==> swift build -c release"
swift build -c release >/dev/null

cat <<EOF

==> bump-cef done. To publish, run:

    git add scripts/fetch-cef.sh Sources/ChromiumWrapper Package.swift
    git commit -m "Bump CEF to $CEF_VERSION ($NEW_TAG)"
    git tag $NEW_TAG
    git push origin main
    git push origin $NEW_TAG

    gh release create $NEW_TAG \\
      artifacts/CEF.xcframework.zip \\
      --title "$NEW_TAG — CEF ${CEF_VERSION%%+*} (arm64)" \\
      --notes "Bump to CEF $CEF_VERSION."

EOF
