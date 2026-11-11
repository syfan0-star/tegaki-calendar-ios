#!/usr/bin/env python3
"""The second check of the prototype build's gate (docs/M7C_CONTRACT.md §4.6, §12.2 S3 (2); D12).

    python3 -I tools/span/prototype_gate.py [<repo>] [--base <commit>] [--head <commit>]

<repo> defaults to the repository this script is in, --base to 43fe366 (1.2.3, the bytes the normal app must
keep), --head to HEAD. Reads `git diff --name-status <base> <head> -- Sources/TegakiCalendar` and accepts only:

  A  Sources/TegakiCalendar/Span/SpanPrototype*.swift
       a new file whose whole code is one `#if SPAN_PROTOTYPE` … `#endif` block (comment and empty lines may stand
       before it; nothing but empty lines after it; no `#else` / `#elseif` of that block), so a build without
       SPAN_PROTOTYPE compiles nothing of it;
  M  Sources/TegakiCalendar/Views/SettingsScreen.swift
       lines added only (none removed or changed), every added line inside a `#if SPAN_PROTOTYPE` … `#endif` block
       of the new file that has no `#else` / `#elseif` (the entry row of 設定 › 情報);
  M  Sources/TegakiCalendar/Resources/Localizable.xcstrings, InfoPlist.xcstrings
       the generated string tables: every key of <base> is there with the same value byte for byte (no existing
       text changes, L-3); new keys are listed.

Anything else under Sources/TegakiCalendar (a changed, removed or renamed file, another new file) fails. Prints
one line per file and `prototype gate: OK` or `prototype gate: FAILED`; the exit status is 0 or 1 (2 for a git
error). Writes nothing. CI runs it in testflight.yml when the input span_prototype is 1; the lead can run it on a
Mac for the record in docs/M7C.md.
"""
import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
BASE = "43fe36666a2120e8a23adf4fc76244151a395e6f"

APP = "Sources/TegakiCalendar/"
PROTOTYPE_FILE = re.compile(r"^Sources/TegakiCalendar/Span/SpanPrototype[^/]*\.swift$")
SETTINGS = "Sources/TegakiCalendar/Views/SettingsScreen.swift"
CATALOGS = ("Sources/TegakiCalendar/Resources/Localizable.xcstrings", "Sources/TegakiCalendar/Resources/InfoPlist.xcstrings")

IF_MARK = re.compile(r"^\s*#if\s+SPAN_PROTOTYPE\s*(//.*)?$")
IF_ANY = re.compile(r"^\s*#if\b")
ELSE_ANY = re.compile(r"^\s*#(else|elseif)\b")
ENDIF = re.compile(r"^\s*#endif\b")
HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")


def git(repo, *args):
    result = subprocess.run(["git", "-C", repo] + list(args), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        sys.stderr.write("prototype gate: git %s failed: %s\n" % (" ".join(args), result.stderr.decode("utf-8", "replace").strip()))
        sys.exit(2)
    return result.stdout.decode("utf-8")


def prototype_blocks(lines):
    """The (first, last) line numbers (1-based, inclusive) of every `#if SPAN_PROTOTYPE` block, and whether each
    has an `#else` / `#elseif` of its own. Nested `#if`s inside a block are followed by depth."""
    blocks = []
    stack = []  # entries: [is_prototype, start, has_else]
    for number, line in enumerate(lines, start=1):
        if IF_ANY.match(line):
            stack.append([bool(IF_MARK.match(line)), number, False])
        elif ELSE_ANY.match(line):
            if stack:
                stack[-1][2] = True
        elif ENDIF.match(line):
            if stack:
                is_prototype, start, has_else = stack.pop()
                if is_prototype:
                    blocks.append((start, number, has_else))
    return blocks, bool(stack)


def check_new_file(text):
    """A new prototype file: one SPAN_PROTOTYPE block holding every line of code."""
    lines = text.split("\n")
    blocks, unclosed = prototype_blocks(lines)
    if unclosed:
        return "an #if is not closed"
    code = [n for n, line in enumerate(lines, start=1) if line.strip() and not line.strip().startswith("//")]
    if not code:
        return "no code"
    outer = [b for b in blocks if b[0] == code[0]]
    if not outer:
        return "the first line of code (line %d) is not `#if SPAN_PROTOTYPE`" % code[0]
    start, end, has_else = outer[0]
    if has_else:
        return "the SPAN_PROTOTYPE block has an #else / #elseif (that part would be in the normal app)"
    after = [n for n, line in enumerate(lines, start=1) if n > end and line.strip()]
    if after:
        return "line %d is after the block's #endif (line %d)" % (after[0], end)
    return None


def check_settings(repo, base, head):
    diff = git(repo, "diff", "-U0", "--no-color", base, head, "--", SETTINGS)
    added = []
    removed = 0
    for line in diff.split("\n"):
        m = HUNK.match(line)
        if m:
            removed += int(m.group(2)) if m.group(2) is not None else 1
            count = int(m.group(4)) if m.group(4) is not None else 1
            first = int(m.group(3))
            added.extend(range(first, first + count))
    if removed:
        return "%d line(s) of 43fe366 removed or changed (only additions inside #if SPAN_PROTOTYPE are allowed)" % removed, added
    lines = git(repo, "show", "%s:%s" % (head, SETTINGS)).split("\n")
    blocks, unclosed = prototype_blocks(lines)
    if unclosed:
        return "an #if is not closed", added
    bad_blocks = [b for b in blocks if b[2]]
    if bad_blocks:
        return "the SPAN_PROTOTYPE block at line %d has an #else / #elseif" % bad_blocks[0][0], added
    outside = [n for n in added if not any(start <= n <= end for start, end, _ in blocks)]
    if outside:
        return "added line %d is outside every #if SPAN_PROTOTYPE block" % outside[0], added
    return None, added


def check_catalog(repo, base, head, path):
    old = json.loads(git(repo, "show", "%s:%s" % (base, path)))
    new = json.loads(git(repo, "show", "%s:%s" % (head, path)))
    for key in sorted(set(old) | set(new)):
        if key != "strings" and old.get(key) != new.get(key):
            return "the top-level item %r changed" % key, []
    old_strings = old.get("strings", {})
    new_strings = new.get("strings", {})
    for key, value in sorted(old_strings.items()):
        if key not in new_strings:
            return "the key %r of 43fe366 is gone" % key, []
        if json.dumps(new_strings[key], sort_keys=True, ensure_ascii=False) != json.dumps(value, sort_keys=True, ensure_ascii=False):
            return "the key %r of 43fe366 changed (an existing text must not change, L-3)" % key, []
    return None, sorted(set(new_strings) - set(old_strings))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("repo", nargs="?", default=DEFAULT_REPO)
    parser.add_argument("--base", default=BASE)
    parser.add_argument("--head", default="HEAD")
    args = parser.parse_args()
    repo = args.repo
    base = git(repo, "rev-parse", args.base + "^{commit}").strip()
    head = git(repo, "rev-parse", args.head + "^{commit}").strip()
    print("prototype gate: %s against %s, %s" % (head, base, APP.rstrip("/")))
    failed = False
    entries = [line.split("\t") for line in git(repo, "diff", "--name-status", "--no-renames", base, head, "--", APP).split("\n") if line]
    if not entries:
        print("  no file under %s differs from %s" % (APP.rstrip("/"), base[:7]))
    for entry in entries:
        status, path = entry[0], entry[-1]
        problem = None
        note = ""
        if status == "A" and PROTOTYPE_FILE.match(path):
            problem = check_new_file(git(repo, "show", "%s:%s" % (head, path)))
            note = "new, all inside #if SPAN_PROTOTYPE"
        elif status == "M" and path == SETTINGS:
            problem, added = check_settings(repo, base, head)
            note = "%d line(s) added inside #if SPAN_PROTOTYPE, none removed" % len(added)
        elif status == "M" and path in CATALOGS:
            problem, new_keys = check_catalog(repo, base, head, path)
            note = "every key of 43fe366 unchanged; new keys: %s" % (", ".join(new_keys) if new_keys else "none")
        else:
            problem = "not allowed before S4 (only Span/SpanPrototype*.swift, the entry in Views/SettingsScreen.swift and the string tables)"
        if problem:
            failed = True
            print("  FAIL %s %s: %s" % (status, path, problem))
        else:
            print("  ok   %s %s: %s" % (status, path, note))
    print("prototype gate: %s" % ("FAILED" if failed else "OK"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
