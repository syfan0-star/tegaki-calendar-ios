#!/usr/bin/env python3
"""The localization lint of 1.2 (docs/M7B_CONTRACT.md §2.7).

    python3 -I tools/l10n/lint.py [<repo>] [--only L-1,L-3,…]

<repo> defaults to the repository this script is in. Exit status 1 when a check fails (its lines
start with the check's name), 0 when every check passes; warnings do not fail. --only runs some of
the checks.

The checks:
  L-1   No Japanese (kana, kanji, hangul, the full-width signs) in the string literals of
        Sources/TegakiCalendar and TegakiKit/Sources (KitChecks and the generated
        DayKit/KitStrings.generated.swift excluded; comments do not count), but for the exceptions
        of tools/l10n/ja-exceptions.txt (§2.5, §2.6). An exception that matches no string is a
        warning.
  L-2   Every key (a jaOnly key: ja only) has a value in the ten languages, not empty; a value other
        than ja has no kana and, outside zh and ko, no kanji or hangul (ko no kanji), but for the
        texts of its "allowJapanese"; a fixed key holds its fixedValues.
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
  L-5   The values of the sources and the translations have no format but %@ and %1$@ … %9$@ (D5).
  L-6   Every translation is of the current ja (its jaSha1), of a key that exists and is translated.
  L-7   The app passes the language and the holidays to the Kit's words (language:, holidays:, words:),
        as does the Kit's Layout and InkModel where it calls its own titles; the app does not read
        the 1.1 values that are Japanese whatever the screen is.
  L-8   Every key the code uses exists, every key of the sources is used ("// l10n-dynamic: <prefix>"
        counts the keys that start with the prefix, and is what allows a key that is not a literal).
  L-9   docs/store: the lengths of the fields, the forbidden words, the keywords, the URLs on the side
        of LegalLinks.englishPagesPublished, no price in the texts of the other languages.
  L-10  build.py --check: the generated files are what the sources and translations give.
  L-11  No right-to-left language (ar, he, fa, ur) in Sources/TegakiCalendar/Resources.
  L-12  A warning, not a failure: a Latin value whose longest line, at 0.6 em a character, is over the
        key's "maxEm" (PaperFitTests and ToolbarFitTests measure the real width).
  L-13  The app passes weekStart: wherever a week's shape is decided (D15).
  L-14  Persistence/WeekStartChoice.swift is the only file of the app that reads the region's first
        day of the week.
L-7, L-8, L-13 and L-14 read the code with its comments and strings out of the way, a call to its
closing parenthesis. The frozen files of tools/compat10/DATA_1_1.sha256 are not read by them.
"""
import argparse
import bisect
import hashlib
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
CHECKS = ("L-1", "L-2", "L-3", "L-4", "L-5", "L-6", "L-7", "L-8", "L-9", "L-10", "L-11", "L-12", "L-13", "L-14")
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


# ── L-2, L-5, L-6, L-11, L-12 (the tables) ────────────────────────────────────────────────────

_KANA = re.compile("[぀-ヿㇰ-ㇿｦ-ﾝ]")
_KANJI = re.compile("[㐀-䶿一-鿿豈-﫿]")
_HANGUL = re.compile("[ᄀ-ᇿ㄰-㆏가-힯]")


def listed(items, limit=6):
    items = sorted(items)
    return ", ".join(items[:limit]) + (f", … ({len(items)} in all)" if len(items) > limit else "")


def check_l2(repo, sources, translations, result):
    keys, origin, _ = sources
    missing = {language: [] for language in build.LANGUAGES}
    for key in sorted(keys):
        entry, where = keys[key], f"{origin[key]}: {key}"
        values = build.values_of(key, entry, translations)
        wanted = ("ja",) if entry.get("jaOnly", False) else build.LANGUAGES
        for language in wanted:
            if language not in values:
                missing[language].append(key)
        for language, value in values.items():
            if language == "ja":
                continue
            rest = value
            for text in entry.get("allowJapanese", []):
                rest = rest.replace(text, "")
            if _KANA.search(rest):
                result.problem(f"{where}: {language} {quoted(value)} has kana")
            if not language.startswith("zh") and _KANJI.search(rest):
                result.problem(f"{where}: {language} {quoted(value)} has kanji")
            if language != "ko" and _HANGUL.search(rest):
                result.problem(f"{where}: {language} {quoted(value)} has hangul")
        if entry.get("fixed", False):
            for language in build.TRANSLATED:
                if key in translations[language] and translations[language][key] != entry["fixedValues"][language]:
                    result.problem(f"{where}: {language} of the translations is not its fixedValues (a fixed key is "
                                   f"not translated, §2.3)")
        elif entry.get("jaOnly", False):
            for language in build.TRANSLATED:
                if key in translations[language]:
                    result.problem(f"{where}: {language} has a translation, but the key is jaOnly (§2.3)")
    for language in build.LANGUAGES:
        if missing[language]:
            result.problem(f"{language}: {len(missing[language])} keys have no value: {listed(missing[language])}")
    result.summary = f"{len(keys)} keys"


_FORMAT = re.compile(r"%(?:[1-9]\$@|@|[-+#0]*[0-9.*]*(?:hh?|ll?|[qLztj])?[diouxXfFeEgGaAcCsSpn]|[1-9][0-9]*\$[^@\s]?|[1-9][0-9]+\$@)")


def check_l5(repo, sources, translations, result):
    keys, origin, _ = sources
    for key in sorted(keys):
        for language, value in build.values_of(key, keys[key], translations).items():
            for match in _FORMAT.finditer(value):
                if match.group(0) == "%@" or re.fullmatch(r"%[1-9]\$@", match.group(0)):
                    continue
                result.problem(f"{origin[key]}: {key}: {language} {quoted(value)} has the format "
                               f"{match.group(0)!r} (only %@ and %1$@ … %9$@, numbers are formatted first, D5)")
    result.summary = f"{len(keys)} keys"


def ja_sha1(ja):
    return hashlib.sha1(ja.encode("utf-8")).hexdigest()[:10]


def check_l6(repo, sources, result):
    keys, origin, _ = sources
    folder = os.path.join(repo, build.TRANSLATIONS_DIR)
    names = sorted(os.listdir(folder)) if os.path.isdir(folder) else []
    count = 0
    for name in names:
        language = name[:-len(".json")]
        if not name.endswith(".json") or language not in build.TRANSLATED:
            continue
        rel = f"{build.TRANSLATIONS_DIR}/{name}"
        data = build.read_json(os.path.join(folder, name), rel)
        for key in sorted(data["strings"]):
            entry = data["strings"][key]
            count += 1
            if key not in keys:
                result.problem(f"{rel}: {key}: no source has this key")
            elif keys[key].get("fixed", False) or keys[key].get("jaOnly", False):
                continue  # L-2 says what is wrong with it
            elif "jaSha1" not in entry:
                result.problem(f"{rel}: {key}: has no jaSha1 (§2.3)")
            elif entry["jaSha1"] != ja_sha1(keys[key]["ja"]):
                result.problem(f"{rel}: {key}: to be checked: the ja changed after the translation "
                               f"(jaSha1 {entry['jaSha1']}, the ja is now {ja_sha1(keys[key]['ja'])}, §2.3)")
    result.summary = f"{count} translations"


RIGHT_TO_LEFT = ("ar", "he", "fa", "ur")


def check_l11(repo, result):
    folder = os.path.join(repo, build.APP_RESOURCES)
    seen = 0
    def right_to_left(name):
        return re.split(r"[-_]", name)[0].lower() in RIGHT_TO_LEFT
    for name in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
        if name.endswith(".lproj"):
            seen += 1
            if right_to_left(name[:-len(".lproj")]):
                result.problem(f"{build.APP_RESOURCES}/{name}: a right-to-left language is out of scope (O-1)")
        if name.endswith(".xcstrings"):
            seen += 1
            rel = f"{build.APP_RESOURCES}/{name}"
            catalog = build.read_json(os.path.join(folder, name), rel)
            languages = {language for entry in catalog.get("strings", {}).values()
                         for language in entry.get("localizations", {})}
            for language in sorted(languages):
                if right_to_left(language):
                    result.problem(f"{rel}: has {language}, a right-to-left language (out of scope, O-1)")
    result.summary = f"{seen} tables"


def check_l12(repo, sources, translations, result):
    keys, origin, _ = sources
    with_limit = 0
    for key in sorted(keys):
        limit = keys[key].get("maxEm")
        if limit is None:
            continue
        with_limit += 1
        for language, value in build.values_of(key, keys[key], translations).items():
            if baseline.has_japanese(value):
                continue
            for line in value.split("\n"):
                estimate = len(_POSITIONAL.sub("00", line).replace("%@", "00")) * 0.6
                if estimate > limit:
                    result.warning(f"{origin[key]}: {key}: {language} {quoted(line)} is about {estimate:.1f} em, "
                                   f"maxEm is {limit:g} (a rough guess; the tests measure the real width)")
    result.summary = f"{with_limit} keys with maxEm"


# ── L-7, L-8, L-13, L-14 (the code) ───────────────────────────────────────────────────────────

def scan_code(src):
    """Two copies of a Swift source of its length, for matching by position: without the comments,
    and without the comments and the text of the strings (their quotes and the code of their
    interpolations stay), so a pattern cannot match in a comment or a string and parentheses count."""
    n = len(src)
    no_comments, code_only = list(src), list(src)

    def blank(target, start, end):
        for k in range(start, end):
            if target[k] != "\n":
                target[k] = " "

    def skip_comment(i):
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
        else:
            depth, j = 1, i + 2
            while j < n and depth:
                if src.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif src.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
        blank(no_comments, i, j)
        blank(code_only, i, j)
        return j

    def code(i, interpolation):
        depth = 0
        while i < n:
            ch = src[i]
            if ch == "/" and (src.startswith("//", i) or src.startswith("/*", i)):
                i = skip_comment(i)
            elif ch == '"' or (ch == "#" and baseline._RAW_START.match(src, i)):
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
        j = i
        while src[j] == "#":
            j += 1
        hashes = j - i
        multiline = src.startswith('"""', j)
        j += 3 if multiline else 1
        close = ('"""' if multiline else '"') + "#" * hashes
        escape = "\\" + "#" * hashes
        text_start = j
        while j < n:
            if src.startswith(escape, j):
                k = j + len(escape)
                if k < n and src[k] == "(":
                    blank(code_only, text_start, j)
                    j = code(k + 1, True)
                    text_start = j
                else:
                    j = k + 1
                continue
            if src.startswith(close, j):
                blank(code_only, text_start, j)
                return j + len(close)
            if not multiline and src[j] == "\n":
                break
            j += 1
        blank(code_only, text_start, j)
        return j

    code(0, False)
    return "".join(no_comments), "".join(code_only)


class Source:
    def __init__(self, path, text):
        self.path, self.text = path, text
        self.no_comments, self.code = scan_code(text)
        self.newlines = [i for i, ch in enumerate(text) if ch == "\n"]

    def line(self, index):
        return bisect.bisect_left(self.newlines, index) + 1

    def call_args(self, open_paren):
        """The code between the parenthesis at open_paren and its partner."""
        depth, i, n = 0, open_paren, len(self.code)
        while i < n:
            ch = self.code[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    return self.code[open_paren + 1:i]
            i += 1
        return self.code[open_paren + 1:]

    def calls(self, pattern):
        """(line, what matched, the arguments) of every call that `pattern` finds; a pattern ends at or
        before the "(" (the next "(" is the call's). A definition (func x() …) is not a call."""
        for match in pattern.finditer(self.code):
            before = self.code[max(0, match.start() - 12):match.start()]
            if re.search(r"\bfunc\s+$", before):
                continue
            paren = self.code.find("(", match.end() - 1 if match.group(0).endswith("(") else match.end())
            if paren < 0:
                continue
            yield self.line(match.start()), match.group(0), self.call_args(paren)


def frozen_paths(repo):
    """The files of tools/compat10/DATA_1_1.sha256: they cannot change, so they are not read here."""
    try:
        with open(os.path.join(repo, "tools/compat10/DATA_1_1.sha256"), encoding="utf-8") as f:
            return {line.split()[1] for line in f if line.strip()}
    except OSError:
        return set()


def read_code(repo, result):
    """The sources of L-1 as (app, Kit Layout and InkModel, Kit): frozen files and tests left out."""
    files, problems = current_sources(repo)
    for problem in problems:
        result.problem(problem)
    frozen = frozen_paths(repo)
    sources = {path: Source(path, text) for path, text in files.items() if path not in frozen}
    app = [s for path, s in sorted(sources.items()) if path.startswith(baseline.APP_ROOT)]
    kit = [s for path, s in sorted(sources.items()) if path.startswith(baseline.KIT_ROOT)]
    layout = [s for s in kit if s.path.startswith((baseline.KIT_ROOT + "Layout/", baseline.KIT_ROOT + "InkModel/"))]
    return app, layout, kit


_LANGUAGE_ARGUMENT = re.compile(r"\b\w*[Ll]anguage\w*\b|\.(?:ja|en|zhHans|zhHant|ko|fr|de|es|it|ptBR)\b")
_HOLIDAYS = re.compile(r"\bholidays\s*:")
_WORDS = re.compile(r"\bwords\s*:")
_WEEK_START = re.compile(r"\bweekStart\s*:")

# What must carry the language in the app (§2.7). PlanText.savingsMonths and PlanText.perMonth give
# numbers, DateText.time is the same in every language (D7).
L7_LANGUAGE = re.compile(
    r"\bPageNavigation\.title\(|\bcompactTitle\(|\bPlanText\.(?!savingsMonths\b|perMonth\b)\w+\(|\bStrokeBudget\.pageLabel\("
    r"|\bcountText\(|\bAppExport\.pdfFileName\(|\bjsonFileName\(|\bkindLabel\(|\bLegalLinks\.(?:terms|privacy|support|appleEULATitle)\("
    r"|\.title\(|\bDateText\.(?!time\b)\w+\(|\bEventDateText\.\w+\(")
L7_HOLIDAYS = re.compile(r"\bPageNavigation\.title\(|\bAppExport\.pdfFileName\(|\bAllDayBandLayout\.empty\(|\bAllDayBandEngine\.\w+\(")
L7_LAYOUT_INPUT = re.compile(r"\b(?:Month|Week|Day|Year)LayoutInput\(")
L7_KIT_HOLIDAYS = re.compile(r"\bAllDayBandEngine\.(?:week|day)\(|\bAllDayBandLayout\.empty\(|\bPageNavigation\.title\(")
L7_KIT_LANGUAGE = re.compile(r"\bPageNavigation\.(?:title|compactTitle)\(")
L7_NEVER = (
    (re.compile(r"\bJapaneseHolidays\b"), "JapaneseHolidays (the holidays come through HolidayCalendar, §2.5)"),
    (re.compile(r"\bPageNavigation\.weekdayLetters\b"), "PageNavigation.weekdayLetters (Japanese whatever the screen is; DateText.weekdays)"),
    (re.compile(r"\.(?:yearlyBadge|readOnlyBadge|cancelPath|paymentPath)\b(?!\s*\()"), "the 1.1 value of PlanText, Japanese whatever the screen is (pass language:)"),
    (re.compile(r"\bLegalLinks\.(?:terms|privacy|support|appleEULATitle)\b(?!\s*\()"), "the 1.1 value of LegalLinks, Japanese whatever the screen is (pass the language)"),
    (re.compile(r"\.map\(\s*StrokeBudget\.pageLabel\b"), ".map(StrokeBudget.pageLabel), which cannot pass the language (write { StrokeBudget.pageLabel($0, language: L.language) })"),
)
_JA_LOCALE = re.compile(r'\bLocale\(\s*identifier:\s*"ja_JP"\s*\)')


def check_l7(repo, result):
    app, layout, _ = read_code(repo, result)
    calls = 0
    for source in app:
        for line, name, args in source.calls(L7_LANGUAGE):
            calls += 1
            if not _LANGUAGE_ARGUMENT.search(args):
                result.problem(f"{source.path}:{line}: {name}…) has no language: (§2.7)")
        for line, name, args in source.calls(L7_HOLIDAYS):
            calls += 1
            if not _HOLIDAYS.search(args):
                result.problem(f"{source.path}:{line}: {name}…) has no holidays: (§2.7; without it Japan's holidays show)")
        for line, name, args in source.calls(L7_LAYOUT_INPUT):
            calls += 1
            for what, pattern in (("holidays:", _HOLIDAYS), ("words:", _WORDS)):
                if not pattern.search(args):
                    result.problem(f"{source.path}:{line}: {name}…) has no {what} (§2.7)")
        for pattern, what in L7_NEVER:
            for match in pattern.finditer(source.code):
                result.problem(f"{source.path}:{source.line(match.start())}: {what}")
        for match in _JA_LOCALE.finditer(source.no_comments):
            result.problem(f"{source.path}:{source.line(match.start())}: Locale(identifier: \"ja_JP\") (§2.7)")
    for source in layout:
        for line, name, args in source.calls(L7_KIT_HOLIDAYS):
            calls += 1
            if not _HOLIDAYS.search(args):
                result.problem(f"{source.path}:{line}: {name}…) has no holidays: (§2.7)")
        for line, name, args in source.calls(L7_KIT_LANGUAGE):
            calls += 1
            if not _LANGUAGE_ARGUMENT.search(args):
                result.problem(f"{source.path}:{line}: {name}…) has no language: (§2.7)")
    result.summary = f"{calls} calls in {len(app)} files of the app and {len(layout)} of the Kit"


_KEY_CALL = re.compile(r"\b(?P<owner>L|KitStrings)\.(?P<function>text|format|plural|value)\(")
_DYNAMIC = re.compile(r"//\s*l10n-dynamic:\s*(\S+)")
_DEFINING_FILES = (baseline.APP_ROOT + "Support/L10n.swift",)


def check_l8(repo, sources, result):
    keys, origin, _ = sources
    app, _, kit = read_code(repo, result)
    used, prefixes, found = set(), set(), 0
    for source in app + kit:
        annotations = {}  # line → prefix
        for match in _DYNAMIC.finditer(source.text):
            annotations[source.line(match.start())] = match.group(1)
            prefixes.add(match.group(1))
        if source.path in _DEFINING_FILES:
            continue
        for match in _KEY_CALL.finditer(source.code):
            found += 1
            line = source.line(match.start())
            literal = re.match(r'\s*"([^"\n]*)"\s*(\+)?', source.no_comments[match.end():])
            if literal and "\\(" not in literal.group(1) and not literal.group(2):
                key = literal.group(1)
                names = [key + ".one", key + ".other"] if match.group("function") == "plural" else [key]
                for name in names:
                    if name in keys:
                        used.add(name)
                    else:
                        result.problem(f"{source.path}:{line}: the key {name!r} is in no source file")
                continue
            near = [annotations[k] for k in range(line - 3, line + 1) if k in annotations]
            if not near:
                result.problem(f"{source.path}:{line}: the key of {match.group('owner')}.{match.group('function')} "
                               f"is not a literal and has no \"// l10n-dynamic: <prefix>\" on the lines above (§2.5)")
    for prefix in sorted(prefixes):
        if not any(key.startswith(prefix) for key in keys):
            result.problem(f"l10n-dynamic: no key starts with {prefix!r}")
    unused = [key for key in sorted(keys)
              if keys[key].get("target") != "infoplist" and key not in used
              and not any(key.startswith(prefix) for prefix in prefixes)]
    for key in unused:
        result.problem(f"{origin[key]}: {key}: no code uses this key")
    result.summary = f"{found} uses of a key, {len(keys)} keys"


L13_CALLS = re.compile(
    r"\bPageNavigation\.title\(|\bcompactTitle\(|\bdayRange\(|\bpageId\(\s*(?!\.(?:day|month|year)\b)"
    r"|\bMonthLayoutInput\(|\bWeekLayoutInput\(|\bAllDayBandEngine\.week\b|\bMonthLayout\.grid\("
    r"|\bAppExport\.pdfFileName\(|\bPaperWords\.monthHeaderWeekdays\(|\bdemoPage\(\s*kind\b")


def check_l13(repo, result):
    app, _, _ = read_code(repo, result)
    calls = 0
    for source in app:
        for match in L13_CALLS.finditer(source.code):
            before = source.code[max(0, match.start() - 12):match.start()]
            if re.search(r"\bfunc\s+$", before):
                continue
            calls += 1
            paren = source.code.find("(", match.start())
            if not _WEEK_START.search(source.call_args(paren)):
                result.problem(f"{source.path}:{source.line(match.start())}: {match.group(0)}…) has no weekStart: "
                               f"(D15: the Kit's default is Monday, whatever the setting)")
    result.summary = f"{calls} calls in {len(app)} files"


_FIRST_DAY = re.compile(r"\b(?:firstDayOfWeek|firstWeekday)\b")
L14_OWNER = baseline.APP_ROOT + "Persistence/WeekStartChoice.swift"


def check_l14(repo, result):
    app, _, _ = read_code(repo, result)
    for source in app:
        if source.path == L14_OWNER:
            continue
        for match in _FIRST_DAY.finditer(source.code):
            result.problem(f"{source.path}:{source.line(match.start())}: {match.group(0)}: only "
                           f"Persistence/WeekStartChoice.swift reads the region's first day of the week (D6, §10.3)")
    result.summary = f"{len(app)} files"


# ── L-9 ───────────────────────────────────────────────────────────────────────────────────────

STORE = "docs/store"
FIELD_LIMITS = {"subtitle.txt": 30, "promo.txt": 170, "description.txt": 4000, "whatsnew.txt": 4000}
REVIEW_NOTE_BYTES = 4000
KEYWORD_BYTES = 100
NAME_LENGTHS = (2, 30)
SUBSCRIPTION_NAME_LENGTHS = (2, 30)
SUBSCRIPTION_NOTE_LENGTH = 45
STORE_BASE = "https://syfan0-star.github.io/tegaki-calendar/app/"
# Apple's marks in every language's writing, and "free" (1.0 was rejected under 5.2.5).
STORE_MARKS = ("apple pencil", "pencil", "ipad", "iphone", "icloud", "apple", "アップル", "ペンシル", "苹果", "蘋果",
               "애플", "아이패드", "아이폰", "펜슬", "아이클라우드")
STORE_FREE = re.compile(r"無料|免费|免費|무료|\b(?:free|gratuit|kostenlos|gratis|grátis)\b", re.IGNORECASE)
STORE_PRICE = re.compile(r"[¥￥€$£₩]|\b(?:JPY|EUR|USD|GBP|CNY|KRW|TWD|HKD|BRL|MXN|CAD|AUD|CHF)\b")
_NAME_SEPARATOR = re.compile(r"[\s:：,，.。·・/()（）–—-]+")
_CJK_WORD = re.compile("[぀-ヿ㐀-䶿一-鿿豈-﫿가-힯]")


def store_text(path):
    """A field's text without the one line break at its end; None when the file is not there."""
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return None
    return text[:-1] if text.endswith("\n") else text


def english_pages_published(repo):
    path = "TegakiKit/Sources/Access/LegalLinks.swift"
    try:
        with open(os.path.join(repo, path), encoding="utf-8") as f:
            match = re.search(r"\benglishPagesPublished\s*=\s*(true|false)\b", f.read())
    except OSError:
        match = None
    return None if not match else match.group(1) == "true"


def check_l9(repo, result):
    folder = os.path.join(repo, STORE)
    rel_table = f"{STORE}/locales.json"
    try:
        table = build.read_json(os.path.join(folder, "locales.json"), rel_table)
    except build.BuildError as e:
        result.problem(str(e))
        return
    published = english_pages_published(repo)
    if published is None:
        result.problem("TegakiKit/Sources/Access/LegalLinks.swift: englishPagesPublished cannot be read")
        published = False
    pages = {name: STORE_BASE + ("en/" if published else "") + name for name in ("terms.html", "support.html", "privacy.html")}
    other_side = {name: STORE_BASE + ("" if published else "en/") + name for name in pages}
    seen = 0

    def banned(where, text):
        low = text.casefold()
        for mark in STORE_MARKS:
            if mark.casefold() in low:
                result.problem(f"{where}: {quoted(text)} has {mark!r} (Apple's marks stay out of the name, subtitle and keywords; 5.2.5)")
        match = STORE_FREE.search(text)
        if match:
            result.problem(f"{where}: {quoted(text)} has {match.group(0)!r}")
        match = STORE_PRICE.search(text)
        if match:
            result.problem(f"{where}: {quoted(text)} has the price sign {match.group(0)!r}")

    for locale in table.get("locales", []):
        code = locale["code"]
        rel = f"{STORE}/{code}"
        if "copyOf" in locale or not os.path.isdir(os.path.join(repo, rel)):
            continue
        seen += 1
        fields = locale.get("fields", table.get("fields", []))
        is_primary = code == table.get("primary")
        for field in fields:
            where = f"{rel}/{field}"
            text = store_text(os.path.join(repo, where))
            if text is None:
                result.problem(f"{where}: is not there")
                continue
            if field == "name.txt":
                names = [line for line in text.split("\n") if line.strip()]
                if not names:
                    result.problem(f"{where}: has no name")
                for name in names:
                    if not NAME_LENGTHS[0] <= len(name) <= NAME_LENGTHS[1]:
                        result.problem(f"{where}: {quoted(name)} is {len(name)} characters (2–30)")
                    banned(where, name)
            elif field == "keywords.txt":
                if len(text.encode("utf-8")) > KEYWORD_BYTES:
                    result.problem(f"{where}: is {len(text.encode('utf-8'))} bytes (at most {KEYWORD_BYTES})")
                banned(where, text)
                name_text = store_text(os.path.join(repo, rel, "name.txt")) or ""
                name_words = {w.casefold() for w in _NAME_SEPARATOR.split(name_text)
                              if len(w) >= (2 if _CJK_WORD.search(w) else 3)}
                for word in text.split(","):
                    word = word.strip()
                    shortest = 2 if _CJK_WORD.search(word) else 3
                    if len(word) < shortest:
                        result.problem(f"{where}: the word {quoted(word)} is shorter than {shortest} characters")
                    for name_word in sorted(name_words):
                        if name_word in word.casefold():
                            result.problem(f"{where}: the word {quoted(word)} has {name_word!r} of the app's name")
            elif field == "urls.txt":
                lines = text.split("\n")
                expected = [pages["support.html"], pages["privacy.html"]]
                if lines != expected:
                    result.problem(f"{where}: is {quoted(' / '.join(lines), 200)}, englishPagesPublished = "
                                   f"{str(published).lower()} wants {' / '.join(expected)} (0-38)")
            else:
                limit = FIELD_LIMITS.get(field)
                if limit is not None and len(text) > limit:
                    result.problem(f"{where}: is {len(text)} characters (at most {limit})")
                if field == "subtitle.txt":
                    banned(where, text)
                if field == "description.txt":
                    if pages["terms.html"] not in text:
                        result.problem(f"{where}: has no {pages['terms.html']} (0-38)")
                    if other_side["terms.html"] in text:
                        result.problem(f"{where}: has {other_side['terms.html']}, englishPagesPublished = {str(published).lower()} (0-38)")
                if field in ("description.txt", "promo.txt", "whatsnew.txt") and not is_primary:
                    match = STORE_PRICE.search(text)
                    if match:
                        result.problem(f"{where}: has the price sign {match.group(0)!r} (no price outside ja, §6.6)")
        if is_primary:
            continue
        where = f"{STORE}/subscriptions/{code}.json"
        path = os.path.join(repo, where)
        if not os.path.exists(path):
            continue
        try:
            data = build.read_json(path, where)
        except build.BuildError as e:
            result.problem(str(e))
            continue
        texts = [("group.displayName", data.get("group", {}).get("displayName", ""), SUBSCRIPTION_NAME_LENGTHS)]
        for product, values in sorted(data.get("products", {}).items()):
            texts.append((f"{product}.displayName", values.get("displayName", ""), SUBSCRIPTION_NAME_LENGTHS))
            texts.append((f"{product}.description", values.get("description", ""), (1, SUBSCRIPTION_NOTE_LENGTH)))
        for name, text, (shortest, longest) in texts:
            if not shortest <= len(text) <= longest:
                result.problem(f"{where}: {name} {quoted(text)} is {len(text)} characters ({shortest}–{longest})")
            match = STORE_PRICE.search(text)
            if match:
                result.problem(f"{where}: {name} has the price sign {match.group(0)!r} (§6.6)")
    note = store_text(os.path.join(folder, "review-note.txt"))
    if note is None:
        result.problem(f"{STORE}/review-note.txt: is not there")
    elif len(note.encode("utf-8")) > REVIEW_NOTE_BYTES:
        result.problem(f"{STORE}/review-note.txt: is {len(note.encode('utf-8'))} bytes (at most {REVIEW_NOTE_BYTES})")
    result.summary = f"{seen} locales, the URLs on the {'English' if published else 'Japanese'} side"


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
    with_sources = ("L-2", "L-3", "L-4", "L-5", "L-6", "L-8", "L-12")
    if any(name in wanted for name in with_sources):
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
        if name in with_sources and source_error:
            result.problem(f"the sources cannot be read: {source_error}")
        elif name == "L-1":
            check_l1(repo, exceptions, result)
        elif name == "L-3":
            check_l3(repo, exceptions, sources, result)
        elif name == "L-4":
            check_l4(repo, sources, translations, result)
        elif name == "L-2":
            check_l2(repo, sources, translations, result)
        elif name == "L-5":
            check_l5(repo, sources, translations, result)
        elif name == "L-6":
            try:
                check_l6(repo, sources, result)
            except build.BuildError as e:
                result.problem(str(e))
        elif name == "L-7":
            check_l7(repo, result)
        elif name == "L-8":
            check_l8(repo, sources, result)
        elif name == "L-9":
            check_l9(repo, result)
        elif name == "L-10":
            check_l10(repo, result)
        elif name == "L-11":
            try:
                check_l11(repo, result)
            except build.BuildError as e:
                result.problem(str(e))
        elif name == "L-12":
            check_l12(repo, sources, translations, result)
        elif name == "L-13":
            check_l13(repo, result)
        elif name == "L-14":
            check_l14(repo, result)
        results.append(result)
        for message in result.problems:
            print(f"{name}: {message}")
        for message in result.warnings:
            print(f"{name}: warning: {message}")
        state = "ok" if not result.problems else f"FAILED ({len(result.problems)})"
        print(f"{name}: {state}{': ' + result.summary if result.summary else ''}")
    failed = [r.name for r in results if r.problems]
    print(f"lint.py: {'FAILED (' + ', '.join(failed) + ')' if failed else 'ok'} — ran {', '.join(r.name for r in results)} (§2.7)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
