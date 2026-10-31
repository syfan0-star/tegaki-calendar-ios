#!/usr/bin/env bash
# Type-checks the app and its tests against the Mac Catalyst SDK on a Mac that has only the Command
# Line Tools (no Xcode, no XCTest, no StoreKitTest). The real compile and the simulator tests run on
# CI (.github/workflows/build.yml); this is the local stand-in described in docs/M4.md §2.2 / §4.4,
# docs/M5.md §2.2 and docs/M6.md §2.2, saved here in 1.0.1 (docs/R1_0_1.md) so later milestones can
# reuse it.
#
#   tools/typecheck/typecheck.sh [work-dir]
#
# Steps (work-dir defaults to $TMPDIR/tegaki-typecheck; nothing is written inside the repository):
#   1. TegakiKit's five modules (DayKit, Holidays, Layout, InkModel, Access) are emitted from the
#      current sources as .swiftmodule for arm64-apple-ios17.0-macabi into <work-dir>/kitmod.
#   2. Stand-in modules for what the CLT lack: XCTest (XCTestStandIn.swift) and StoreKitTest
#      (StoreKitTestStandIn.swift), emitted into the same directory.
#   3. A copy of Sources/ in which SwiftUI's `@State` (and `State(initialValue:)`) is replaced by `@StateStandIn`
#      (StateStandIn.swift: the same shape — wrappedValue, a Binding projection, DynamicProperty),
#      because the CLT have no plugin for the macro the SDK's `@State` now expands through.
#   4. `swiftc -typecheck -swift-version 5` of the app (all of the copy + StateStandIn.swift).
#   5. The app copy emitted as module `TegakiCalendar` (so `@testable import` resolves), then
#      `swiftc -typecheck` of each folder of Tests/ (TegakiCalendarTests; since 1.0.1 also
#      TegakiCalendarUITests) as its own module against it and the stand-ins.
#   6. `swiftc -typecheck` of TegakiKit's XCTest targets against the stand-in XCTest (macOS target).
#      Since 1.1 (docs/M7A_CONTRACT.md §1.4) also the two test-only library targets: the frozen 1.0
#      copy Compat10 (every .swift under TegakiKit/Tests/Compat10, Checks/ included) and
#      CompatFixtures are emitted as modules, and the folders Compat10, CompatFixtures and Fixtures
#      (JSON only) are not type-checked as test targets. Each test folder's files are found with
#      `find`, so sub-folders count too.
# Exit status: non-zero when any step fails. Warnings are printed and counted, not fatal.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
WORK="${1:-${TMPDIR:-/tmp}/tegaki-typecheck}"
SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-ios17.0-macabi"
KIT="$WORK/kitmod"
APP="$WORK/app"
LOG="$WORK/logs"

# The work dir is emptied on every run, so only a new / empty directory or one this script made
# (it carries the marker file) is accepted — never the repository or a directory with other files.
MARKER=".tegaki-typecheck"
case "$(cd "$(dirname "$WORK")" 2>/dev/null && pwd)/$(basename "$WORK")/" in
  "$REPO"/*) echo "typecheck: the work dir must be outside the repository ($WORK)"; exit 2 ;;
esac
if [ -d "$WORK" ] && [ -n "$(ls -A "$WORK")" ] && [ ! -f "$WORK/$MARKER" ]; then
  echo "typecheck: $WORK is not empty and was not made by this script; pass another directory"
  exit 2
fi
rm -rf "$WORK"
mkdir -p "$KIT" "$APP" "$LOG"
touch "$WORK/$MARKER"

CATALYST=(
  -sdk "$SDK"
  -target "$TARGET"
  -swift-version 5
  -Fsystem "$SDK/System/iOSSupport/System/Library/Frameworks"
  -I "$SDK/System/iOSSupport/usr/lib/swift"
  -I "$KIT"
)

emit() { # emit <module> <files...>
  local name="$1"; shift
  xcrun swiftc -emit-module -parse-as-library -module-name "$name" \
    -emit-module-path "$KIT/$name.swiftmodule" -enable-testing "${CATALYST[@]}" "$@" \
    2> "$LOG/emit-$name.log" || { cat "$LOG/emit-$name.log"; echo "typecheck: emitting $name FAILED"; exit 1; }
  echo "emitted $name ($# files)"
}

# 1. TegakiKit (dependency order: Package.swift).
emit DayKit "$REPO"/TegakiKit/Sources/DayKit/*.swift
emit Holidays "$REPO"/TegakiKit/Sources/Holidays/*.swift
emit Layout "$REPO"/TegakiKit/Sources/Layout/*.swift
emit InkModel "$REPO"/TegakiKit/Sources/InkModel/*.swift
emit Access "$REPO"/TegakiKit/Sources/Access/*.swift

# 2. Stand-ins.
emit XCTest "$HERE/XCTestStandIn.swift"
emit StoreKitTest "$HERE/StoreKitTestStandIn.swift"

# 3. The app copy with the @State stand-in.
APP_FILES=()
while IFS= read -r f; do
  rel="${f#"$REPO"/}"
  mkdir -p "$APP/$(dirname "$rel")"
  sed -E -e 's/@State([[:space:](])/@StateStandIn\1/g' \
         -e 's/([^[:alnum:]_.])State\((initialValue|wrappedValue):/\1StateStandIn(\2:/g' "$f" > "$APP/$rel"
  APP_FILES+=("$APP/$rel")
done < <(find "$REPO/Sources" -name '*.swift' | sort)
cp "$HERE/StateStandIn.swift" "$APP/StateStandIn.swift"
APP_FILES+=("$APP/StateStandIn.swift")
echo "app copy: ${#APP_FILES[@]} files (@State → @StateStandIn: $(grep -l '@StateStandIn' "${APP_FILES[@]}" | wc -l | tr -d ' ') files)"

# 4. Type-check the app.
if xcrun swiftc -typecheck -module-name TegakiCalendar "${CATALYST[@]}" "${APP_FILES[@]}" 2> "$LOG/app.log"; then
  echo "app: typecheck OK ($(grep -c 'warning:' "$LOG/app.log" || true) warnings; $LOG/app.log)"
else
  grep -E 'error:' "$LOG/app.log" | head -60
  echo "app: typecheck FAILED ($LOG/app.log)"
  exit 1
fi

# 5. The tests against the app module.
xcrun swiftc -emit-module -parse-as-library -module-name TegakiCalendar -enable-testing \
  -emit-module-path "$KIT/TegakiCalendar.swiftmodule" "${CATALYST[@]}" "${APP_FILES[@]}" \
  2> "$LOG/emit-app.log" || { grep -E 'error:' "$LOG/emit-app.log" | head -40; echo "typecheck: emitting the app module FAILED"; exit 1; }
# Each folder of Tests/ is its own test target (module): TegakiCalendarTests (unit tests, @testable
# import of the app) and, since 1.0.1, TegakiCalendarUITests (XCUITest; the stand-in has the XCUI
# types it uses).
for dir in "$REPO"/Tests/*/; do
  module="$(basename "$dir")"
  TEST_FILES=()
  while IFS= read -r f; do TEST_FILES+=("$f"); done < <(find "$dir" -name '*.swift' | sort)
  [ "${#TEST_FILES[@]}" -gt 0 ] || continue
  if xcrun swiftc -typecheck -module-name "$module" "${CATALYST[@]}" "${TEST_FILES[@]}" 2> "$LOG/tests-$module.log"; then
    echo "$module: typecheck OK (${#TEST_FILES[@]} files, $(grep -c 'warning:' "$LOG/tests-$module.log" || true) warnings; $LOG/tests-$module.log)"
  else
    grep -E 'error:' "$LOG/tests-$module.log" | head -60
    echo "$module: typecheck FAILED ($LOG/tests-$module.log)"
    exit 1
  fi
done

# 6. TegakiKit's XCTest targets (macOS) against the stand-in XCTest.
MAC=(-sdk "$SDK" -swift-version 5 -I "$WORK/kitmac")
mkdir -p "$WORK/kitmac"
emitmac() {
  local name="$1"; shift
  xcrun swiftc -emit-module -parse-as-library -module-name "$name" -enable-testing \
    -emit-module-path "$WORK/kitmac/$name.swiftmodule" "${MAC[@]}" "$@" \
    2> "$LOG/emitmac-$name.log" || { cat "$LOG/emitmac-$name.log"; echo "typecheck: emitting $name (macOS) FAILED"; exit 1; }
}
swift_files() { # swift_files <dir>: every .swift under <dir>, sorted (one per line)
  find "$1" -name '*.swift' | sort
}
emitmac DayKit "$REPO"/TegakiKit/Sources/DayKit/*.swift
emitmac Holidays "$REPO"/TegakiKit/Sources/Holidays/*.swift
emitmac Layout "$REPO"/TegakiKit/Sources/Layout/*.swift
emitmac InkModel "$REPO"/TegakiKit/Sources/InkModel/*.swift
COMPAT_FIXTURES=()
while IFS= read -r f; do COMPAT_FIXTURES+=("$f"); done < <(swift_files "$REPO/TegakiKit/Tests/CompatFixtures")
emitmac CompatFixtures "${COMPAT_FIXTURES[@]}"
emitmac Access "$REPO"/TegakiKit/Sources/Access/*.swift
COMPAT10=()
while IFS= read -r f; do COMPAT10+=("$f"); done < <(swift_files "$REPO/TegakiKit/Tests/Compat10")
emitmac Compat10 "${COMPAT10[@]}"
echo "emitted Compat10 (${#COMPAT10[@]} files) and CompatFixtures (${#COMPAT_FIXTURES[@]} files) (macOS)"
# The stand-in XCTest of this step also has `measure` (Compat10BudgetTests measures a decode; XCTest
# runs the block 10 times, the stand-in only type-checks the call).
cat > "$WORK/XCTestStandInMeasure.swift" <<'SWIFT'
extension XCTestCase {
    public func measure(_ block: () -> Void) {}
}
SWIFT
emitmac XCTest "$HERE/XCTestStandIn.swift" "$WORK/XCTestStandInMeasure.swift"
for t in "$REPO"/TegakiKit/Tests/*/; do
  name="$(basename "$t")"
  case "$name" in
    Compat10|CompatFixtures|Fixtures) continue ;; # library targets (emitted above) and the JSON fixtures
  esac
  KIT_TEST_FILES=()
  while IFS= read -r f; do KIT_TEST_FILES+=("$f"); done < <(swift_files "$t")
  [ "${#KIT_TEST_FILES[@]}" -gt 0 ] || continue
  if xcrun swiftc -typecheck -module-name "$name" "${MAC[@]}" "${KIT_TEST_FILES[@]}" 2> "$LOG/kit-$name.log"; then
    echo "TegakiKit $name: typecheck OK (${#KIT_TEST_FILES[@]} files, $(grep -c 'warning:' "$LOG/kit-$name.log" || true) warnings)"
  else
    grep -E 'error:' "$LOG/kit-$name.log" | head -40
    echo "TegakiKit $name: typecheck FAILED ($LOG/kit-$name.log)"
    exit 1
  fi
done
echo "typecheck: all OK"
