#!/bin/bash
# The reach check of an app log taken with `xcrun simctl spawn <udid> log show` (docs/M7D_CONTRACT.md §3.3 3, §3.8;
# docs/M7D.md, D0b). On the iOS 27 simulators of the image xcode-27, `log show` gives the app's NSLog lines as
# "<compose failure [<uuid>]>": in D0 (run 44632524223) every app log had them and none had a `toolbar: paperArea=`
# line (1.3's run 44474759145: 18–52 per log). The steps that read those logs print what they find or count a number
# whose expected value is 0, so a log without the app's lines passed without a sign. This prints one line of counts for
# a log (its lines, the lines `log show` could not compose, and the lines of each expected marker) and one warning when
# a line could not be composed or a marker has no line.
#
# Usage: tools/ci/log-reach.sh <label> <log file> [<marker>…]   (a marker is a fixed string, e.g. "toolbar: paperArea=")
# Used by build.yml after each `log show` it takes (the J-4 photo steps' logs in a step of their own, so those steps stay
# the same as ja-baseline.yml's). Never fails: it exits 0 whatever it finds (the logs are shown only; D0's gate 3 reads
# shots/span-app/lines/<id>.txt, written by the test runner).
set -uo pipefail

LABEL="${1:-log}"
FILE="${2:-}"
if [ "$#" -ge 2 ]; then shift 2; else shift "$#"; fi

count() {  # count <E|F> <pattern>: the lines of $FILE that match, 0 when none does
  local N
  N="$(grep -c "-$1" -e "$2" -- "$FILE" 2>/dev/null || true)"
  echo "${N:-0}"
}

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "::warning::$LABEL: no log file (${FILE:-none}); the app's log lines were not collected (docs/M7D.md, D0b)."
  exit 0
fi

LINES="$(count E '')"
FAILURES="$(count F '<compose failure')"
COUNTS=""
ABSENT=""
for MARKER in "$@"; do
  N="$(count F "$MARKER")"
  COUNTS="$COUNTS, \"$MARKER\" $N"
  if [ "$N" = 0 ]; then ABSENT="$ABSENT \"$MARKER\""; fi
done
SHOWN="${FILE#"$PWD"/}"
echo "$LABEL: $LINES lines, $FAILURES that log show could not compose$COUNTS ($SHOWN)"
if [ "$FAILURES" != 0 ] || [ -n "$ABSENT" ]; then
  WHAT=""
  if [ "$FAILURES" != 0 ]; then WHAT="$FAILURES lines are \"<compose failure …>\" (log show could not compose them)"; fi
  if [ -n "$ABSENT" ]; then WHAT="${WHAT:+$WHAT; }no line with$ABSENT"; fi
  echo "::warning::$LABEL: $WHAT in $SHOWN (docs/M7D.md, D0b)."
fi
exit 0
