#!/bin/bash
# Installs XcodeGen for CI from its official release zip, pinned by version and sha256 (docs/M7D_CONTRACT.md §3.3 4,
# 0d-28). Until 1.3 every job ran `brew install xcodegen`, whose version is the formula baked into the runner image:
# it differs from one image to the next (1.3's last run, 44474759145, had 2.46.0 in every job; Homebrew got 2.47.0 on
# 11/17, and 2.47 changed the scheme's defaults, so the project it makes differs). 2.46.0 is the generator of 1.3's CI,
# so with it D0 changes only the Xcode.
#
# What it does: downloads xcodegen.zip of the release, fails unless its sha256 is the one below (read from the
# GitHub release's digest on 2026-11-20, [S58]), unpacks it into the job's temporary folder (the zip's own layout,
# so the binary finds its share/ folder next to it), puts its bin folder first in PATH for this and the job's later
# steps ($GITHUB_PATH), and fails unless `xcodegen --version` then says this version.
#
# Used by every job that generates a project (build.yml, testflight.yml, ja-baseline.yml, store-shots.yml, duo.yml;
# compat-v1-0 on macos-26 too), as "$GITHUB_WORKSPACE/tools/ci/install-xcodegen.sh" (ja-baseline.yml's steps run in
# the reference commit's checkout, which does not have this file). The version moves only in a commit that changes
# VERSION and SHA256 here on purpose; if 2.46.0 does not run on the xcode-27 image, the contract's fallback is 2.48.0
# (sha256 620c9f0dc10849f94728ab5df52d225ebab8187439dd6fee1925e59e80dff892) in every job at once, written in
# docs/M7D.md.
set -euo pipefail

VERSION="2.46.0"
SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
URL="https://github.com/yonaskolb/XcodeGen/releases/download/$VERSION/xcodegen.zip"

ROOT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/xcodegen-$VERSION"
ZIP="$ROOT/xcodegen.zip"

fail() {
  echo "::error::$1"
  exit 1
}

mkdir -p "$ROOT"
rm -f "$ZIP"
curl --fail --location --silent --show-error --retry 3 --retry-delay 5 --output "$ZIP" "$URL" \
  || fail "XcodeGen $VERSION could not be downloaded from $URL."

GOT_SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo "xcodegen.zip: sha256 $GOT_SHA ($(wc -c < "$ZIP" | tr -d ' ') bytes)"
[ "$GOT_SHA" = "$SHA256" ] \
  || fail "xcodegen.zip of $VERSION has the sha256 $GOT_SHA, not $SHA256 (docs/M7D_CONTRACT.md §3.3 4). Nothing is installed."

# A folder of its own each time (nothing of an earlier unpacking in it). ditto keeps the zip's file modes.
DEST="$(mktemp -d "$ROOT/unpacked.XXXXXX")"
ditto -x -k "$ZIP" "$DEST" || fail "xcodegen.zip could not be unpacked."

# The release zip holds xcodegen/bin/xcodegen (and xcodegen/share/xcodegen/…): the one file named xcodegen.
BIN="$(find "$DEST" -type f -name xcodegen)"
[ -n "$BIN" ] || fail "No file named xcodegen in xcodegen.zip of $VERSION."
[ "$(printf '%s\n' "$BIN" | wc -l | tr -d ' ')" = 1 ] || fail "More than one file named xcodegen in xcodegen.zip: $BIN"
[ -x "$BIN" ] || chmod u+x "$BIN"
BIN_DIR="$(cd "$(dirname "$BIN")" && pwd -P)"

export PATH="$BIN_DIR:$PATH"
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$BIN_DIR" >> "$GITHUB_PATH"
else
  echo "(not in GitHub Actions: add $BIN_DIR to PATH yourself)"
fi

FOUND="$(command -v xcodegen || true)"
[ "$FOUND" = "$BIN_DIR/xcodegen" ] || fail "xcodegen in PATH is ${FOUND:-nothing}, not $BIN_DIR/xcodegen."
SAYS="$(xcodegen --version 2>&1 || true)"
echo "xcodegen --version: $SAYS ($FOUND)"
GOT_VERSION="$(printf '%s\n' "$SAYS" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
[ "$GOT_VERSION" = "$VERSION" ] || fail "xcodegen --version says \"$SAYS\", not $VERSION (docs/M7D_CONTRACT.md §3.3 4)."
