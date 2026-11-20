#!/usr/bin/env python3
# The handwriting of the XCUITest photos (1.4 D1d; docs/M7D.md, "UI テストの 2 回目の写真" and "D1 の残りに足す"): a
# warning only. Run 44676125566's second attempt of ui-tests (image 20261119.0378.1) lost handwriting in its photos (whole
# PencilKit tiles not shown, as in D0's photo steps) while every test that took them passed: nothing compared the
# photos. The photo steps of build.yml and ja-baseline.yml check theirs and take them again (tools/shots/ink_retake.sh);
# XCUITest's photos cannot be taken again after the test, so this only tells. It reuses tools/shots/ink_check.swift as
# it is (its head has the rule: a 48 px tile whose dark, yellow, red or blue ink fell below half of the reference, the 8
# neighbours' gain counted, 30 px or more in all) against the lines of tools/shots/ink_ref_xcui.tsv (its head says which
# photos they come from), keyed by a name that stays the same from run to run:
#   ui-tests        "ui-tests/<class>/<test> :: <the attachment's name>", read from the manifest.json that
#                   `xcresulttool export attachments` writes beside the photos (their files are named by UUIDs). The
#                   attachment's name loses the "_<n>_<UUID>" that XCTest adds before its extension. A second photo of the
#                   same key in one run gets " #2" (and has no reference line).
#   span-shots-app  "span-shots-app/<file name>" (the PNGs of shots/span-app; not its lang/ folder).
#
#   python3 -I tools/shots/xcui_ink.py check --ink <ink_check> --ref <ref.tsv> --prefix <prefix> (--manifest <attachments
#           folder> | --folder <folder>) --out <tsv> [--label <name>]
#       checks every PNG, writes one row a photo (and one a reference line of this prefix with no photo) to <tsv>, prints
#       each result and a summary line (also to $GITHUB_STEP_SUMMARY), and one ::warning:: with the counts when a photo is
#       short or cannot be compared, then one a photo (8 at most: GitHub shows 10 a step). Always exits 0: it never fails
#       a job. It runs its self-test first and says so in the summary line.
#   python3 -I tools/shots/xcui_ink.py ref --ink <ink_check> --prefix <prefix> (--manifest <dir> | --folder <dir>)
#           [--leave-out <key>…]
#       prints the reference lines of a complete run's photos (to renew tools/shots/ink_ref_xcui.tsv: same Xcode, runtime
#       and image as the runs it checks).
#   python3 -I tools/shots/xcui_ink.py self-test --ink <ink_check>
#       made-up photos and a made-up manifest: a complete photo, the same moved by 3 px, one with its ink gone, one of
#       another size, a name with no line, and two attachments of one name. Exit 1 when one case is wrong.
import argparse
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import unicodedata
import zlib

SUFFIX = re.compile(r"_[0-9]+_[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}(\.[A-Za-z0-9]+)?$")
WARNINGS = 8


def manifest_photos(folder):
    """[(key without the prefix, path)] of the PNG attachments that manifest.json lists, in the manifest's order."""
    with open(os.path.join(folder, "manifest.json"), encoding="utf-8") as f:
        data = json.load(f)
    photos = []
    seen = {}
    for test in data if isinstance(data, list) else []:
        if not isinstance(test, dict):
            continue
        ident = re.sub(r"\(\)$", "", str(test.get("testIdentifier") or "?"))
        attachments = [a for a in test.get("attachments") or [] if isinstance(a, dict)]
        for a in sorted(attachments, key=lambda a: a.get("timestamp") or 0):
            name = str(a.get("exportedFileName") or "")
            if not name.lower().endswith(".png") or "/" in name:
                continue
            key = ident + " :: " + SUFFIX.sub(r"\1", str(a.get("suggestedHumanReadableName") or name))
            key = re.sub(r"[\t\r\n]", " ", key)
            seen[key] = seen.get(key, 0) + 1
            if seen[key] > 1:
                key += " #%d" % seen[key]
            photos.append((key, os.path.join(folder, name)))
    return photos


def folder_photos(folder):
    return [(name, os.path.join(folder, name)) for name in sorted(os.listdir(folder))
            if name.lower().endswith(".png") and os.path.isfile(os.path.join(folder, name)) and "\t" not in name]


def ref_keys(path):
    keys = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#") or "\t" not in line:
                continue
            keys.append(line.split("\t", 1)[0])
    return keys


def ink(program, photo, ref, key):
    """(result, px short, tiles, box, ink_check's line) for one photo."""
    try:
        p = subprocess.run([program, photo, ref, key], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           universal_newlines=True, timeout=120)
    except (OSError, subprocess.SubprocessError) as error:
        return "error", "", "", "", "ink_check did not run: %s" % error
    lines = (p.stdout or "").strip().splitlines()
    line = lines[-1].strip() if lines else ""
    if line.startswith("ink: " + key + ": "):                # what it says after the name
        line = line[len("ink: " + key + ": "):]
    short = re.search(r"\(([0-9]+) px short", line)
    px = short.group(1) if short else ""
    if p.returncode == 0 and line == "no reference":
        return "no-reference", "", "", "", line
    if p.returncode == 0 and "complete (" in line:
        return "complete", px, "", "", line
    if p.returncode == 1 and "handwriting missing (" in line:
        tiles = re.search(r"in ([0-9]+) tiles", line)
        box = re.search(r"px box ([0-9,\-]+)", line)
        return "short", px, tiles.group(1) if tiles else "", box.group(1) if box else "", line
    if p.returncode == 2 and ", the reference is " in line:
        return "other-size", "", "", "", line
    if p.returncode == 2:
        return "unreadable", "", "", "", line
    return "error", "", "", "", "exit %d: %s" % (p.returncode, line or "(no output)")


def escape(text):  # a workflow command's message
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


# The self-test's made-up photos: plain RGB PNGs (paper white, a dark block as the ink).
def png(path, width, height, blocks):
    rows = []
    for y in range(height):
        row = bytearray(b"\x00")
        for x in range(width):
            dark = any(x0 <= x < x1 and y0 <= y < y1 for x0, y0, x1, y1 in blocks)
            row += b"\x20\x24\x30" if dark else b"\xff\xff\xff"
        rows.append(bytes(row))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))


def self_test(program):
    """[(case, ok, what came out)]"""
    work = tempfile.mkdtemp(prefix="xcui-ink-self-test-", dir=os.environ.get("RUNNER_TEMP") or None)
    try:
        att = os.path.join(work, "attachments")
        os.mkdir(att)
        block = (60, 120, 108, 168)                      # 48 x 48 px of ink below the 64 px top that ink_check leaves out
        png(os.path.join(att, "A.png"), 200, 240, [block])
        png(os.path.join(att, "B.png"), 200, 240, [(63, 123, 111, 171)])
        png(os.path.join(att, "C.png"), 200, 240, [])
        png(os.path.join(att, "D.png"), 240, 200, [block])
        png(os.path.join(att, "E.png"), 200, 240, [block])
        uuid = "_0_0123ABCD-0000-4000-8000-00000000000%d.png"
        manifest = [
            {"testIdentifier": "SelfTests/testA()", "attachments": [
                {"exportedFileName": "A.png", "suggestedHumanReadableName": "ink — start" + uuid % 1, "timestamp": 1},
                {"exportedFileName": "B.png", "suggestedHumanReadableName": "ink — start" + uuid % 2, "timestamp": 2},
                {"exportedFileName": "note.txt", "suggestedHumanReadableName": "note" + uuid % 3, "timestamp": 3}]},
            {"testIdentifier": "SelfTests/testB()", "attachments": [
                {"exportedFileName": "B.png", "suggestedHumanReadableName": "ink — moved" + uuid % 4, "timestamp": 1},
                {"exportedFileName": "C.png", "suggestedHumanReadableName": "ink — gone" + uuid % 5, "timestamp": 2},
                {"exportedFileName": "D.png", "suggestedHumanReadableName": "ink — turned" + uuid % 6, "timestamp": 3},
                {"exportedFileName": "E.png", "suggestedHumanReadableName": "ink — new" + uuid % 7, "timestamp": 4}]},
        ]
        with open(os.path.join(att, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False)
        photos = manifest_photos(att)
        keys = [k for k, _ in photos]
        cases = [("the manifest's keys", keys == ["SelfTests/testA :: ink — start.png", "SelfTests/testA :: ink — start.png #2",
                                                    "SelfTests/testB :: ink — moved.png", "SelfTests/testB :: ink — gone.png",
                                                    "SelfTests/testB :: ink — turned.png", "SelfTests/testB :: ink — new.png"],
                  " | ".join(keys))]
        ref = os.path.join(work, "ref.tsv")
        lines = ["# made up"]
        for key in ("SelfTests/testA :: ink — start.png", "SelfTests/testB :: ink — moved.png",
                    "SelfTests/testB :: ink — gone.png", "SelfTests/testB :: ink — turned.png", "SelfTests/testB :: ink — away.png"):
            p = subprocess.run([program, "ref", os.path.join(att, "A.png"), "self/" + key], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, universal_newlines=True, timeout=120)
            lines.append(p.stdout.strip())
        with open(ref, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        out = os.path.join(work, "out.tsv")
        rows = run_check(program, ref, "self/", photos, out, quiet=True)
        got = {row[0]: row[2] for row in rows}
        for key, want in (("self/SelfTests/testA :: ink — start.png", "complete"),
                          ("self/SelfTests/testA :: ink — start.png #2", "no-reference"),
                          ("self/SelfTests/testB :: ink — moved.png", "complete"),
                          ("self/SelfTests/testB :: ink — gone.png", "short"),
                          ("self/SelfTests/testB :: ink — turned.png", "other-size"),
                          ("self/SelfTests/testB :: ink — new.png", "no-reference"),
                          ("self/SelfTests/testB :: ink — away.png", "no-photo")):
            cases.append((key[5:], got.get(key) == want, "%s (%s expected)" % (got.get(key), want)))
        short = [row for row in rows if row[2] == "short"]
        cases.append(("the gone ink's pixels", bool(short) and short[0][3] == "2304", short[0][3] if short else "-"))
        return cases
    finally:
        shutil.rmtree(work, ignore_errors=True)


def run_check(program, ref, prefix, photos, out, quiet=False):
    """The rows (key, file, result, px short, tiles, box, line), written to <out> as a TSV."""
    rows = []
    for key, path in photos:
        result, px, tiles, box, line = ink(program, path, ref, prefix + key)
        rows.append((prefix + key, os.path.basename(path), result, px, tiles, box, line))
        if not quiet:
            print("%s\t%s%s" % (result, prefix + key, "\t" + px + " px short" if px and result != "complete" else ""))
    there = {unicodedata.normalize("NFC", row[0]) for row in rows}   # ink_check matches canonically equal names too
    for key in ref_keys(ref):
        if key.startswith(prefix) and unicodedata.normalize("NFC", key) not in there:
            rows.append((key, "-", "no-photo", "", "", "", "a reference line with no photo in this run"))
    with open(out, "w", encoding="utf-8") as f:
        f.write("# key\tfile\tresult\tpx short\ttiles\tpx box\tink_check\n")
        for row in rows:
            f.write("\t".join(str(v).replace("\t", " ").replace("\n", " ") for v in row) + "\n")
    return rows


def check(args):
    label = args.label or args.prefix.rstrip("/")
    if not os.access(args.ink, os.X_OK):
        print("::warning::%s" % escape("The %s photos' handwriting is not checked: no program %s (tools/shots/ink_check.swift "
                                       "compiled; tools/shots/xcui_ink.py)." % (label, args.ink)))
        return
    try:
        cases = self_test(args.ink)
        failed = [c for c in cases if not c[1]]
        selftest = "self-test ok (%d cases)" % len(cases) if not failed else "SELF-TEST FAILED (%s)" % "; ".join(
            "%s: %s" % (c[0], c[2]) for c in failed)
    except Exception as error:  # noqa: BLE001 (the check goes on and says so)
        failed = [("self-test", False, str(error))]
        selftest = "SELF-TEST FAILED (%s)" % error
    if failed:
        print("::warning::%s" % escape("The handwriting check of the %s photos: its %s; what it finds below may be blind "
                                       "(tools/shots/xcui_ink.py, a warning only)." % (label, selftest)))
    try:
        photos = manifest_photos(args.manifest) if args.manifest else folder_photos(args.folder)
    except (OSError, ValueError) as error:
        print("::warning::%s" % escape("The %s photos' handwriting is not checked: %s (tools/shots/xcui_ink.py)." % (label, error)))
        return
    if not os.path.isfile(args.ref):
        print("::warning::%s" % escape("The %s photos' handwriting is not checked: no %s." % (label, args.ref)))
        return
    rows = run_check(args.ink, args.ref, args.prefix, photos, args.out)
    count = {}
    for row in rows:
        count[row[2]] = count.get(row[2], 0) + 1
    short = [row for row in rows if row[2] == "short"]
    odd = [row for row in rows if row[2] in ("other-size", "unreadable", "error")]
    px = sum(int(row[3] or 0) for row in short)
    checked = len(photos) - count.get("no-reference", 0)
    summary = ("XCUITest handwriting, %s: %d photos, %d with a reference line: %d complete, %d short (%d px), %d not "
               "comparable; %d with no line; %d reference lines with no photo; %s. A warning only (%s)."
               % (label, len(photos), checked, count.get("complete", 0), len(short), px, len(odd),
                  count.get("no-reference", 0), count.get("no-photo", 0), selftest, os.path.basename(args.out)))
    print(summary)
    if short or odd:
        names = ", ".join(row[0][len(args.prefix):] for row in (short + odd)[:3])
        print("::warning::%s" % escape("%s: %d of %d photos have less ink than their line in %s (%d px short: handwriting "
                                       "not drawn, or moved by more than a tile) and %d could not be compared: %s%s. The "
                                       "tests passed or failed on their own; this is a warning only (docs/M7D.md, D1d; the "
                                       "rows in %s)." % (label, len(short), checked, args.ref, px, len(odd), names,
                                                          ", …" if len(short) + len(odd) > 3 else "",
                                                          os.path.basename(args.out))))
        for row in (short + odd)[:WARNINGS]:
            print("::warning::%s" % escape("%s: %s" % (row[0], row[6])))
        if len(short) + len(odd) > WARNINGS:
            print("… and %d more in %s" % (len(short) + len(odd) - WARNINGS, os.path.basename(args.out)))
    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        try:
            with open(step_summary, "a", encoding="utf-8") as f:
                f.write("### The handwriting of the %s photos (a warning only)\n\n%s\n\n" % (label, summary))
                for row in (short + odd)[:30]:
                    f.write("- %s: %s\n" % (row[0], row[6]))
                f.write("\n")
        except OSError:
            pass


def main():
    parser = argparse.ArgumentParser(description="The handwriting of the XCUITest photos (a warning only).")
    parser.add_argument("mode", choices=("check", "ref", "self-test"))
    parser.add_argument("--ink", required=True, help="the compiled tools/shots/ink_check.swift")
    parser.add_argument("--ref", default="tools/shots/ink_ref_xcui.tsv")
    parser.add_argument("--prefix", default="")
    parser.add_argument("--manifest", help="the folder of xcresulttool's attachments (with manifest.json)")
    parser.add_argument("--folder", help="a folder of PNGs named by the test")
    parser.add_argument("--out", default="ink-xcui.tsv")
    parser.add_argument("--label", default="")
    parser.add_argument("--leave-out", action="append", default=[], help="ref: a key (without the prefix) to leave out")
    args = parser.parse_args()
    if args.mode == "self-test":
        cases = self_test(args.ink)
        for name, ok, what in cases:
            print("%s: %s: %s" % ("ok" if ok else "FAILED", name, what))
        bad = sum(not ok for _, ok, _ in cases)
        print("xcui_ink self-test: %d cases, %d failed" % (len(cases), bad))
        sys.exit(1 if bad else 0)
    if bool(args.manifest) == bool(args.folder):
        parser.error("give --manifest or --folder")
    if args.mode == "ref":
        photos = manifest_photos(args.manifest) if args.manifest else folder_photos(args.folder)
        for key, path in photos:
            if key in args.leave_out or re.search(r" #[0-9]+$", key):
                continue
            p = subprocess.run([args.ink, "ref", path, args.prefix + key], stdout=subprocess.PIPE, universal_newlines=True,
                               timeout=120)
            if p.returncode != 0:
                sys.exit("ink_check ref failed on %s: %s" % (path, p.stdout.strip()))
            print(p.stdout.strip())
        return
    try:
        check(args)
    except Exception as error:  # noqa: BLE001 (never fails a job)
        print("::warning::%s" % escape("The handwriting check of the XCUITest photos stopped: %r (tools/shots/xcui_ink.py, "
                                       "a warning only)." % (error,)))
    sys.exit(0)


if __name__ == "__main__":
    main()
