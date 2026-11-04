#!/usr/bin/env python3
"""The Japanese strings of 1.1.1, for J-1 (docs/M7B_CONTRACT.md §1.3, §1.5; lint L-3).

    python3 -I tools/l10n/baseline.py [<repo>] [--commit <rev>] [--tree <dir>] [--check]

<repo> defaults to the repository this script is in. Reads the Swift sources of the <1.1.1> commit
(--commit, default BASE_COMMIT below: the head of fix-1-1-1 for now, §1.5 moves it to the merge of 1.1.1
into main) with `git archive`, and writes tools/l10n/ja-baseline.tsv: one line for every string literal of
Sources/TegakiCalendar and TegakiKit/Sources (KitChecks excluded; the tests are outside both) that
has Japanese in its text, comments excluded. With --check nothing is written: the exit status is 1
when the file is not what the commit gives.

When git cannot run (for example a Python running under Rosetta, whose /usr/bin/git shim cannot load
the arm64 libxcrun: use /usr/bin/python3 then), extract the commit yourself and pass the folder:
    git archive <commit> | tar -x -C <dir>
    python3 -I tools/l10n/baseline.py --tree <dir> --commit <the full commit id>

The file (tab-separated, UTF-8, "#" lines are comments):
    # commit: <the 40 hex digits of the commit>
    # strings: <rows> in <files> files
    <file> <TAB> <line> <TAB> <the string>
<file> is the path without "Sources/TegakiCalendar/" (the app) or "TegakiKit/Sources/" (the Kit), as
in the contract: Views/SettingsScreen.swift, Access/PlanText.swift. <line> is the line of the opening
quote. <the string> is the text between the quotes as the Swift source writes it: "\\n" stays the
two characters \\ and n, and an interpolation stays "\\(…)" (§2.3). The rows of a file are in source
order, so the strings of one line are in order from left to right (a key's `was` can name the second
one as "<file>:<line>#2", see lint.py).

The same scanner finds the strings of lint L-1 (lint.py): string literals ("…", \"\"\"…\"\"\", #"…"#) are
found by a small Swift lexer, not a regular expression, so a string inside an interpolation counts,
and "//" or "/*" inside a string is not a comment. "Japanese" is kana, kanji, hangul and the
full-width signs (U+3000–U+303F, U+FF00–U+FFEF) and their neighbouring CJK blocks (JA_RANGES).
"""
import argparse
import bisect
import io
import os
import re
import subprocess
import sys
import tarfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_REPO = os.path.normpath(os.path.join(HERE, "..", ".."))

BASE_COMMIT = "31d243c725f141f60ff62c9ad8d12148d5f7e86d"  # <1.1.1> (§1.5): the provisional one until 1.1.1 is on main
TSV = "tools/l10n/ja-baseline.tsv"

APP_ROOT = "Sources/TegakiCalendar/"
KIT_ROOT = "TegakiKit/Sources/"
ROOTS = (APP_ROOT, KIT_ROOT)
# Not scanned: the checks run on a Mac (KitChecks, like the tests, may write Japanese freely) and
# the generated table of the Kit's strings (lint L-2 and L-10 look at it instead).
EXCLUDED_DIRS = (KIT_ROOT + "KitChecks/",)
GENERATED = (KIT_ROOT + "DayKit/KitStrings.generated.swift",)

# The characters that make a string "Japanese" (L-1: kana, kanji, hangul, the full-width signs).
JA_RANGES = [
    (0x1100, 0x11FF),    # Hangul Jamo
    (0x2E80, 0x2FDF),    # CJK Radicals Supplement, Kangxi Radicals
    (0x2FF0, 0x2FFF),    # Ideographic Description Characters
    (0x3000, 0x303F),    # CJK Symbols and Punctuation (full-width space, 「」, 〜, 、。)
    (0x3040, 0x30FF),    # Hiragana, Katakana (・ and ー included)
    (0x3130, 0x318F),    # Hangul Compatibility Jamo
    (0x3190, 0x31FF),    # Kanbun, Bopomofo Extended, CJK Strokes, Katakana Phonetic Extensions
    (0x3200, 0x33FF),    # Enclosed CJK Letters and Months, CJK Compatibility (㈱, ㌔)
    (0x3400, 0x4DBF),    # CJK Unified Ideographs Extension A
    (0x4E00, 0x9FFF),    # CJK Unified Ideographs
    (0xA960, 0xA97F),    # Hangul Jamo Extended-A
    (0xAC00, 0xD7FF),    # Hangul Syllables, Hangul Jamo Extended-B
    (0xF900, 0xFAFF),    # CJK Compatibility Ideographs
    (0xFE30, 0xFE4F),    # CJK Compatibility Forms
    (0xFF00, 0xFFEF),    # Halfwidth and Fullwidth Forms (（）, ！, ｶﾅ)
    (0x1B000, 0x1B16F),  # Kana Supplement, Kana Extended-A, Small Kana Extension
    (0x20000, 0x3134F),  # CJK Unified Ideographs Extensions B–G, Compatibility Supplement
]
JA_RE = re.compile("[" + "".join(f"\\U{low:08x}-\\U{high:08x}" for low, high in JA_RANGES) + "]")


class BaselineError(Exception):
    """The commit, the tree or the file cannot be read; the message says why."""


def has_japanese(text):
    return JA_RE.search(text) is not None


def short_path(path):
    """"Sources/TegakiCalendar/Views/A.swift" → "Views/A.swift", "TegakiKit/Sources/Access/B.swift"
    → "Access/B.swift"; a path already in that form stays as it is."""
    for root in ROOTS:
        if path.startswith(root):
            return path[len(root):]
    return path


def scanned(path):
    """Whether lint L-1 and the baseline look at the repository path `path`."""
    return (path.endswith(".swift") and path.startswith(ROOTS)
            and not path.startswith(EXCLUDED_DIRS) and path not in GENERATED)


# ── The Swift lexer (string literals only) ─────────────────────────────────────────────────────

class Literal:
    """One string literal of a Swift source.

    line, column  where it starts (1-based; the column counts characters, a leading "#" included)
    body          the source between the delimiters ("\\n" as two characters, "\\(…)" as written)
    text          the body without its interpolations: what decides whether it is Japanese (a string
                  inside an interpolation is a literal of its own)
    hashes        the number of "#" of a raw string (#"…"# is 1), 0 for an ordinary one
    multiline     \"\"\"…\"\"\"
    interpolated  the body has an interpolation "\\(…)"
    terminated    False when the source ends the line (or the file) before the closing quote
    """
    __slots__ = ("line", "column", "body", "text", "hashes", "multiline", "interpolated", "terminated")

    def __init__(self, line, column, body, text, hashes, multiline, interpolated, terminated):
        self.line, self.column, self.body, self.text = line, column, body, text
        self.hashes, self.multiline = hashes, multiline
        self.interpolated, self.terminated = interpolated, terminated


_RAW_START = re.compile(r'#+"')


def swift_literals(src):
    """Every string literal of the Swift source `src`, in source order (a literal inside an
    interpolation comes after the one around it)."""
    n = len(src)
    newlines = [i for i, ch in enumerate(src) if ch == "\n"]
    found = []

    def position(i):
        k = bisect.bisect_left(newlines, i)  # the newlines before index i
        return k + 1, i - (newlines[k - 1] if k else -1)

    def skip_comment(i):
        """i is at "//" or "/*": the index after the comment (block comments nest in Swift)."""
        if src.startswith("//", i):
            j = src.find("\n", i)
            return n if j < 0 else j
        depth, i = 1, i + 2
        while i < n and depth:
            if src.startswith("/*", i):
                depth, i = depth + 1, i + 2
            elif src.startswith("*/", i):
                depth, i = depth - 1, i + 2
            else:
                i += 1
        return i

    def code(i, interpolation):
        """Code from i: to the end of the source, or (interpolation) to the ")" that closes it;
        returns the index after that ")"."""
        depth = 0
        while i < n:
            ch = src[i]
            if ch == "/" and (src.startswith("//", i) or src.startswith("/*", i)):
                i = skip_comment(i)
            elif ch == '"' or (ch == "#" and _RAW_START.match(src, i)):
                i = string(i)
            elif interpolation and ch == "(":
                depth, i = depth + 1, i + 1
            elif interpolation and ch == ")":
                if depth == 0:
                    return i + 1
                depth, i = depth - 1, i + 1
            else:
                i += 1
        return i

    def string(i):
        """i is at the first "#" or the opening quote; returns the index after the literal."""
        start, j = i, i
        while src[j] == "#":
            j += 1
        hashes = j - start
        multiline = src.startswith('"""', j)
        j += 3 if multiline else 1
        body_start = j
        close = ('"""' if multiline else '"') + "#" * hashes
        escape = "\\" + "#" * hashes
        slot = len(found)
        found.append(None)  # keeps the outer literal before the ones inside its interpolations
        pieces, piece_start, interpolated = [], j, False
        while j < n:
            if src.startswith(escape, j):
                k = j + len(escape)
                if k < n and src[k] == "(":
                    pieces.append(src[piece_start:j])
                    interpolated = True
                    j = code(k + 1, True)
                    piece_start = j
                else:
                    j = k + 1  # \n, \", \\, \u{…} (the "{…}" is plain text after the "u")
                continue
            if src.startswith(close, j):
                pieces.append(src[piece_start:j])
                line, column = position(start)
                found[slot] = Literal(line, column, src[body_start:j], "".join(pieces), hashes,
                                      multiline, interpolated, True)
                return j + len(close)
            if not multiline and src[j] == "\n":
                break
            j += 1
        pieces.append(src[piece_start:j])
        line, column = position(start)
        found[slot] = Literal(line, column, src[body_start:j], "".join(pieces), hashes, multiline,
                              interpolated, False)
        return j

    code(0, False)
    return found


def japanese_literals(src):
    return [lit for lit in swift_literals(src) if has_japanese(lit.text)]


# ── Swift escapes ─────────────────────────────────────────────────────────────────────────────

_SIMPLE_UNESCAPES = {"0": "\0", "\\": "\\", "t": "\t", "n": "\n", "r": "\r", '"': '"', "'": "'"}


def unescape(body):
    """The value of an ordinary one-line Swift string literal from its source `body` (the text
    between the quotes). Raises ValueError for an interpolation "\\(…)" (the string is composed from
    parts, C-type, §2.4) and for an escape Swift does not have."""
    out, i, n = [], 0, len(body)
    while i < n:
        ch = body[i]
        if ch != "\\":
            out.append(ch)
            i += 1
            continue
        if i + 1 >= n:
            raise ValueError("a lone backslash at the end")
        nxt = body[i + 1]
        if nxt == "(":
            raise ValueError("an interpolation \\(…)")
        if nxt in _SIMPLE_UNESCAPES:
            out.append(_SIMPLE_UNESCAPES[nxt])
            i += 2
            continue
        if nxt == "u":
            match = re.match(r"\\u\{([0-9A-Fa-f]{1,8})\}", body[i:])
            if match:
                code_point = int(match.group(1), 16)
                if code_point > 0x10FFFF or 0xD800 <= code_point <= 0xDFFF:
                    raise ValueError(f"\\u{{{match.group(1)}}} is not a Unicode scalar")
                out.append(chr(code_point))
                i += len(match.group(0))
                continue
        raise ValueError(f"the escape \\{nxt} is not Swift's")
    return "".join(out)


# ── Reading the 1.1 sources ───────────────────────────────────────────────────────────────────

def _git(repo, args, what):
    try:
        result = subprocess.run(["git", "-C", repo] + args, capture_output=True)
    except OSError as e:
        raise BaselineError(f"git cannot be run ({e.strerror}); use --tree, see --help")
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", "replace").strip()
        message = stderr.splitlines()[0] if stderr else f"exit {result.returncode}"
        hint = (" (a Python under Rosetta cannot run /usr/bin/git: use /usr/bin/python3, or --tree, "
                "see --help)" if "libxcrun" in stderr else "")
        raise BaselineError(f"{what}: git {' '.join(args[:2])} failed: {message}{hint}")
    return result.stdout


def resolve_commit(repo, rev):
    out = _git(repo, ["rev-parse", "--verify", "--quiet", rev + "^{commit}"], f"the commit {rev!r}")
    sha = out.decode("ascii", "replace").strip()
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise BaselineError(f"the commit {rev!r} is not known to {repo}")
    return sha


def _decode(raw, where):
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError as e:
        raise BaselineError(f"{where}: is not UTF-8 ({e.reason} at byte {e.start})")


def sources_of_commit(repo, sha):
    """{repository path: text} of the scanned .swift files of the commit."""
    archive = _git(repo, ["archive", "--format=tar", sha, "--"] + [root.rstrip("/") for root in ROOTS],
                   f"the commit {sha}")
    files = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        for member in tar.getmembers():
            if member.isfile() and scanned(member.name):
                files[member.name] = _decode(tar.extractfile(member).read(), f"{sha[:7]}:{member.name}")
    return files


def sources_of_tree(top):
    """{repository path: text} of the scanned .swift files of a folder laid out as the repository."""
    files = {}
    for root in ROOTS:
        base = os.path.join(top, root)
        for folder, dirs, names in os.walk(base):
            dirs.sort()
            for name in sorted(names):
                path = os.path.relpath(os.path.join(folder, name), top).replace(os.sep, "/")
                if scanned(path):
                    with open(os.path.join(folder, name), "rb") as f:
                        files[path] = _decode(f.read(), path)
    return files


# ── The rows and the file ─────────────────────────────────────────────────────────────────────

def baseline_rows(files):
    """[(short path, line, body)] of the Japanese literals of `files`, by repository path (the app
    first, then the Kit) and source order. Raises BaselineError for a Japanese literal the file
    cannot hold on one line: a raw or multi-line one (1.1 has none outside KitChecks), or one with a
    tab, a carriage return or a newline in its source."""
    rows = []
    for path in sorted(files):
        for lit in japanese_literals(files[path]):
            where = f"{path}:{lit.line}"
            if lit.hashes or lit.multiline or not lit.terminated:
                raise BaselineError(f"{where}: a raw, multi-line or unterminated string with Japanese; "
                                    f"the baseline holds ordinary one-line strings only (extend baseline.py)")
            if any(ch in lit.body for ch in "\t\r\n"):
                raise BaselineError(f"{where}: the string has a tab or a line break in its source")
            rows.append((short_path(path), lit.line, lit.body))
    return rows


TSV_HEADER = """\
# 生成物。直さない。tools/l10n/baseline.py
# The Japanese strings of 1.1.1 (docs/M7B_CONTRACT.md §1.3 J-1; lint L-3: each row is one key's "was"
# or "composedOf", or an exception of ja-exceptions.txt). Sources/TegakiCalendar and TegakiKit/Sources
# without KitChecks, comments excluded. Columns: the file (without Sources/TegakiCalendar/ or
# TegakiKit/Sources/), the line, the string as the Swift source writes it between its quotes.
"""


def tsv_text(sha, rows):
    files = len({row[0] for row in rows})
    lines = [TSV_HEADER, f"# commit: {sha}\n", f"# strings: {len(rows)} in {files} files\n"]
    lines.extend(f"{path}\t{line}\t{body}\n" for path, line, body in rows)
    return "".join(lines)


def read_tsv(path):
    """(commit, rows) of a ja-baseline.tsv; rows are (short path, line, body) in file order."""
    try:
        with open(path, "rb") as f:
            raw = f.read()
    except OSError as e:
        raise BaselineError(f"{path}: cannot be read ({e.strerror}); write it with tools/l10n/baseline.py")
    text = _decode(raw, path)
    commit, declared, rows = None, None, []
    for number, line in enumerate(text.split("\n"), 1):
        if line == "":
            continue
        if line.startswith("#"):
            match = re.fullmatch(r"# commit: ([0-9a-f]{40})", line)
            if match:
                commit = match.group(1)
            match = re.fullmatch(r"# strings: (\d+) in (\d+) files", line)
            if match:
                declared = (int(match.group(1)), int(match.group(2)))
            continue
        fields = line.split("\t")
        if len(fields) != 3 or not re.fullmatch(r"[1-9][0-9]*", fields[1]) or not fields[0].endswith(".swift") \
                or fields[2] == "":
            raise BaselineError(f"{path}:{number}: a row is <file> TAB <line> TAB <string>")
        rows.append((fields[0], int(fields[1]), fields[2]))
    if commit is None or declared is None:
        raise BaselineError(f"{path}: the header has no \"# commit:\" or \"# strings:\" line")
    found = (len(rows), len({row[0] for row in rows}))
    if found != declared:
        raise BaselineError(f"{path}: the header says {declared[0]} strings in {declared[1]} files, "
                            f"the rows are {found[0]} in {found[1]}")
    return commit, rows


def main(argv):
    parser = argparse.ArgumentParser(
        prog="baseline.py",
        description="Writes tools/l10n/ja-baseline.tsv: the Japanese string literals of the <1.1.1> "
                    "commit (docs/M7B_CONTRACT.md §1.3 J-1).")
    parser.add_argument("repo", nargs="?", default=DEFAULT_REPO,
                        help="the repository (default: the one this script is in)")
    parser.add_argument("--commit", default=BASE_COMMIT,
                        help=f"the <1.1.1> commit (default {BASE_COMMIT}); with --tree, its full id")
    parser.add_argument("--tree", help="read the sources from this folder (an extracted git archive "
                                       "of the commit) instead of running git")
    parser.add_argument("--check", action="store_true",
                        help="write nothing; exit 1 when the file is not what the commit gives")
    args = parser.parse_args(argv)
    repo = os.path.abspath(args.repo)
    out_path = os.path.join(repo, TSV)
    try:
        if not os.path.isdir(os.path.join(repo, "tools", "l10n")):
            raise BaselineError(f"{repo} is not the repository (it has no tools/l10n)")
        if args.tree:
            if not re.fullmatch(r"[0-9a-f]{40}", args.commit):
                raise BaselineError("with --tree, --commit is the full 40-digit id of the commit the folder holds")
            sha, files = args.commit, sources_of_tree(os.path.abspath(args.tree))
        else:
            sha = resolve_commit(repo, args.commit)
            files = sources_of_commit(repo, sha)
        if not files:
            raise BaselineError(f"no Swift sources under {' or '.join(ROOTS)} in {args.tree or sha}")
        rows = baseline_rows(files)
    except BaselineError as e:
        print(f"baseline.py: {e}", file=sys.stderr)
        return 1
    text = tsv_text(sha, rows)
    summary = f"{len(rows)} strings in {len({row[0] for row in rows})} files of {sha[:7]}"
    try:
        with open(out_path, "rb") as f:
            same = f.read() == text.encode("utf-8")
    except FileNotFoundError:
        same = False
    if args.check:
        if same:
            print(f"baseline.py: {TSV} is what {sha[:7]} gives ({summary})")
            return 0
        print(f"baseline.py: {TSV} is not what {sha[:7]} gives ({summary}); "
              f"run python3 -I tools/l10n/baseline.py", file=sys.stderr)
        return 1
    if same:
        print(f"baseline.py: {TSV} is up to date ({summary})")
        return 0
    with open(out_path, "wb") as f:
        f.write(text.encode("utf-8"))
    print(f"baseline.py: wrote {TSV} ({summary})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
