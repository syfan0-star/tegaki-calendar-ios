#!/usr/bin/env bash
# Runs the compatibility checks of K-7 on the real 1.0 and on the frozen copy and compares them
# (docs/M7A_CONTRACT.md §1.4, §7.4 compat-v1.0 ④ ⑤).
#
#   tools/compat10/run.sh <fixtures folder>
#
# Needs <repo>/v10/TegakiKit: the TegakiKit of commit a21e4692109e504701b507ad9c695181fdecddfd (CI: the
# second checkout, `path: v10`; locally: `git archive a21e4692109e504701b507ad9c695181fdecddfd TegakiKit |
# tar -x -C <repo copy>/v10`). The fixtures folder holds the committed fixtures plus K's large ones
# (`swift run --package-path TegakiKit KitChecks --write-compat-fixtures --out <folder>` after copying
# TegakiKit/Tests/Fixtures/compat11/*.json there).
#
# ④ copies Compat10Checks.swift and LedgerV10.swift into RunReal, and every file of the frozen copy
#   (LayoutFactsV10.swift included) and Compat10Checks.swift into RunFrozen (Sources/*/Copied-*.swift,
#   ignored by git);
# ⑤ runs RunReal and RunFrozen. Exit 0 only when both print `compat10: N checks, F failed` with the
#   same N, F = 0 for both, N ≥ EXPECTED_MIN, and RunReal's InkImport line has no failure.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
FIXTURES="$(cd "${1:?usage: run.sh <fixtures folder>}" && pwd)"
FROZEN="$REPO/TegakiKit/Tests/Compat10"
EXPECTED_MIN="$(tr -d '[:space:]' < "$HERE/EXPECTED_MIN")"

if [ ! -f "$REPO/v10/TegakiKit/Package.swift" ]; then
  echo "run.sh: $REPO/v10/TegakiKit is missing (check out a21e4692109e504701b507ad9c695181fdecddfd at v10)"
  exit 2
fi

# ④ The copies.
rm -f "$HERE"/Sources/RunReal/Copied-*.swift "$HERE"/Sources/RunFrozen/Copied-*.swift
cp "$FROZEN/Checks/Compat10Checks.swift" "$HERE/Sources/RunReal/Copied-Compat10Checks.swift"
cp "$FROZEN/LedgerV10.swift" "$HERE/Sources/RunReal/Copied-LedgerV10.swift"
for f in "$FROZEN"/*.swift "$FROZEN"/Checks/*.swift; do
  cp "$f" "$HERE/Sources/RunFrozen/Copied-$(basename "$f")"
done
echo "copied: RunReal $(ls "$HERE"/Sources/RunReal/Copied-*.swift | wc -l | tr -d ' ') files, RunFrozen $(ls "$HERE"/Sources/RunFrozen/Copied-*.swift | wc -l | tr -d ' ') files"

# ⑤ Both runs.
swift build --package-path "$HERE"
LOGS="$(mktemp -d)"
set +e
swift run --skip-build --package-path "$HERE" RunReal "$FIXTURES" > "$LOGS/real.log" 2>&1
REAL_STATUS=$?
swift run --skip-build --package-path "$HERE" RunFrozen "$FIXTURES" > "$LOGS/frozen.log" 2>&1
FROZEN_STATUS=$?
set -e
echo "== RunReal (the real 1.0, exit $REAL_STATUS)"
grep -E '^(FAIL|compat10)' "$LOGS/real.log" || cat "$LOGS/real.log"
echo "== RunFrozen (the frozen copy, exit $FROZEN_STATUS)"
grep -E '^(FAIL|compat10)' "$LOGS/frozen.log" || cat "$LOGS/frozen.log"

count() { # count <log> <field>: N or F of the `compat10: N checks, F failed` line
  sed -nE 's/^compat10: ([0-9]+) checks, ([0-9]+) failed$/\1 \2/p' "$1" | tail -1 | cut -d' ' -f"$2"
}
REAL_N="$(count "$LOGS/real.log" 1)"; REAL_F="$(count "$LOGS/real.log" 2)"
FROZEN_N="$(count "$LOGS/frozen.log" 1)"; FROZEN_F="$(count "$LOGS/frozen.log" 2)"
IMPORT_F="$(sed -nE 's/^compat10 \(real only\): InkImport ([0-9]+) checks, ([0-9]+) failed$/\2/p' "$LOGS/real.log" | tail -1)"
echo "compat-v1.0: real N=${REAL_N:-?} F=${REAL_F:-?} (InkImport F=${IMPORT_F:-?}), frozen N=${FROZEN_N:-?} F=${FROZEN_F:-?}, EXPECTED_MIN=$EXPECTED_MIN"
if [ -z "$REAL_N" ] || [ -z "$FROZEN_N" ] || [ -z "$IMPORT_F" ]; then
  echo "compat-v1.0: FAILED (a run did not report)"; exit 1
fi
if [ "$REAL_N" != "$FROZEN_N" ]; then
  echo "compat-v1.0: FAILED (the real 1.0 and the frozen copy ran a different number of checks)"; exit 1
fi
if [ "$REAL_F" != "0" ] || [ "$FROZEN_F" != "0" ] || [ "$IMPORT_F" != "0" ] || [ "$REAL_STATUS" -ne 0 ] || [ "$FROZEN_STATUS" -ne 0 ]; then
  echo "compat-v1.0: FAILED (failures above)"; exit 1
fi
if [ "$REAL_N" -lt "$EXPECTED_MIN" ]; then
  echo "compat-v1.0: FAILED ($REAL_N checks < EXPECTED_MIN $EXPECTED_MIN: a fixture is missing)"; exit 1
fi
echo "compat-v1.0: OK ($REAL_N checks on the real 1.0 and on the frozen copy, 0 failed)"
