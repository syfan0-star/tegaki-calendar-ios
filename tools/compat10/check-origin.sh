#!/usr/bin/env bash
# Checks that the frozen copy of the 1.0 InkModel (TegakiKit/Tests/Compat10) was made from the real
# 1.0 (M7A_CONTRACT §1.4, §7.4 compat-v1.0 ②):
#   1. ORIGIN.sha256: every file a copy was made from has, in <v10>, the digest written down;
#   2. ORIGIN.ranges: every line range that was copied in part (and every range LedgerV10 /
#      LayoutFactsV10 transcribe) has the digest written down (`sed -n '<first>,<last>p' | shasum`),
#      so a wrong line number is noticed;
#   3. FROZEN.sha256: the copies themselves are unchanged since they were frozen.
#
#   tools/compat10/check-origin.sh <v10>
#
# <v10> is a tree of commit a21e4692109e504701b507ad9c695181fdecddfd (CI: the second checkout,
# `path: v10`; locally: `git archive a21e4692109e504701b507ad9c695181fdecddfd | tar -x -C <dir>`).
# Exit status 1 when anything differs.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
FROZEN="$REPO/TegakiKit/Tests/Compat10"
V10="$(cd "${1:?usage: check-origin.sh <a21e469 tree>}" && pwd)"

echo "== ORIGIN.sha256 (whole files of a21e469)"
(cd "$V10" && shasum -a 256 -c "$FROZEN/ORIGIN.sha256")

echo "== ORIGIN.ranges (line ranges of a21e469)"
bad=0
count=0
while read -r digest location name; do
  [ -n "$digest" ] || continue
  file="${location%:*}"
  range="${location##*:}"
  first="${range%-*}"
  last="${range#*-}"
  got="$(sed -n "${first},${last}p" "$V10/$file" | shasum -a 256 | cut -d' ' -f1)"
  count=$((count + 1))
  if [ "$got" = "$digest" ]; then
    echo "$location: OK ($name)"
  else
    echo "$location: FAILED ($name)"
    bad=$((bad + 1))
  fi
done < "$FROZEN/ORIGIN.ranges"
if [ "$bad" -ne 0 ]; then
  echo "check-origin: $bad of $count ranges differ"
  exit 1
fi

echo "== FROZEN.sha256 (the copies)"
(cd "$FROZEN" && shasum -a 256 -c FROZEN.sha256)
echo "check-origin: OK ($count ranges)"
