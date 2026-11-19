#!/usr/bin/env python3
"""The watch on how the app tells devices apart (docs/M7D_CONTRACT.md §4.1, 0d-19; build.yml's build-and-test).

1.4 lays the screen out by the size of the window, never by the kind of device ([S15][S43]: no `UIScreen.main` for sizes
or scales, no device orientation, no idiom or size class to tell a device), and tells the iPhone Duo by the Pencil's touch
and the hinge only, never by a model name (§4.8). This script keeps 1.5 and later from bringing such a reading back
unseen: it reads every Swift file under Sources/TegakiCalendar except the 20 frozen files (tools/l10n/lint-skip.txt, the
rows of tools/compat10/DATA_1_1.sha256; frozen InkTrace.swift's record of the model is not read) and finds, in their code
(comments are not code and are not read; string literals are, for the model names):

  idiom               userInterfaceIdiom
  main-screen         UIScreen.main                                  never allowed
  device-orientation  UIDevice.current.orientation
  orientation         interfaceOrientation (interfaceOrientations: and supportedInterfaceOrientations too)
  model-name          utsname, "hw.machine" / "hw.model", UIDevice.current.model / .localizedModel, and a string
                      that starts "iPhone1 … "iPhone9 (a model identifier)        never allowed

Each line of code that has one must be covered by a row of tools/duo/idiom-allow.txt:

  <path from the repository's top>|<text of that line>|<why it is allowed>

  - the text is a part of the line as it is in the file (spaces at its ends do not count) and holds the word found
    there; it may hold "|" (the path is up to the first "|", the reason after the last one), the reason may not;
  - a row covers one line: a text that is on two lines of the file needs two rows (so a third copy is seen);
  - a row that covers no line fails too, so the list stays exactly the code's (§4.1: "D1 の最初に全部を数えて書く");
  - a row whose text holds UIScreen.main or a model name fails (§4.1: they never go on the list; after 1.4 there are 0
    of them outside the frozen files). `identifierForVendor` is not the kind of device and is not looked for.
  - lines starting with "#" and empty lines are comments.

  python3 -I tools/duo/idiom_check.py [<repository>] [--list]   (exit 0: ok, 1: a problem, 2: usage)
  python3 -I tools/duo/idiom_check.py --self-test                (the watch tried on made-up files; exit 0 when it bites)

Standard library only; reads, never writes in the repository.
"""
import os
import re
import sys
import tempfile

SOURCES = "Sources/TegakiCalendar"
FROZEN_LIST = "tools/l10n/lint-skip.txt"
ALLOW_LIST = "tools/duo/idiom-allow.txt"

# (kind, pattern, may it be allowed?) in the order they are reported.
PATTERNS = [
    ("idiom", re.compile(r"userInterfaceIdiom"), True),
    ("main-screen", re.compile(r"UIScreen\s*\.\s*main"), False),
    ("device-orientation", re.compile(r"UIDevice\s*\.\s*current\s*\.\s*orientation"), True),
    ("orientation", re.compile(r"interfaceOrientation"), True),
    ("model-name", re.compile(r"\butsname\b"), False),
    ("model-name", re.compile(r"hw\.(?:machine|model)\b"), False),
    ("model-name", re.compile(r"UIDevice\s*\.\s*current\s*\.\s*(?:model|localizedModel)\b"), False),
    ("model-name", re.compile(r"\"iPhone[1-9]"), False),
]
NEVER = [p for kind, p, allowed in PATTERNS if not allowed]


def code_only(text):
    """The text with Swift's comments (// to the end of the line, nested /* */) turned into spaces; string literals
    ("…", multi-line \"\"\"…\"\"\", raw #"…"#, with their \\( ) interpolations) are kept as they are. Lines and columns
    stay where they were."""
    out = []
    n = len(text)
    i = 0
    stack = [["code", 0]]  # ["code", parens inside an interpolation] / ["str", hashes, multi-line]
    while i < n:
        top = stack[-1]
        c = text[i]
        if top[0] == "code":
            if text.startswith("//", i):
                j = text.find("\n", i)
                j = n if j < 0 else j
                out.append(" " * (j - i))
                i = j
                continue
            if text.startswith("/*", i):
                depth = 0
                while i < n:
                    if text.startswith("/*", i):
                        depth += 1
                        out.append("  ")
                        i += 2
                    elif text.startswith("*/", i):
                        depth -= 1
                        out.append("  ")
                        i += 2
                        if depth == 0:
                            break
                    else:
                        out.append("\n" if text[i] == "\n" else " ")
                        i += 1
                continue
            if c in "#\"":
                j = i
                while j < n and text[j] == "#":
                    j += 1
                if j < n and text[j] == "\"":
                    multi = text.startswith("\"\"\"", j)
                    end = j + (3 if multi else 1)
                    stack.append(["str", j - i, multi])
                    out.append(text[i:end])
                    i = end
                    continue
                out.append(text[i:j] if j > i else c)
                i = j if j > i else i + 1
                continue
            if len(stack) > 1:
                if c == "(":
                    top[1] += 1
                elif c == ")":
                    if top[1] == 0:
                        stack.pop()
                        out.append(c)
                        i += 1
                        continue
                    top[1] -= 1
            out.append(c)
            i += 1
            continue
        # inside a string literal
        hashes, multi = top[1], top[2]
        escape = "\\" + "#" * hashes
        if text.startswith(escape, i):
            k = i + len(escape)
            if k < n and text[k] == "(":
                stack.append(["code", 0])
                out.append(text[i:k + 1])
                i = k + 1
                continue
            out.append(text[i:k + 1])
            i = k + 1
            continue
        close = ("\"\"\"" if multi else "\"") + "#" * hashes
        if text.startswith(close, i):
            stack.pop()
            out.append(close)
            i += len(close)
            continue
        if c == "\n" and not multi:  # an unclosed string ends with its line (it would not compile anyway)
            stack.pop()
        out.append(c)
        i += 1
    return "".join(out)


def frozen_paths(repo):
    """The frozen files of tools/l10n/lint-skip.txt (not read here)."""
    paths = set()
    with open(os.path.join(repo, FROZEN_LIST), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                paths.add(line)
    return paths


def swift_files(repo, frozen):
    found = []
    top = os.path.join(repo, SOURCES)
    for folder, dirs, names in os.walk(top):
        dirs.sort()
        for name in sorted(names):
            if not name.endswith(".swift"):
                continue
            path = os.path.relpath(os.path.join(folder, name), repo).replace(os.sep, "/")
            if path not in frozen:
                found.append(path)
    return found


def findings(repo, paths):
    """[(path, line number, raw line, [(kind, matched text, allowed?)])] for every line of code with a word of PATTERNS."""
    found = []
    for path in paths:
        with open(os.path.join(repo, path), encoding="utf-8") as f:
            raw = f.read()
        code = code_only(raw).split("\n")
        lines = raw.split("\n")
        for number, (line, code_line) in enumerate(zip(lines, code), start=1):
            hits = []
            for kind, pattern, allowed in PATTERNS:
                for m in pattern.finditer(code_line):
                    hits.append((kind, m.group(0), allowed))
            if hits:
                found.append((path, number, line, hits))
    return found


def read_allow(repo, problems):
    """[(row number, path, text, reason)] of tools/duo/idiom-allow.txt."""
    rows = []
    try:
        f = open(os.path.join(repo, ALLOW_LIST), encoding="utf-8")
    except OSError as error:
        problems.append("%s cannot be read (%s)" % (ALLOW_LIST, error))
        return rows
    with f:
        for number, line in enumerate(f, start=1):
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if line.count("|") < 2:
                problems.append("%s:%d: not <path>|<text>|<reason>: %s" % (ALLOW_LIST, number, line))
                continue
            path, rest = line.split("|", 1)
            text, reason = rest.rsplit("|", 1)
            path, text, reason = path.strip(), text.strip(), reason.strip()
            if not path or not text or not reason:
                problems.append("%s:%d: the path, the text and the reason must each be there: %s" % (ALLOW_LIST, number, line))
                continue
            if any(p.search(text) for p in NEVER):
                problems.append("%s:%d: UIScreen.main and the model names are never allowed (docs/M7D_CONTRACT.md §4.1): %s"
                                % (ALLOW_LIST, number, text))
                continue
            rows.append((number, path, text, reason))
    return rows


def check(repo, show_all=False, out=sys.stdout):
    """Prints what it found; returns the number of problems."""
    problems = []
    try:
        frozen = frozen_paths(repo)
    except OSError as error:
        print("idiom_check: %s cannot be read (%s)" % (FROZEN_LIST, error), file=out)
        return 1
    paths = swift_files(repo, frozen)
    found = findings(repo, paths)
    allow = read_allow(repo, problems)
    lines = []  # the lines a row may cover
    for path, number, line, hits in found:
        never = [h for h in hits if not h[2]]
        if never:
            problems.append("%s:%d: %s is never allowed (docs/M7D_CONTRACT.md §4.1: the layout by the window, the Duo by the "
                            "Pencil and the hinge, never UIScreen.main or a model name): %s"
                            % (path, number, ", ".join(sorted({h[1] for h in never})), line.strip()))
        else:
            lines.append((path, number, line, sorted({h[1] for h in hits})))
    # Which row covers which line: a row covers a line of its file that holds its text, when its text holds a word found
    # on that line; each row covers one line and each line needs one row (a matching, so the rows' order and a short row
    # that fits many lines do not matter).
    fits = [[r for r, (number, path, text, reason) in enumerate(allow)
             if path == lpath and text in line and any(w in text for w in words)]
            for lpath, lnumber, line, words in lines]
    row_of_line = {}
    line_of_row = {}

    def take(index, seen):
        free = next((r for r in fits[index] if r not in line_of_row), None)
        if free is not None:  # the first free row (rows listed in the code's order report in that order)
            line_of_row[free] = index
            row_of_line[index] = free
            return True
        for r in fits[index]:
            if r in seen:
                continue
            seen.add(r)
            if r not in line_of_row or take(line_of_row[r], seen):
                line_of_row[r] = index
                row_of_line[index] = r
                return True
        return False

    for index in range(len(lines)):
        take(index, set())
    for index, (path, number, line, words) in enumerate(lines):
        if index not in row_of_line:
            problems.append("%s:%d: %s, not in %s (add \"%s|<the line's text>|<why>\" when it does not tell the device "
                            "apart for the layout or the input, docs/M7D_CONTRACT.md §4.1): %s"
                            % (path, number, ", ".join(words), ALLOW_LIST, path, line.strip()))
        elif show_all:
            row = allow[row_of_line[index]]
            print("  %s:%d: %s (allowed by row %d: %s)" % (path, number, ", ".join(words), row[0], row[3]), file=out)
    allowed_lines = len(row_of_line)
    for r, (number, path, text, reason) in enumerate(allow):
        if r not in line_of_row:
            problems.append("%s:%d: covers no line (%s|%s): take the row away, or the code moved" % (ALLOW_LIST, number, path, text))
    for problem in problems:
        print("::error::idiom_check: " + problem, file=out)
    print("idiom_check: %d lines in %d Swift files of %s (the %d frozen files not read), %d allowed by %s, %d problem%s: %s"
          % (len(found), len(paths), SOURCES, len(frozen), allowed_lines, ALLOW_LIST, len(problems),
             "" if len(problems) == 1 else "s", "ok" if not problems else "FAILED"), file=out)
    return len(problems)


# ── the self-test ────────────────────────────────────────────────────────────────────────────────────────────────

def self_test():
    """Made-up repositories in a temporary folder: the watch must pass the good one and fail each bad one."""
    import io

    frozen_file = "Sources/TegakiCalendar/Ink/Frozen.swift"
    base = {
        FROZEN_LIST: "# frozen\n%s\n" % frozen_file,
        frozen_file: "let s = UIScreen.main.scale  // frozen: never read\n",
        "Sources/TegakiCalendar/Views/A.swift": (
            "import UIKit\n"
            "/* UIScreen.main in a block comment /* nested userInterfaceIdiom */ still a comment */\n"
            "// UIScreen.main and utsname in a line comment\n"
            "let url = \"https://example.com/a//b\" // a // inside a string is not a comment\n"
            "let isPad = UIDevice.current.userInterfaceIdiom == .pad\n"
            "let other = UIDevice.current.userInterfaceIdiom == .pad\n"
            "let isPad2 = UIDevice.current.userInterfaceIdiom == .pad\n"
            "let s = \"\\(isPad ? \"a\" : \"b\") ok\" // interpolation with strings inside\n"
            "let t = #\"raw \\(not) \"quoted\" \"#\n"
            "let m = \"\"\"\n"
            "  UIScreen.main inside a multi-line string is read\n"
            "  \"\"\"\n"
        ),
        "Sources/TegakiCalendar/Views/B.swift": "scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))\n",
        "Sources/TegakiCalendar/Views/C.txt": "UIScreen.main (not Swift)\n",
    }
    allow_ok = (
        "# comment\n"
        "Sources/TegakiCalendar/Views/A.swift|let isPad = UIDevice.current.userInterfaceIdiom == .pad|the iPad's default\n"
        "Sources/TegakiCalendar/Views/A.swift|let other = UIDevice.current.userInterfaceIdiom == .pad|reason two\n"
        "Sources/TegakiCalendar/Views/A.swift|UIDevice.current.userInterfaceIdiom == .pad|the third line\n"
        "Sources/TegakiCalendar/Views/B.swift|interfaceOrientations: .landscapeRight|screenshot mode's landscape\n"
    )
    # The multi-line string holds UIScreen.main: that must fail; the good tree has it out.
    good = dict(base)
    good["Sources/TegakiCalendar/Views/A.swift"] = base["Sources/TegakiCalendar/Views/A.swift"].replace(
        "  UIScreen.main inside a multi-line string is read\n", "  nothing here\n")
    good[ALLOW_LIST] = allow_ok

    a = "Sources/TegakiCalendar/Views/A.swift"
    cases = [
        ("the good tree", good, 0),
        ("UIScreen.main added outside the frozen files (§6 C row's mutation)",
         dict(good, **{a: good[a] + "let w = UIScreen.main.bounds.width\n"}), 1),
        ("UIScreen.main in a multi-line string", dict(base, **{ALLOW_LIST: allow_ok}), 1),
        ("a model name: utsname", dict(good, **{a: good[a] + "var info = utsname()\n"}), 1),
        ("a model name: hw.machine", dict(good, **{a: good[a] + "sysctlbyname(\"hw.machine\", nil, &size, nil, 0)\n"}), 1),
        ("a model name: UIDevice.current.model", dict(good, **{a: good[a] + "let m = UIDevice.current.model\n"}), 1),
        ("a model identifier string", dict(good, **{a: good[a] + "if id == \"iPhone19,1\" { }\n"}), 1),
        ("device orientation", dict(good, **{a: good[a] + "let o = UIDevice.current.orientation\n"}), 1),
        ("a fourth idiom line with no row", dict(good, **{a: good[a] + "let x = UIDevice.current.userInterfaceIdiom == .pad\n"}), 1),
        ("a row that covers no line", dict(good, **{ALLOW_LIST: allow_ok + "Sources/TegakiCalendar/Views/B.swift|gone|old\n"}), 1),
        ("a row for UIScreen.main",
         dict(good, **{a: good[a] + "let w = UIScreen.main.bounds.width\n",
                       ALLOW_LIST: allow_ok + a + "|let w = UIScreen.main.bounds.width|tried\n"}), 2),
        ("a row without a reason (its line is then not covered)",
         dict(good, **{ALLOW_LIST: allow_ok.replace("|reason two", "|")}), 2),
        ("the rows in another order (a short row first)",
         dict(good, **{ALLOW_LIST: "\n".join(reversed(allow_ok.strip().split("\n"))) + "\n"}), 0),
        ("a row whose text does not hold the word",
         dict(good, **{ALLOW_LIST: allow_ok.replace("interfaceOrientations: .landscapeRight", "requestGeometryUpdate")}), 2),
        ("a row with \"|\" in its text", dict(good, **{
            "Sources/TegakiCalendar/Views/B.swift": "if a || UIDevice.current.userInterfaceIdiom == .pad { }\n",
            ALLOW_LIST: allow_ok.replace("Sources/TegakiCalendar/Views/B.swift|interfaceOrientations: .landscapeRight|screenshot mode's landscape\n",
                                         "Sources/TegakiCalendar/Views/B.swift|a || UIDevice.current.userInterfaceIdiom|a row with a bar\n")}), 0),
    ]
    failed = 0
    with tempfile.TemporaryDirectory(prefix="idiom-check-") as tmp:
        for index, (name, tree, want) in enumerate(cases):
            root = os.path.join(tmp, "repo%d" % index)
            for path, text in tree.items():
                os.makedirs(os.path.dirname(os.path.join(root, path)), exist_ok=True)
                with open(os.path.join(root, path), "w", encoding="utf-8") as f:
                    f.write(text)
            buffer = io.StringIO()
            got = check(root, out=buffer)
            ok = got == want
            failed += not ok
            print("%s %s: %d problem%s (expected %d)" % ("ok  " if ok else "FAIL", name, got, "" if got == 1 else "s", want))
            if not ok:
                print("     " + buffer.getvalue().replace("\n", "\n     "))
    # code_only keeps lines and columns.
    sample = "a /* b\nc */ d // e\n\"//\" \"\\(f(\"g\"))\"\n"
    stripped = code_only(sample)
    ok = len(stripped) == len(sample) and stripped.split("\n")[1].startswith("     d") and "//" in stripped.split("\n")[2]
    failed += not ok
    print("%s code_only keeps the lines and the columns" % ("ok  " if ok else "FAIL"))
    print("idiom_check self-test: %s" % ("ok" if not failed else "%d FAILED" % failed))
    return 1 if failed else 0


def main(argv):
    args = argv[1:]
    if args == ["--self-test"]:
        return self_test()
    show_all = "--list" in args
    rest = [a for a in args if a != "--list"]
    if len(rest) > 1 or any(a.startswith("-") for a in rest):
        print(__doc__, file=sys.stderr)
        return 2
    repo = rest[0] if rest else "."
    if not os.path.isdir(os.path.join(repo, SOURCES)):
        print("idiom_check: %s has no %s" % (repo, SOURCES), file=sys.stderr)
        return 2
    return 1 if check(repo, show_all=show_all) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
