#!/bin/bash
# The stdout and stderr of the apps an XCUITest run launched, taken out of its result bundle (docs/M7D_CONTRACT.md §3.3 3,
# §3.8; docs/M7D.md, D0b). On the iOS 27 simulators `log show` cannot compose the app's NSLog lines (tools/ci/log-reach.sh),
# and an app that XCUITest launches is not xcodebuild's child, so its lines are not in the test log either. XCTest keeps
# the stdout and stderr of each app it launched in the result bundle (StandardOutputAndStandardError-<bundle id>.txt), and
# NSLog writes its lines to stderr as well; `xcrun xcresulttool export diagnostics` takes them out.
#
# Usage: tools/ci/xcresult-app-output.sh <output file> <result bundle>…
# For each result bundle that exists, appends to <output file> a line "== <bundle>: <file>" and the contents of every
# StandardOutputAndStandardError*.txt it exported (the test runner's as well: nothing is guessed from a bundle id), or,
# when there is none, the list of the files the export wrote, so the reader sees what this Xcode keeps. Not verified on
# Xcode 27.2 before D0b's run (the file name is the one Xcode 15–16 used). Best effort: a failed export is a warning, and
# it always exits 0, so the step's result does not depend on it.
set -uo pipefail

if [ "$#" -lt 2 ]; then
  echo "::warning::tools/ci/xcresult-app-output.sh: usage: <output file> <result bundle>…"
  exit 0
fi
OUT="$1"
SHOWN="${OUT#"$PWD"/}"
shift
mkdir -p "$(dirname "$OUT")" 2>/dev/null || true
touch "$OUT" 2>/dev/null || { echo "::warning::$SHOWN cannot be written; the apps' output is not kept."; exit 0; }

for BUNDLE in "$@"; do
  [ -d "$BUNDLE" ] || continue
  DIR="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/xcresult-output.XXXXXX")" || { echo "::warning::no folder for the export of $BUNDLE"; continue; }
  if ! xcrun xcresulttool export diagnostics --path "$BUNDLE" --output-path "$DIR" > "$DIR.log" 2>&1; then
    echo "::warning::$BUNDLE: xcresulttool could not export its diagnostics ($(tail -n 1 "$DIR.log" 2>/dev/null)); the apps' output is not kept."
    continue
  fi
  FOUND=0
  while IFS= read -r -d '' F; do
    FOUND=$((FOUND + 1))
    echo "== $BUNDLE: ${F#"$DIR"/}"
    cat "$F"
    echo ""
  done < <(find "$DIR" -type f -name 'StandardOutputAndStandardError*' -print0 | sort -z) >> "$OUT"
  if [ "$FOUND" = 0 ]; then
    {
      echo "== $BUNDLE: no StandardOutputAndStandardError file; the files of its diagnostics:"
      find "$DIR" -type f | sed "s|^$DIR/||" | sort | head -n 200
    } >> "$OUT"
    echo "::warning::$BUNDLE: its diagnostics have no StandardOutputAndStandardError file (their list is in $SHOWN)."
  else
    echo "$BUNDLE: $FOUND StandardOutputAndStandardError files into $SHOWN"
  fi
done
exit 0
