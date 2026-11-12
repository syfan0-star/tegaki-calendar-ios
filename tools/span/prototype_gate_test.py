#!/usr/bin/env python3
"""The prototype gate's own test (docs/M7C_CONTRACT.md §4.6, §12.2 S3 (2); D12).

    python3 -I tools/span/prototype_gate_test.py [--gate <prototype_gate.py>]

Builds a throwaway git repository in a temporary folder (removed afterwards; nothing of this repository is read or
written) whose first commit stands in for 43fe366 — a SettingsScreen.swift with the rows of 設定 › 情報 and the two
string tables — and commits one change per case on top of it. Each case runs tools/span/prototype_gate.py (or
--gate) with --base and --head and expects OK or FAILED with the reason. The FAILED cases are the ways a change could
make the normal app differ from 43fe366 while only "adding" lines: a `#if SPAN_PROTOTYPE` block that wraps a row of
43fe366 (the row is gone from a build without SPAN_PROTOTYPE), a new key that is not a prototype key, a prototype key
with another language, a new key of InfoPlist.xcstrings, and the rules the gate had from the start. Prints one line
per case and exits 0 when every case gives what it should, 1 otherwise. build.yml runs it on every push.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SETTINGS = "Sources/TegakiCalendar/Views/SettingsScreen.swift"
LOCALIZABLE = "Sources/TegakiCalendar/Resources/Localizable.xcstrings"
INFOPLIST = "Sources/TegakiCalendar/Resources/InfoPlist.xcstrings"
SPAN = "Sources/TegakiCalendar/Span/"

SETTINGS_BASE = """import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        Section {
            countRow(Self.pageTitle, StrokeCensus.rowText(census?.page, counting: census == nil))
            countRow(Self.largestPageTitle, StrokeCensus.rowText(census?.largest, counting: census == nil))
            countRow(Self.yearPageTitle, StrokeCensus.yearRowText(census?.year, year: currentYear, counting: census == nil))
        } header: {
            Text(L.text("settings.info.header"))
        }
    }
}
"""

ENTRY = ["            #if SPAN_PROTOTYPE",
         "            // the prototype build's last row only",
         "            SpanPrototypeEntryRow()",
         "            #endif"]

YEAR_ROW = "            countRow(Self.yearPageTitle"
LARGEST_ROW = "            countRow(Self.largestPageTitle"


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


LOCALIZABLE_BASE = {
    "sourceLanguage": "en",
    "strings": {
        "settings.info.header": {"extractionState": "manual", "localizations": {"en": unit("Info"), "ja": unit("情報")}},
    },
    "version": "1.0",
}
INFOPLIST_BASE = {
    "sourceLanguage": "en",
    "strings": {
        "CFBundleDisplayName": {"extractionState": "manual", "localizations": {"en": unit("Tegaki"), "ja": unit("てがきカレンダー")}},
    },
    "version": "1.0",
}

PROTOTYPE_FILE = """// the prototype's screen
#if SPAN_PROTOTYPE
import SwiftUI

struct SpanPrototypeScreen: View {
    var body: some View { Text("x") }
}
#endif
"""


def catalog_text(data):
    return json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def settings_lines():
    return SETTINGS_BASE.split("\n")


def index_of(lines, prefix):
    return next(n for n, line in enumerate(lines) if line.startswith(prefix))


# Each case: (name, expected "OK" or "FAILED", a part of the FAIL line it must print (or None), the change: a function
# of the repository folder that writes the files of the change).

def entry_after_rows(root):
    lines = settings_lines()
    at = index_of(lines, YEAR_ROW) + 1
    write(root, SETTINGS, "\n".join(lines[:at] + ENTRY + lines[at:]))


def entry_wrapping_the_year_row(root):
    # The review's ISO-1: the new `#if` one line higher, around the year row of 43fe366.
    lines = settings_lines()
    at = index_of(lines, YEAR_ROW)
    write(root, SETTINGS, "\n".join(lines[:at] + [ENTRY[0], lines[at]] + ENTRY[1:] + lines[at + 1:]))


def only_if_and_endif_around_two_rows(root):
    # The review's G1 / CI-1: `#if SPAN_PROTOTYPE` before the two rows, `#endif` after them, nothing else.
    lines = settings_lines()
    first = index_of(lines, LARGEST_ROW)
    last = index_of(lines, YEAR_ROW)
    write(root, SETTINGS, "\n".join(lines[:first] + [ENTRY[0]] + lines[first:last + 1] + [ENTRY[3]] + lines[last + 1:]))


def a_row_removed(root):
    lines = settings_lines()
    at = index_of(lines, YEAR_ROW)
    write(root, SETTINGS, "\n".join(lines[:at] + ENTRY + lines[at + 1:]))


def a_line_outside_the_block(root):
    lines = settings_lines()
    at = index_of(lines, YEAR_ROW) + 1
    write(root, SETTINGS, "\n".join(lines[:at] + ENTRY + ["            Divider()"] + lines[at:]))


def a_block_with_else(root):
    lines = settings_lines()
    at = index_of(lines, YEAR_ROW) + 1
    write(root, SETTINGS, "\n".join(lines[:at] + ENTRY[:3] + ["            #else", "            Divider()"] + ENTRY[3:] + lines[at:]))


def with_strings(root, localizable=None, infoplist=None):
    data = json.loads(json.dumps(LOCALIZABLE_BASE))
    data["strings"].update(localizable or {})
    write(root, LOCALIZABLE, catalog_text(data))
    data = json.loads(json.dumps(INFOPLIST_BASE))
    data["strings"].update(infoplist or {})
    write(root, INFOPLIST, catalog_text(data))


def a_prototype_key(root):
    with_strings(root, {"prototype.span.close": {"extractionState": "manual", "localizations": {"ja": unit("閉じる")}}})


def a_key_that_is_not_a_prototype_key(root):
    with_strings(root, {"settings.extra.row": {"extractionState": "manual", "localizations": {"ja": unit("行")}}})


def a_prototype_key_in_two_languages(root):
    with_strings(root, {"prototype.span.close": {"extractionState": "manual",
                                                 "localizations": {"en": unit("Close"), "ja": unit("閉じる")}}})


def a_new_infoplist_key(root):
    with_strings(root, infoplist={"NSHumanReadableCopyright": {"extractionState": "manual", "localizations": {"ja": unit("x")}}})


def an_existing_text_changed(root):
    data = json.loads(json.dumps(LOCALIZABLE_BASE))
    data["strings"]["settings.info.header"]["localizations"]["ja"] = unit("じょうほう")
    write(root, LOCALIZABLE, catalog_text(data))


def a_prototype_file(root):
    write(root, SPAN + "SpanPrototypeScreen.swift", PROTOTYPE_FILE)


def a_prototype_file_with_code_after_endif(root):
    write(root, SPAN + "SpanPrototypeScreen.swift", PROTOTYPE_FILE + "let leaked = 1\n")


def another_new_file(root):
    write(root, SPAN + "SpanSession.swift", PROTOTYPE_FILE)


CASES = [
    ("the entry as its own block after the rows (r13's shape)", "OK", None, entry_after_rows),
    ("a block that wraps the year row of 43fe366 (ISO-1)", "FAILED", "is inside the #if SPAN_PROTOTYPE block", entry_wrapping_the_year_row),
    ("only #if and #endif around two rows of 43fe366 (G1, CI-1)", "FAILED", "is inside the #if SPAN_PROTOTYPE block", only_if_and_endif_around_two_rows),
    ("a row of 43fe366 replaced by the block", "FAILED", "removed or changed", a_row_removed),
    ("an added line after the block", "FAILED", "is outside every #if SPAN_PROTOTYPE block", a_line_outside_the_block),
    ("a block with #else", "FAILED", "has an #else / #elseif", a_block_with_else),
    ("a prototype key, ja only", "OK", None, a_prototype_key),
    ("a new key that is not a prototype key (ISO-2, G2, CI-2)", "FAILED", "is not a prototype key", a_key_that_is_not_a_prototype_key),
    ("a prototype key with en too", "FAILED", "(ja only)", a_prototype_key_in_two_languages),
    ("a new key of InfoPlist.xcstrings (ISO-2, G2, CI-2)", "FAILED", "takes no new key", a_new_infoplist_key),
    ("an existing text changed", "FAILED", "changed (an existing text must not change", an_existing_text_changed),
    ("a new prototype file, all inside #if SPAN_PROTOTYPE", "OK", None, a_prototype_file),
    ("a new prototype file with code after #endif", "FAILED", "is after the block's #endif", a_prototype_file_with_code_after_endif),
    ("another new file under Sources/TegakiCalendar", "FAILED", "not allowed before S4", another_new_file),
]


def write(root, path, text):
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def git(root, *args):
    # No hooks, no signing, a neutral author: the folder is thrown away.
    command = ["git", "-C", root, "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false",
               "-c", "user.name=prototype-gate-test", "-c", "user.email=prototype-gate-test@example.invalid"] + list(args)
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        sys.stderr.write("git %s failed: %s\n" % (" ".join(args), result.stderr.decode("utf-8", "replace")))
        sys.exit(2)
    return result.stdout.decode("utf-8").strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--gate", default=os.path.join(HERE, "prototype_gate.py"))
    args = parser.parse_args()
    folder = tempfile.mkdtemp(prefix="prototype-gate-test-")
    failures = 0
    try:
        root = os.path.join(folder, "repo")
        os.makedirs(root)
        git(root, "init", "-q")
        write(root, SETTINGS, SETTINGS_BASE)
        write(root, LOCALIZABLE, catalog_text(LOCALIZABLE_BASE))
        write(root, INFOPLIST, catalog_text(INFOPLIST_BASE))
        git(root, "add", "-A")
        git(root, "commit", "-q", "-m", "base")
        base = git(root, "rev-parse", "HEAD")
        for name, expected, reason, change in CASES:
            git(root, "checkout", "-q", "--detach", base)
            change(root)
            git(root, "add", "-A")
            git(root, "commit", "-q", "-m", name)
            result = subprocess.run([sys.executable, "-I", args.gate, root, "--base", base, "--head", "HEAD"],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            output = result.stdout.decode("utf-8", "replace")
            got = "OK" if result.returncode == 0 and output.rstrip().endswith("prototype gate: OK") else (
                "FAILED" if result.returncode == 1 else "error %d" % result.returncode)
            fail_lines = [line.strip() for line in output.split("\n") if line.strip().startswith("FAIL")]
            good = got == expected and (reason is None or any(reason in line for line in fail_lines))
            if not good:
                failures += 1
            print("%s %s: expected %s, got %s%s" % ("ok  " if good else "BAD ", name, expected, got,
                                                  (" — " + fail_lines[0]) if fail_lines else ""))
            if not good and result.stderr:
                print("     " + result.stderr.decode("utf-8", "replace").strip())
    finally:
        shutil.rmtree(folder, ignore_errors=True)
    print("prototype gate test: %d case(s), %s" % (len(CASES), "all as expected" if failures == 0 else "%d not as expected" % failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
