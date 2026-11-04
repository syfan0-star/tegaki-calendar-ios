#!/usr/bin/env python3
"""The localization lint of 1.2 (docs/M7B_CONTRACT.md §2.7).

    python3 -I tools/l10n/lint.py [<repo>] [--only L-1,L-3,…]

<repo> defaults to the repository this script is in. Exit status 1 when a check fails (its lines
start with the check's name), 0 when every check passes; warnings do not fail. --only runs some of
the checks.

The checks of this version (S, first part):
  L-1   No Japanese (kana, kanji, hangul, the full-width signs) in the string literals of
        Sources/TegakiCalendar and TegakiKit/Sources (KitChecks and the generated
        DayKit/KitStrings.generated.swift excluded; comments do not count), but for the exceptions
        of tools/l10n/ja-exceptions.txt (§2.5, §2.6). An exception that matches no string is a
        warning.
  L-3   J-1: every row of tools/l10n/ja-baseline.tsv (the Japanese strings of 1.1, baseline.py) is
        a key's "was" or "composedOf", or an exception. A row is the "was" of one key at most (the
        ".one" and ".other" of a plural are one key), and the ja of that key is the 1.1 string; a
        string with an interpolation \\(…) goes into "composedOf" instead (C-type, §2.4), and its
        ja is checked by the owner's tests.
        A reference is "<file>:<line>", the file as ja-baseline.tsv writes it (Views/A.swift,
        Access/PlanText.swift; with Sources/TegakiCalendar/ or TegakiKit/Sources/ in front is read
        the same). When the line has more than one Japanese string, a "was" picks the one that is
        its ja; otherwise write "<file>:<line>#<n>", the n-th string of the line from the left.
  L-4   The placeholders (%@, %1$@ … %99$@) are the same in every language of a key, and in the ja
        they are the ones "args" counts; ".one" and ".other" come in pairs in one file, and in ja,
        ko, zh-Hans and zh-Hant the two are the same text; a key with "lines" has at most
        lines − 1 line breaks in every language.
  L-10  build.py --check: the generated files are what the sources and translations give.
The other checks of §2.7 (L-2, L-5–L-9, L-11, L-12) come with the later parts of S.
"""
import argparse
import importlib.util
import os
import re
import sys

sys.dont_write_bytecode = True  # importing build.py and baseline.py must not leave __pycache__ in the repository

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_REPO = os.path.normpath(os.path.join(HERE, "..", ".."))


def _load(name, filename):
    # Under -I the script's folder is not on sys.path, so the two neighbours are loaded by path.
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


build = _load("l10n_build", "build.py")
baseline = _load("l10n_baseline", "baseline.py")

EXCEPTIONS = "tools/l10n/ja-exceptions.txt"
WHOLE_FILE_ONLY = "Holidays/JapaneseHolidays.swift"  # the one file whose "*" the contract allows
CHECKS = ("L-1", "L-3", "L-4", "L-10")
LATER = "L-2, L-5, L-6, L-7, L-8, L-9, L-11, L-12"
REF_RE = re.compile(r"(?P<path>[^:#\s][^:#]*\.swift):(?P<line>[1-9][0-9]*)(?:#(?P<n>[1-9][0-9]*))?")
SAME_PLURAL_LANGUAGES = ("ja", "ko", "zh-Hans", "zh-Hant")  # no .one of their own (0-8)


def quoted(text, limit=90):
    """A text for one line of the report: a line break or a tab shows as \\n or \\t."""
    text = text.replace("\n", "\\n").replace("\t", "\\t")
    text = text if len(text) <= limit else text[:limit - 1] + "…"
    return "\"" + text + "\""


class Result:
    def __init__(self, name):
        self.name, self.problems, self.warnings, self.summary = name, [], [], ""

    def problem(self, message):
        self.problems.append(message)

    def warning(self, message):
        self.warnings.append(message)


# ── ja-exceptions.txt ─────────────────────────────────────────────────────────────────────────

class Exceptions:
    """The exceptions: {short path: {string: line of the file}} ("*" is the whole file), and the
    problems of the file's form."""

    def __init__(self, repo):
        self.by_path, self.problems = {}, []
        path = os.path.join(repo, EXCEPTIONS)
        try:
            with open(path, "rb") as f:
                raw = f.read()
        except OSError as e:
            self.problems.append(f"{EXCEPTIONS}: cannot be read ({e.strerror})")
            return
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as e:
            self.problems.append(f"{EXCEPTIONS}: is not UTF-8 ({e.reason} at byte {e.start})")
            return
        for number, line in enumerate(text.split("\n"), 1):
            where = f"{EXCEPTIONS}:{number}"
            if line.strip() == "" or line.startswith("#"):
                continue
            if "\r" in line or "\t" in line:
                self.problems.append(f"{where}: has a carriage return or a tab")
                continue
            if line.count("|") < 2:
                self.problems.append(f"{where}: an exception is <file>|<string>|<reason>")
                continue
            file_part, rest = line.split("|", 1)
            string, reason = rest.rsplit("|", 1)
            short = baseline.short_path(file_part)
            if not short.endswith(".swift") or short.startswith("/") or ".." in short.split("/"):
                self.problems.append(f"{where}: {file_part!r} is not a Swift file of the app or the Kit "
                                     f"(Views/A.swift, Access/B.swift)")
                continue
            if string == "":
                self.problems.append(f"{where}: the string is empty")
                continue
            if string == "*" and short != WHOLE_FILE_ONLY:
                self.problems.append(f"{where}: \"*\" (the whole file) is for {WHOLE_FILE_ONLY} only (§2.5)")
                continue
            if reason.strip() == "":
                self.problems.append(f"{where}: has no reason")
                continue
            strings = self.by_path.setdefault(short, {})
            if string in strings:
                self.problems.append(f"{where}: the same exception as line {strings[string]}")
                continue
            strings[string] = number

    def covers(self, short, body):
        strings = self.by_path.get(short, {})
        return "*" in strings or body in strings


# ── L-1 ───────────────────────────────────────────────────────────────────────────────────────

def current_sources(repo):
    """{repository path: text} of the Swift files L-1 looks at, and [problem] for unreadable ones."""
    files, problems = {}, []
    for root in baseline.ROOTS:
        top = os.path.join(repo, root)
        for folder, dirs, names in os.walk(top):
            dirs.sort()
            for name in sorted(names):
                path = os.path.relpath(os.path.join(folder, name), repo).replace(os.sep, "/")
                if not baseline.scanned(path):
                    continue
                try:
                    with open(os.path.join(folder, name), "rb") as f:
                        files[path] = f.read().decode("utf-8")
                except (OSError, UnicodeDecodeError) as e:
                    problems.append(f"{path}: cannot be read as UTF-8 ({e})")
    return files, problems


def check_l1(repo, exceptions, result):
    files, problems = current_sources(repo)
    for problem in problems:
        result.problem(problem)
    used, per_file = set(), {}
    for path in sorted(files):
        short = baseline.short_path(path)
        strings = exceptions.by_path.get(short, {})
        for lit in baseline.japanese_literals(files[path]):
            if "*" in strings:
                used.add((short, "*"))
                continue
            if lit.body in strings:
                used.add((short, lit.body))
                continue
            result.problem(f"{path}:{lit.line}:{lit.column}: {quoted(lit.body)}")
            per_file[short] = per_file.get(short, 0) + 1
    for short in sorted(exceptions.by_path):
        for string, number in sorted(exceptions.by_path[short].items(), key=lambda item: item[1]):
            if (short, string) not in used:
                result.warning(f"{EXCEPTIONS}:{number}: {short}|{string} matches no string of the "
                               f"current source (not written yet, or no longer needed?)")
    count = sum(per_file.values())
    if count:
        biggest = sorted(per_file.items(), key=lambda item: (-item[1], item[0]))
        result.summary = (f"{count} Japanese strings outside the tables in {len(per_file)} files ("
                          + ", ".join(f"{short} {n}" for short, n in biggest[:12])
                          + (", …" if len(biggest) > 12 else "")
                          + "): move each into a key (L.text / KitStrings, §2.5, §2.6); only the "
                          + "strings §2.5–§2.6 list are exceptions (tools/l10n/ja-exceptions.txt)")
    else:
        result.summary = f"{len(files)} Swift files, no Japanese outside the tables and the exceptions"


# ── L-3 ───────────────────────────────────────────────────────────────────────────────────────

def logical_key(key):
    """A plural pair is one key: "a.b.one" and "a.b.other" → "a.b.(one|other)"."""
    for form in (".one", ".other"):
        if key.endswith(form):
            return key[:-len(form)] + ".(one|other)"
    return key


def check_l3(repo, exceptions, sources, result):
    try:
        commit, rows = baseline.read_tsv(os.path.join(repo, baseline.TSV))
    except baseline.BaselineError as e:
        result.problem(str(e))
        return
    keys, origin, _ = sources
    by_line, files_in_tsv = {}, set()
    for index, (short, line, body) in enumerate(rows):
        by_line.setdefault((short, line), []).append(index)
        files_in_tsv.add(short)
    was_of, composed_of = {}, {}  # row index → {logical key}

    def describe(index):
        short, line, body = rows[index]
        return f"{short}:{line} {quoted(body)}"

    for key in sorted(keys):
        entry, where = keys[key], f"{origin[key]}: {key}"
        picked = {}
        for field in ("was", "composedOf"):
            for ref in entry.get(field, []):
                match = REF_RE.fullmatch(ref)
                if not match:
                    result.problem(f"{where}: {field} {ref!r} is not <file>:<line> or <file>:<line>#<n> "
                                   f"(the file as ja-baseline.tsv writes it)")
                    continue
                short, line = baseline.short_path(match.group("path")), int(match.group("line"))
                candidates = by_line.get((short, line))
                if not candidates:
                    if short not in files_in_tsv:
                        result.problem(f"{where}: {field} {ref!r}: {short} has no Japanese string in 1.1 "
                                       f"(ja-baseline.tsv)")
                    else:
                        result.problem(f"{where}: {field} {ref!r}: no Japanese string of 1.1 on that line "
                                       f"(ja-baseline.tsv: the line of the opening quote in {commit[:7]})")
                    continue
                if match.group("n"):
                    n = int(match.group("n"))
                    if n > len(candidates):
                        result.problem(f"{where}: {field} {ref!r}: the line has {len(candidates)} Japanese "
                                       f"string{'s' if len(candidates) > 1 else ''}")
                        continue
                    index = candidates[n - 1]
                elif len(candidates) == 1:
                    index = candidates[0]
                else:
                    same = []
                    if field == "was":
                        for i in candidates:
                            try:
                                if baseline.unescape(rows[i][2]) == entry["ja"]:
                                    same.append(i)
                            except ValueError:
                                pass
                    if len(same) == 1:
                        index = same[0]
                    else:
                        listing = ", ".join(f"#{k} {quoted(rows[i][2], 30)}" for k, i in enumerate(candidates, 1))
                        result.problem(f"{where}: {field} {ref!r}: the line has {len(candidates)} Japanese "
                                       f"strings ({listing}); write {short}:{line}#<n>")
                        continue
                if index in picked:
                    twice = (f"twice in {field}" if picked[index] == field
                             else "in both was and composedOf")
                    result.problem(f"{where}: {describe(index)} is listed {twice}")
                    continue
                picked[index] = field
                if field == "composedOf":
                    composed_of.setdefault(index, set()).add(logical_key(key))
                    continue
                was_of.setdefault(index, set()).add(logical_key(key))
                try:
                    value = baseline.unescape(rows[index][2])
                except ValueError as e:
                    if "interpolation" in str(e):
                        result.problem(f"{where}: was {describe(index)} is composed of parts (\\(…)); "
                                       f"list it in composedOf (C-type, §2.4)")
                    else:
                        result.problem(f"{where}: was {describe(index)} cannot be read ({e})")
                    continue
                if value != entry["ja"]:
                    result.problem(f"{where}: the ja {quoted(entry['ja'])} is not the 1.1 string "
                                   f"{quoted(value)} of {rows[index][0]}:{rows[index][1]} (J-1: the ja is the "
                                   f"1.1 text, not one character changed)")

    by_key, by_exception, missing, missing_files = 0, 0, [], {}
    for index, (short, line, body) in enumerate(rows):
        claims = was_of.get(index, set())
        if len(claims) > 1:
            result.problem(f"{describe(index)} is the \"was\" of {len(claims)} keys ({', '.join(sorted(claims))}); "
                           f"a 1.1 string is the \"was\" of one key, another key that uses it lists it in composedOf")
        if claims or composed_of.get(index):
            by_key += 1
        elif exceptions.covers(short, body):
            by_exception += 1
        else:
            missing.append(index)
            missing_files[short] = missing_files.get(short, 0) + 1
    for index in missing:
        result.problem(f"{describe(index)}: no key has it in \"was\" or \"composedOf\", and it is not an exception")
    summary = (f"{len(rows)} strings of {commit[:7]} in ja-baseline.tsv: {by_key} in a key, "
               f"{by_exception} exceptions")
    if missing:
        biggest = sorted(missing_files.items(), key=lambda item: (-item[1], item[0]))
        summary += (f", {len(missing)} in neither ("
                    + ", ".join(f"{short} {n}" for short, n in biggest[:12])
                    + (", …" if len(biggest) > 12 else "") + ")")
    result.summary = summary


# ── L-4 ───────────────────────────────────────────────────────────────────────────────────────

_POSITIONAL = re.compile(r"%([1-9][0-9]?)\$@")


def placeholders(text):
    """The arguments a text takes, in order, by the rule of KitStrings.fill and L.format: "%@" takes
    the next one (1, 2, …; a "%n$@" does not move the count), "%n$@" takes n (1–99)."""
    taken, sequence, i = [], 0, 0
    while i < len(text):
        if text[i] != "%":
            i += 1
            continue
        if text.startswith("%@", i):
            sequence += 1
            taken.append(sequence)
            i += 2
            continue
        match = _POSITIONAL.match(text, i)
        if match:
            taken.append(int(match.group(1)))
            i = match.end()
            continue
        i += 1
    return taken


def shown(numbers):
    return "none" if not numbers else " ".join(f"%{n}" for n in numbers)


def check_l4(repo, sources, translations, result):
    keys, origin, _ = sources
    for key in sorted(keys):
        entry, where = keys[key], f"{origin[key]}: {key}"
        values = build.values_of(key, entry, translations)
        ja = sorted(placeholders(values["ja"]))
        if "args" in entry and sorted(set(ja)) != list(range(1, len(entry["args"]) + 1)):
            result.problem(f"{where}: the ja takes the arguments {shown(sorted(set(ja)))}, \"args\" names "
                           f"{len(entry['args'])}")
        for language in build.LANGUAGES[1:]:
            if language in values and sorted(placeholders(values[language])) != ja:
                result.problem(f"{where}: {language} takes the arguments "
                               f"{shown(sorted(placeholders(values[language])))}, the ja {shown(ja)}")
        if "lines" in entry:
            for language in build.LANGUAGES:
                if language in values and values[language].count("\n") > entry["lines"] - 1:
                    result.problem(f"{where}: {language} has {values[language].count(chr(10)) + 1} lines, "
                                   f"\"lines\" allows {entry['lines']} (§2.3)")
    pairs = 0
    for key in sorted(keys):
        for form, other in ((".one", ".other"), (".other", ".one")):
            if not key.endswith(form):
                continue
            sibling = key[:-len(form)] + other
            if sibling not in keys:
                result.problem(f"{origin[key]}: {key}: has no {sibling} (a plural is a pair, D5)")
            elif origin[sibling] != origin[key]:
                result.problem(f"{origin[key]}: {key}: its pair {sibling} is in {origin[sibling]} (one file)")
            elif form == ".one":
                pairs += 1
                one = build.values_of(key, keys[key], translations)
                rest = build.values_of(sibling, keys[sibling], translations)
                for language in SAME_PLURAL_LANGUAGES:
                    if language in one and language in rest and one[language] != rest[language]:
                        result.problem(f"{origin[key]}: {key}: {language} {quoted(one[language])} is not "
                                       f"{sibling} {quoted(rest[language])} ({language} has no plural forms, 0-8)")
    with_lines = sum(1 for entry in keys.values() if "lines" in entry)
    result.summary = f"{len(keys)} keys ({pairs} plural pairs, {with_lines} with \"lines\")"


# ── L-10 ──────────────────────────────────────────────────────────────────────────────────────

def check_l10(repo, result):
    try:
        problems = build.check_outputs(repo)
    except build.BuildError as e:
        result.problem(f"the sources cannot be built: {e}")
        return
    for problem in problems:
        result.problem(problem)
    result.summary = (f"run python3 -I tools/l10n/build.py" if problems
                      else f"the generated files are what the sources give ({build.present_format(repo)})")


# ── main ──────────────────────────────────────────────────────────────────────────────────────

def main(argv):
    parser = argparse.ArgumentParser(
        prog="lint.py", description="The localization lint of 1.2 (docs/M7B_CONTRACT.md §2.7): "
                                    + ", ".join(CHECKS) + ".")
    parser.add_argument("repo", nargs="?", default=DEFAULT_REPO,
                        help="the repository (default: the one this script is in)")
    parser.add_argument("--only", help="a comma-separated list of the checks to run (" + ",".join(CHECKS) + ")")
    args = parser.parse_args(argv)
    repo = os.path.abspath(args.repo)
    wanted = list(CHECKS)
    if args.only:
        wanted = [name.strip().upper() for name in args.only.split(",") if name.strip()]
        unknown = [name for name in wanted if name not in CHECKS]
        if unknown or not wanted:
            print(f"lint.py: --only takes {', '.join(CHECKS)} (not {', '.join(unknown) or 'nothing'})",
                  file=sys.stderr)
            return 2
    if not os.path.isdir(os.path.join(repo, "tools", "l10n")) or not os.path.isdir(os.path.join(repo, build.APP_DIR)):
        print(f"lint.py: {repo} is not the repository", file=sys.stderr)
        return 2

    exceptions = Exceptions(repo) if ("L-1" in wanted or "L-3" in wanted) else None
    sources = translations = None
    source_error = None
    if "L-3" in wanted or "L-4" in wanted:
        try:
            sources = build.load_sources(repo)
            translations = build.load_translations(repo)
        except build.BuildError as e:
            source_error = str(e)

    results = []
    for name in CHECKS:
        if name not in wanted:
            continue
        result = Result(name)
        if name in ("L-1", "L-3") and exceptions.problems and not any(r.name in ("L-1", "L-3") for r in results):
            for problem in exceptions.problems:
                result.problem(problem)
        if name in ("L-3", "L-4") and source_error:
            result.problem(f"the sources cannot be read: {source_error}")
        elif name == "L-1":
            check_l1(repo, exceptions, result)
        elif name == "L-3":
            check_l3(repo, exceptions, sources, result)
        elif name == "L-4":
            check_l4(repo, sources, translations, result)
        elif name == "L-10":
            check_l10(repo, result)
        results.append(result)
        for message in result.problems:
            print(f"{name}: {message}")
        for message in result.warnings:
            print(f"{name}: warning: {message}")
        state = "ok" if not result.problems else f"FAILED ({len(result.problems)})"
        print(f"{name}: {state}{': ' + result.summary if result.summary else ''}")
    failed = [r.name for r in results if r.problems]
    print(f"lint.py: {'FAILED (' + ', '.join(failed) + ')' if failed else 'ok'} — ran {', '.join(r.name for r in results)}; "
          f"not in this lint yet: {LATER} (§2.7)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
