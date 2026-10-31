#!/usr/bin/env python3
"""The frozen copy of the 1.0 InkModel (TegakiKit/Tests/Compat10, M7A_CONTRACT §1.4, K-7).

The copies are made mechanically from the released 1.0 (commit a21e469): the text of the 1.0 file
with every top-level type name of the copied files given the suffix V10 (whole words only, comments
included) and the `import` of a TegakiKit module removed. A copy of only a part of a file is the
listed line ranges of the 1.0 text, renamed the same way, inside the few wrapper lines given here
(each range is preceded by a comment naming it). Nothing else is changed, and nobody edits the
copies after they are frozen.

    python3 -I tools/compat10/freeze.py --check [--from-dir <a21e469 tree>]
        Rebuilds every copy in memory and compares it with TegakiKit/Tests/Compat10 byte for byte,
        and checks FROZEN.sha256, ORIGIN.sha256 and ORIGIN.ranges against the files and the 1.0
        text. Exit 1 on any difference.
    python3 -I tools/compat10/freeze.py --write [--from-dir <a21e469 tree>]
        Writes the copies, FROZEN.sha256 (the copies only, Checks/ excluded, LedgerV10.swift and
        LayoutFactsV10.swift included), ORIGIN.sha256 and ORIGIN.ranges. Used once, when freezing.

The 1.0 text comes from `git show a21e469:<path>` in this repository, or from a directory that
holds the a21e469 tree (`--from-dir v10`, the second checkout of CI's compat-v1.0 job).
LedgerV10.swift and LayoutFactsV10.swift are written by hand (pure functions of the 1.0 app's rules
and the 1.0 layout facts); only their digests and their origin ranges are handled here.
"""
import hashlib
import os
import re
import subprocess
import sys

COMMIT = "a21e4692109e504701b507ad9c695181fdecddfd"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
FROZEN_DIR = os.path.join(REPO, "TegakiKit", "Tests", "Compat10")

INK = "TegakiKit/Sources/InkModel/"
LAYOUT = "TegakiKit/Sources/Layout/"
APP = "Sources/TegakiCalendar/"

# Every top-level type of the copied files (and the types they refer to) gets the suffix V10.
RENAMES = [
    "JSONValue", "InkPoint", "InkTool", "InkStroke", "StrokeFingerprint", "InkPage",
    "InkPageCodec", "InkCodecError", "BandMigration", "CellKey", "PaperSpec", "DayKey",
    "AppExport", "WebImport",
]
# Imports of TegakiKit modules (the copy depends on Foundation, CoreGraphics and Compression only).
DROPPED_IMPORTS = re.compile(r"^(@_exported )?import (Layout|DayKit|InkModel|Holidays)\n", re.M)

# Whole files: (copy, origin).
WHOLE = [
    ("JSONValueV10.swift", INK + "JSONValue.swift"),
    ("InkStrokeV10.swift", INK + "InkStroke.swift"),
    ("InkPageV10.swift", INK + "InkPage.swift"),
    ("InkPageCodecV10.swift", INK + "InkPageCodec.swift"),
    ("BandMigrationV10.swift", INK + "BandMigration.swift"),
]

# Parts of files: (copy, [("text", line) | ("lines", origin, first, last, name)]).
PARTS = [
    ("CellKeyV10.swift", [
        ("lines", LAYOUT + "PaperSpec.swift", 1, 2, "imports"),
        ("text", ""),
        ("text", "/// The week constants of `PaperSpec` that `BandMigration` uses (the rest of PaperSpec is not copied)."),
        ("text", "public enum PaperSpecV10 {"),
        ("lines", LAYOUT + "PaperSpec.swift", 36, 41, "PaperSpecV10.weekWidth / weekGutter / weekColumns / weekColumnWidth"),
        ("text", "}"),
        ("text", ""),
        ("lines", LAYOUT + "PaperSpec.swift", 114, 200, "CellKeyV10"),
    ]),
    ("DayKeyV10.swift", [
        ("lines", "TegakiKit/Sources/DayKit/DayKey.swift", 1, 93, "DayKeyV10"),
        ("text", "}"),
    ]),
    ("WebImportV10.swift", [
        ("lines", INK + "WebImport.swift", 1, 1, "imports"),
        ("text", ""),
        ("text", "/// Only what `AppExport.parse` uses: `supportedVersion`, `ParseError` and `versionNumber`."),
        ("lines", INK + "WebImport.swift", 10, 10, "WebImportV10"),
        ("lines", INK + "WebImport.swift", 12, 12, "WebImportV10.supportedVersion"),
        ("text", ""),
        ("lines", INK + "WebImport.swift", 29, 35, "WebImportV10.ParseError"),
        ("text", ""),
        ("lines", INK + "WebImport.swift", 165, 169, "WebImportV10.versionNumber"),
        ("text", "}"),
    ]),
    ("AppExportV10.swift", [
        ("lines", INK + "AppExport.swift", 1, 132, "AppExportV10"),
        ("text", "}"),
    ]),
]

# The hand-written pure functions and facts, and the 1.0 lines each one stands for. Each function in
# LedgerV10.swift / LayoutFactsV10.swift carries the same "// a21e469 <path>:<first>-<last>" comment.
HAND = ["LedgerV10.swift", "LayoutFactsV10.swift"]
HAND_RANGES = [
    (APP + "Ink/InkLedger.swift", 217, 235, "LedgerV10.drawnIds"),
    (APP + "Ink/InkLedger.swift", 285, 290, "LedgerV10.drawnIds (what an erase can remove)"),
    (APP + "Ink/InkCanvasView.swift", 1352, 1367, "LedgerV10.lassoCandidates"),
    (APP + "Ink/InkCanvasView.swift", 1120, 1135, "LedgerV10.dotCandidates"),
    (APP + "Ink/InkLedger.swift", 408, 411, "LedgerV10.dotCandidates (paperBounds of a live stroke)"),
    (APP + "Ink/InkLedger.swift", 321, 325, "LedgerV10.needsMoreRoom"),
    (LAYOUT + "PaperSpec.swift", 23, 25, "LedgerV10.needsMoreRoom (inkPad, memoInkPad)"),
    (APP + "Views/CalendarRootScreen.swift", 805, 810, "LedgerV10.displayWouldSave"),
    (APP + "Views/CalendarRootScreen.swift", 1327, 1333, "LedgerV10.displayWouldSave (reloadShownPage)"),
    (APP + "Views/CalendarRootScreen.swift", 878, 889, "LedgerV10.applyRemoteWouldSave"),
    (APP + "Sync/SyncEngine.swift", 633, 647, "LedgerV10.mergeRemoteOutcome"),
    (LAYOUT + "MonthLayoutEngine.swift", 23, 26, "memoHeightV10"),
    (LAYOUT + "DayLayoutEngine.swift", 210, 218, "cellsV10 (day: grid)"),
    (LAYOUT + "WeekLayoutEngine.swift", 235, 241, "cellsV10 (week: grid)"),
    (LAYOUT + "MonthLayoutEngine.swift", 90, 92, "cellsV10 (month: the 42 day cells)"),
    (LAYOUT + "MonthLayoutEngine.swift", 162, 164, "cellsV10 (month: memo)"),
    (LAYOUT + "MonthLayout.swift", 45, 55, "cellsV10 (month: 42 days from the Monday)"),
    (LAYOUT + "YearLayoutEngine.swift", 300, 308, "cellsV10 (year: 372 cells)"),
]

# ORIGIN.sha256: every file a copy or a hand-written function was made from.
ORIGIN_FILES = sorted({o for _, o in WHOLE}
                      | {p[1] for _, parts in PARTS for p in parts if p[0] == "lines"}
                      | {r[0] for r in HAND_RANGES})


def origin_text(path, from_dir):
    if from_dir:
        with open(os.path.join(from_dir, path), "rb") as f:
            return f.read().decode("utf-8")
    out = subprocess.run(["git", "-C", REPO, "show", COMMIT + ":" + path], check=True, capture_output=True)
    return out.stdout.decode("utf-8")


def rename(text):
    for name in RENAMES:
        text = re.sub(r"\b" + name + r"\b", name + "V10", text)
    return text


def lines_of(text, first, last):
    lines = text.split("\n")
    return "\n".join(lines[first - 1:last])


def build(from_dir):
    copies = {}
    for copy, origin in WHOLE:
        copies[copy] = rename(DROPPED_IMPORTS.sub("", origin_text(origin, from_dir)))
    for copy, parts in PARTS:
        out = []
        for part in parts:
            if part[0] == "text":
                out.append(part[1])
            else:
                _, origin, first, last, name = part
                chunk = rename(DROPPED_IMPORTS.sub("", lines_of(origin_text(origin, from_dir), first, last) + "\n")).rstrip("\n")
                lead = next((line for line in chunk.split("\n") if line.strip()), "")
                indent = lead[:len(lead) - len(lead.lstrip())]
                out.append("%s// a21e469 %s:%d-%d  %s" % (indent, origin, first, last, name))
                out.append(chunk)
        copies[copy] = "\n".join(out) + "\n"
    return copies


def sha(data):
    return hashlib.sha256(data).hexdigest()


def frozen_digests(copies):
    names = sorted(list(copies) + HAND)
    rows = []
    for name in names:
        if name in copies:
            data = copies[name].encode("utf-8")
        else:
            with open(os.path.join(FROZEN_DIR, name), "rb") as f:
                data = f.read()
        rows.append("%s  %s\n" % (sha(data), name))
    return "".join(rows)


def origin_digests(from_dir):
    return "".join("%s  %s\n" % (sha(origin_text(p, from_dir).encode("utf-8")), p) for p in ORIGIN_FILES)


def origin_ranges(from_dir):
    rows = []
    for copy, parts in PARTS:
        for part in parts:
            if part[0] == "lines":
                _, origin, first, last, name = part
                rows.append((origin, first, last, name))
    rows.extend(HAND_RANGES)
    out = []
    for origin, first, last, name in rows:
        # The same bytes as `sed -n '<first>,<last>p' <file> | shasum -a 256` (every line ends in "\n").
        data = (lines_of(origin_text(origin, from_dir), first, last) + "\n").encode("utf-8")
        out.append("%s  %s:%d-%d  %s\n" % (sha(data), origin, first, last, name))
    return "".join(out)


def main(argv):
    from_dir = None
    if "--from-dir" in argv:
        from_dir = argv[argv.index("--from-dir") + 1]
    copies = build(from_dir)
    expected = dict(copies)
    expected["FROZEN.sha256"] = frozen_digests(copies)
    expected["ORIGIN.sha256"] = origin_digests(from_dir)
    expected["ORIGIN.ranges"] = origin_ranges(from_dir)
    if "--write" in argv:
        for name, text in expected.items():
            with open(os.path.join(FROZEN_DIR, name), "wb") as f:
                f.write(text.encode("utf-8"))
            print("wrote", name)
        return 0
    if "--check" in argv:
        bad = 0
        for name, text in sorted(expected.items()):
            path = os.path.join(FROZEN_DIR, name)
            try:
                with open(path, "rb") as f:
                    same = f.read() == text.encode("utf-8")
            except OSError:
                same = False
            print(("ok       " if same else "DIFFERS  ") + name)
            bad += 0 if same else 1
        print("freeze: %d of %d files differ" % (bad, len(expected)) if bad else "freeze: the frozen copy is what a21e469 gives")
        return 1 if bad else 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
