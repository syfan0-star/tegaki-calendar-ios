#!/usr/bin/env bash
# Reads every compat-span fixture with an old version's REAL TegakiKit (docs/M7C_CONTRACT.md §6.3, §10.4; 1.3 itself
# since 1.4, docs/M7D_CONTRACT.md §5.3).
#
#   tools/span-compat/run.sh <v10|v11|v123|v13> <that version's TegakiKit folder> [<work folder> [compat-span|compat-span-143]]
#
# The TegakiKit folder is the old commit's TegakiKit taken out of git: v10 = a21e4692109e504701b507ad9c695181fdecddfd
# (1.0), v11 = the commit in tools/l10n/ja-baseline-ref.txt (<1.1.1>), v123 = 43fe36666a2120e8a23adf4fc76244151a395e6f
# (1.2.3), v13 = 955fe678ec9f999ac45fac1b372f246e43c02f95 (1.3, build 26), for example
# `git archive 955fe678ec9f999ac45fac1b372f246e43c02f95 TegakiKit | tar -x -C <dir>/v13`.
# CI's compat-v1.0 job passes its checkouts v10 and v11 and the archives v123 and v13.
#
# A Swift package is made in the work folder (default: a new temporary folder; it must be outside the repository):
# Package.swift naming the old TegakiKit by its absolute path, and Sources/Probe = Probe/Common.swift,
# Probe/main.swift and <version>/Version.swift of this folder. `swift run Probe` then reads
# TegakiKit/Tests/Fixtures/compat-span of this checkout, or (1.4.3, docs/R1_4_3_CONTRACT.md §8.3; the fourth argument)
# TegakiKit/Tests/Fixtures/compat-span-143, the month's and the year's joined-path fixtures. Exit 0 only when its last line is
# `span-compat <version>: N checks, 0 failed`. Nothing is written into the repository or the old TegakiKit
# except SwiftPM's own .build folder of the package (in the work folder).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
VERSION="${1:?usage: run.sh <v10|v11|v123|v13> <TegakiKit folder> [<work folder> [compat-span|compat-span-143]]}"
KIT="$(cd "${2:?usage: run.sh <v10|v11|v123|v13> <TegakiKit folder> [<work folder> [compat-span|compat-span-143]]}" && pwd)"
case "$VERSION" in
  v10|v11|v123|v13) ;;
  *) echo "run.sh: the version is v10, v11, v123 or v13, not $VERSION"; exit 2 ;;
esac
if [ ! -f "$KIT/Package.swift" ] || [ ! -d "$KIT/Sources/InkModel" ]; then
  echo "run.sh: $KIT is not a TegakiKit folder"; exit 2
fi
WORK="${3:-$(mktemp -d)}"
mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"
case "$WORK/" in
  "$REPO"/*) echo "run.sh: the work folder must be outside the repository ($WORK)"; exit 2 ;;
esac
FOLDER="${4:-compat-span}"
case "$FOLDER" in
  compat-span|compat-span-143) ;;
  *) echo "run.sh: the fixture folder is compat-span or compat-span-143, not $FOLDER"; exit 2 ;;
esac
FIXTURES="$REPO/TegakiKit/Tests/Fixtures/$FOLDER"

PKG="$WORK/span-compat-$VERSION"
rm -rf "$PKG/Sources"
mkdir -p "$PKG/Sources/Probe"
cp "$HERE/Probe/Common.swift" "$HERE/Probe/main.swift" "$HERE/$VERSION/Version.swift" "$PKG/Sources/Probe/"
cat > "$PKG/Package.swift" <<EOF
// swift-tools-version:5.9
// Made by tools/span-compat/run.sh for $VERSION; not in the repository.
import PackageDescription
let package = Package(name: "Probe", platforms: [.macOS(.v14)],
  dependencies: [.package(path: "$KIT")],
  targets: [.executableTarget(name: "Probe", dependencies: [
    .product(name: "InkModel", package: "TegakiKit"), .product(name: "Layout", package: "TegakiKit"), .product(name: "DayKit", package: "TegakiKit")], path: "Sources/Probe")],
  swiftLanguageVersions: [.v5])
EOF
echo "span-compat $VERSION: TegakiKit $KIT, fixtures $FIXTURES"
swift build --package-path "$PKG" --product Probe
"$PKG/.build/debug/Probe" "$FIXTURES"
