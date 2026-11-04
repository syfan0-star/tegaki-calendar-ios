#!/usr/bin/env python3
"""The string tables of 1.2, made from their sources (docs/M7B_CONTRACT.md §2.3; D3, D4, D5).

    python3 -I tools/l10n/build.py [<repo>]

<repo> defaults to the repository this script is in. Reads

    tools/l10n/source/kit-<owner>.json       the Kit's keys with their ja text and notes, one file
                                             per owner (kit-K.json, kit-H.json)
    tools/l10n/translations/<language>.json  the nine other languages (en zh-Hans zh-Hant ko fr de
                                             es it pt-BR), written by X

and writes

    TegakiKit/Sources/DayKit/KitStrings.generated.swift
        `enum KitStrings` (§0): the keys whose target is "kit" as one [String: String] table per
        language, picked with a switch over `UILanguage`, and text / format / plural on top.

The same files give the same bytes (keys in code point order, no dates or machine paths, and the
escapes of the Swift literals come from a fixed list, not from Python's Unicode tables, so every
Python writes the same), and a file whose text is already right is not written again. A missing
source or translations folder, or a source file without keys, is not an error: the tables are then
empty, and the generated file still compiles (it needs only `UILanguage` and `PluralCategory` of
DayKit/UILanguage.swift). Anything malformed stops the build with a message and exit status 1
before anything is written.

What goes into the tables:
  - a plain key: ja from the source; each other language from its translation file when that has
    the key (at run time a language without it falls back to en, then to the key: KitStrings.text);
  - `fixed: true`: `fixedValues`, in all ten languages (a translation of the key is not used);
  - `jaOnly: true`: the ja table only (a translation of the key is not used). It is not listed in
    `KitStrings.keys`, which holds the keys that must have all ten languages (L-2 asks ten
    languages of every key but the jaOnly ones; KitChecks walks `keys` for the same check).
Translations of keys that no Kit source has (the app's keys, old keys) are not used here.

Every *.json of the source folder is named app-<owner>.json or kit-<owner>.json, and every *.json
of the translations folder <language>.json for one of the nine languages; any other name (an iCloud
copy such as "kit-K 2.json") stops the build. Names that start with "." are skipped. The app-*.json
files are not read yet.

This is the first part of the generator (S0 in "統合の順番" at the end of docs/M7B_CONTRACT.md):
the Kit output only. The app's outputs (Localizable.xcstrings, InfoPlist.xcstrings and
`--format strings`), `--check` (lint L-10) and the lint come next (S1); `build_outputs` returns
every output as text, so `--check` can compare without writing.
"""
import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_REPO = os.path.normpath(os.path.join(HERE, "..", ".."))

SOURCE_DIR = "tools/l10n/source"
TRANSLATIONS_DIR = "tools/l10n/translations"
KIT_OUTPUT = "TegakiKit/Sources/DayKit/KitStrings.generated.swift"
UI_LANGUAGE_FILE = "TegakiKit/Sources/DayKit/UILanguage.swift"  # K's; the output needs its types

# The ten languages (O-1) in the order of UILanguage's cases (§0), with the names of the cases.
LANGUAGES = ["ja", "en", "zh-Hans", "zh-Hant", "ko", "fr", "de", "es", "it", "pt-BR"]
SWIFT_CASE = {
    "ja": "ja", "en": "en", "zh-Hans": "zhHans", "zh-Hant": "zhHant", "ko": "ko",
    "fr": "fr", "de": "de", "es": "es", "it": "it", "pt-BR": "ptBR",
}
TRANSLATED = LANGUAGES[1:]

KEY_RE = re.compile(r"^[a-z][a-zA-Z0-9]*(\.[a-z0-9][a-zA-Z0-9]*)+$")  # §2.4
SOURCE_FILE_RE = re.compile(r"^(app|kit)-([A-Z][A-Za-z0-9]*)\.json$")  # app-S.json, kit-K.json, …


class BuildError(Exception):
    """A missing or malformed piece of the sources or the translations; the message says where."""


def _is_str(value):
    return isinstance(value, str)


def _is_bool(value):
    return isinstance(value, bool)


def _is_str_list(value):
    return isinstance(value, list) and all(isinstance(item, str) for item in value)


def _is_positive_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value > 0


def _is_positive_int(value):
    return isinstance(value, int) and not isinstance(value, bool) and value >= 1


# The fields a key of a source file may have (§2.3), with what each must be. Any other field stops
# the build, so that a misspelt "jaOnly" or "fixed" cannot quietly turn into a plain key.
KEY_FIELDS = {
    "target": (_is_str, "a string"),
    "ja": (_is_str, "a string"),
    "comment": (_is_str, "a string"),
    "where": (_is_str_list, "a list of strings"),
    "was": (_is_str_list, "a list of strings"),
    "composedOf": (_is_str_list, "a list of strings"),
    "args": (_is_str_list, "a list of strings"),
    "glossary": (_is_str_list, "a list of strings"),
    "allowJapanese": (_is_str_list, "a list of strings"),
    "maxEm": (_is_positive_number, "a positive number"),
    "lines": (_is_positive_int, "a whole number from 1"),
    "fixed": (_is_bool, "true or false"),
    "fixedValues": (lambda value: isinstance(value, dict), "an object"),
    "jaOnly": (_is_bool, "true or false"),
}
TRANSLATION_FIELDS = {"text", "jaSha1"}


def read_json(path, rel):
    """The JSON value of a file: UTF-8 without a byte order mark, no name twice in one object (the
    json module would keep the last one without a word), no NaN or Infinity."""
    def pairs(items):
        obj = {}
        for name, value in items:
            if name in obj:
                raise BuildError(f"{rel}: the name {name!r} appears twice in one object")
            obj[name] = value
        return obj

    def constant(name):
        raise BuildError(f"{rel}: {name} is not JSON")

    try:
        with open(path, "rb") as f:
            raw = f.read()
    except OSError as e:
        raise BuildError(f"{rel}: cannot be read ({e.strerror})")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        raise BuildError(f"{rel}: is not UTF-8 ({e.reason} at byte {e.start})")
    if text.startswith("﻿"):
        raise BuildError(f"{rel}: starts with a byte order mark (save it as UTF-8 without one)")
    try:
        return json.loads(text, object_pairs_hook=pairs, parse_constant=constant)
    except json.JSONDecodeError as e:
        raise BuildError(f"{rel}:{e.lineno}:{e.colno}: not JSON ({e.msg})")


def check_text(value, where):
    """A text that goes into a table: a non-empty string that UTF-8 can hold (a lone \\ud800–\\udfff
    escape cannot be written to a Swift file)."""
    if not isinstance(value, str) or value == "":
        raise BuildError(f"{where}: must be a non-empty string")
    try:
        value.encode("utf-8")
    except UnicodeEncodeError:
        raise BuildError(f"{where}: has a lone surrogate (a \\ud800–\\udfff escape without its pair)")


def check_kit_key(key, entry, where):
    """One key of a kit-*.json file (§2.3, §2.4)."""
    if not KEY_RE.match(key):
        raise BuildError(f"{where}: a key looks like kit.plan.monthly ({KEY_RE.pattern}, §2.4)")
    if not key.startswith("kit."):
        raise BuildError(f"{where}: a key of the Kit starts with \"kit.\" (§2.4)")
    if not isinstance(entry, dict):
        raise BuildError(f"{where}: must be an object")
    for field in sorted(entry):
        if field not in KEY_FIELDS:
            raise BuildError(f"{where}: unknown field {field!r} (the fields are "
                             f"{', '.join(sorted(KEY_FIELDS))}; §2.3)")
        ok, what = KEY_FIELDS[field]
        if not ok(entry[field]):
            raise BuildError(f"{where}: \"{field}\" must be {what}")
    if entry.get("target") != "kit":
        raise BuildError(f"{where}: \"target\" must be \"kit\" in a kit-*.json file")
    if "ja" not in entry:
        raise BuildError(f"{where}: has no \"ja\"")
    check_text(entry["ja"], f"{where}: \"ja\"")
    fixed = entry.get("fixed", False)
    if fixed and entry.get("jaOnly", False):
        raise BuildError(f"{where}: \"fixed\" and \"jaOnly\" cannot both be true")
    if fixed:
        values = entry.get("fixedValues")
        if values is None or set(values) != set(LANGUAGES):
            raise BuildError(f"{where}: a fixed key has \"fixedValues\" for exactly the ten "
                             f"languages ({' '.join(LANGUAGES)})")
        for language in LANGUAGES:
            check_text(values[language], f"{where}: fixedValues.{language}")
        if values["ja"] != entry["ja"]:
            raise BuildError(f"{where}: fixedValues.ja is not the same as \"ja\"")
    elif "fixedValues" in entry:
        raise BuildError(f"{where}: \"fixedValues\" belongs to a key with \"fixed\": true")


def load_kit_sources(repo):
    """The keys of tools/l10n/source/kit-*.json: ({key: entry}, [(file, number of keys)])."""
    folder = os.path.join(repo, SOURCE_DIR)
    keys, files, origin = {}, [], {}
    if not os.path.isdir(folder):
        return keys, files
    for name in sorted(os.listdir(folder)):
        if name.startswith(".") or not name.endswith(".json"):
            continue  # .DS_Store, an editor's lock file, notes
        rel = f"{SOURCE_DIR}/{name}"
        match = SOURCE_FILE_RE.match(name)
        if not match:
            raise BuildError(f"{rel}: a source file is app-<owner>.json or kit-<owner>.json "
                             f"(remove a copy such as \"kit-K 2.json\")")
        if match.group(1) != "kit":
            continue  # the app's keys (app-*.json) are for the app's outputs (S1)
        data = read_json(os.path.join(folder, name), rel)
        if not isinstance(data, dict) or set(data) != {"owner", "keys"}:
            raise BuildError(f"{rel}: must be an object with just \"owner\" and \"keys\"")
        if data["owner"] != match.group(2):
            raise BuildError(f"{rel}: \"owner\" is {data['owner']!r}, the file name says "
                             f"{match.group(2)!r}")
        if not isinstance(data["keys"], dict):
            raise BuildError(f"{rel}: \"keys\" must be an object")
        for key in sorted(data["keys"]):
            where = f"{rel}: {key}"
            if key in origin:
                raise BuildError(f"{where}: the key is also in {origin[key]} (a key has one file)")
            check_kit_key(key, data["keys"][key], where)
            keys[key] = data["keys"][key]
            origin[key] = rel
        files.append((rel, len(data["keys"])))
    return keys, files


def load_translations(repo):
    """{language: {key: text}} from tools/l10n/translations/<language>.json, every key of the files
    (the app's too); a language without a file has none."""
    folder = os.path.join(repo, TRANSLATIONS_DIR)
    texts = {language: {} for language in TRANSLATED}
    if not os.path.isdir(folder):
        return texts
    for name in sorted(os.listdir(folder)):
        if name.startswith(".") or not name.endswith(".json"):
            continue
        rel = f"{TRANSLATIONS_DIR}/{name}"
        language = name[:-len(".json")]
        if language not in texts:
            raise BuildError(f"{rel}: the translation files are "
                             f"{', '.join(lang + '.json' for lang in TRANSLATED)} "
                             f"(ja is in the sources; remove a copy such as \"de 2.json\")")
        data = read_json(os.path.join(folder, name), rel)
        if not isinstance(data, dict) or set(data) != {"language", "strings"}:
            raise BuildError(f"{rel}: must be an object with just \"language\" and \"strings\"")
        if data["language"] != language:
            raise BuildError(f"{rel}: \"language\" is {data['language']!r}, the file name says "
                             f"{language!r}")
        if not isinstance(data["strings"], dict):
            raise BuildError(f"{rel}: \"strings\" must be an object")
        for key in sorted(data["strings"]):
            entry = data["strings"][key]
            where = f"{rel}: {key}"
            if not isinstance(entry, dict) or "text" not in entry or not set(entry) <= TRANSLATION_FIELDS:
                raise BuildError(f"{where}: must be an object with \"text\" and \"jaSha1\" (§2.3)")
            if "jaSha1" in entry and not isinstance(entry["jaSha1"], str):
                raise BuildError(f"{where}: \"jaSha1\" must be a string")
            check_text(entry["text"], f"{where}: \"text\"")
            texts[language][key] = entry["text"]
    return texts


# Code points that the Swift literals write as \u{…}, so that no invisible character sits in the
# generated source and every unusual space or separate accent can be seen: the controls, the spaces
# other than U+0020, the zero-width, joining, direction and other format characters, the combining
# marks (a decomposed "é" or "が" shows as e\u{301} or か\u{3099}), variation selectors, tags, private
# use and noncharacters. A fixed list, not unicodedata: Python 3.9 and a newer Python have different
# Unicode tables, and the output must not depend on which Python runs the generator.
ESCAPED_RANGES = [
    (0x0000, 0x001F), (0x007F, 0x00A0), (0x00AD, 0x00AD), (0x0300, 0x036F), (0x061C, 0x061C),
    (0x115F, 0x1160), (0x1680, 0x1680), (0x17B4, 0x17B5), (0x180B, 0x180F), (0x1AB0, 0x1AFF),
    (0x1DC0, 0x1DFF), (0x2000, 0x200F), (0x2028, 0x202F), (0x205F, 0x206F), (0x20D0, 0x20FF),
    (0x3000, 0x3000), (0x3099, 0x309A), (0x3164, 0x3164), (0xE000, 0xF8FF), (0xFDD0, 0xFDEF),
    (0xFE00, 0xFE0F), (0xFE20, 0xFE2F), (0xFEFF, 0xFEFF), (0xFFA0, 0xFFA0), (0xFFF0, 0xFFFB),
    (0xE0000, 0xE0FFF), (0xF0000, 0x10FFFF),
]
SIMPLE_ESCAPES = {"\\": "\\\\", "\"": "\\\"", "\n": "\\n", "\r": "\\r", "\t": "\\t"}


def _escaped(code):
    if code & 0xFFFE == 0xFFFE:  # U+FFFE, U+FFFF, U+1FFFE, … (noncharacters)
        return True
    return any(low <= code <= high for low, high in ESCAPED_RANGES)


def swift_string(text):
    """`text` as a Swift string literal."""
    out = []
    for ch in text:
        if ch in SIMPLE_ESCAPES:
            out.append(SIMPLE_ESCAPES[ch])
        elif _escaped(ord(ch)):
            out.append("\\u{%X}" % ord(ch))
        else:
            out.append(ch)
    return "\"" + "".join(out) + "\""


KIT_HEADER = """\
// 生成物。直さない。tools/l10n/build.py
//
// Written by `python3 -I tools/l10n/build.py <repo>` (docs/M7B_CONTRACT.md §2.3) from the Kit's
// sources and tools/l10n/translations/<language>.json. To change a text, change those files and
// run the generator again: this file is written over.
"""

# The part of KitStrings that does not depend on the sources (§0; D4, D5).
KIT_FUNCTIONS = """\
/// The strings of TegakiKit, one table per language (D4: no `.strings`, `.xcstrings` or
/// `Bundle.module`, so the language is always the one passed in, the same on a Mac, in CI and in
/// the app). The Kit's functions take `language: UILanguage` (default `.ja`, the 1.1 text) and
/// read their words here.
public enum KitStrings {
    /// The keys that are to have a text in all ten languages (L-2), sorted: every key of the Kit's
    /// sources but the `jaOnly` ones (the ja-only formats such as `kit.date.ja.*`, which only the ja
    /// table has). Until a language is translated, `value` is nil for its keys and `text` falls back.
    public static let keys: [String] = @KEYS@

    /// The text of `key` in `language`; when that language's table does not have the key, the en
    /// text, and when en does not have it either, the key itself.
    public static func text(_ key: String, _ language: UILanguage) -> String {
        table(language)[key] ?? en[key] ?? key
    }

    /// `text(key, language)` with its placeholders filled from `args`, without `String(format:)`:
    /// `%@` takes the next argument (the first `%@` takes `args[0]`, the second `args[1]`, …; a
    /// `%n$@` does not move this count) and `%n$@` takes `args[n - 1]` (n from 1 to 99). Nothing
    /// else is a placeholder: `%%`, `%d` and any other `%` stay as they are (numbers are formatted
    /// before they are passed, D5). A placeholder whose argument is missing stays as it is.
    public static func format(_ key: String, _ language: UILanguage, _ args: [String]) -> String {
        fill(text(key, language), args)
    }

    /// `format(key + ".one", …)` or `format(key + ".other", …)`: the form that
    /// `language.pluralCategory(count)` picks (D5, 0-8). `count` only picks the form; a text that
    /// shows the number gets it in `args`, already formatted.
    public static func plural(_ key: String, _ language: UILanguage, count: Int, _ args: [String]) -> String {
        format(key + "." + language.pluralCategory(count).rawValue, language, args)
    }

    /// The text of `key` in the table of `language` itself, without the fallback of `text`; nil when
    /// that table does not have the key. For the checks that every key has all ten languages
    /// (KitChecks, KitStringsTests).
    public static func value(_ key: String, _ language: UILanguage) -> String? {
        table(language)[key]
    }

    private static func table(_ language: UILanguage) -> [String: String] {
        switch language {
@CASES@
        }
    }

    private static func fill(_ template: String, _ args: [String]) -> String {
        let percent = UInt8(ascii: "%"), at = UInt8(ascii: "@"), dollar = UInt8(ascii: "$")
        let zero = UInt8(ascii: "0"), nine = UInt8(ascii: "9")
        guard template.utf8.contains(percent) else { return template }
        let bytes = Array(template.utf8)
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count + 32)
        var copied = 0  // bytes[..<copied] are in `result` already
        var next = 0    // the argument of the next "%@"
        var i = 0
        while i < bytes.count {
            guard bytes[i] == percent else {
                i += 1
                continue
            }
            var end = i + 1  // ends on the "@" of the placeholder that starts at i, if there is one
            var argument = -1
            if end < bytes.count, bytes[end] == at {
                argument = next
                next += 1
            } else {
                var n = 0
                while end < bytes.count, end - i <= 2, bytes[end] >= zero, bytes[end] <= nine, n > 0 || bytes[end] != zero {
                    n = n * 10 + Int(bytes[end] - zero)
                    end += 1
                }
                if n > 0, end + 1 < bytes.count, bytes[end] == dollar, bytes[end + 1] == at {
                    argument = n - 1
                    end += 1
                }
            }
            guard argument >= 0 else {
                i += 1
                continue
            }
            if argument < args.count {
                result.append(contentsOf: bytes[copied..<i])
                result.append(contentsOf: args[argument].utf8)
                copied = end + 1
            }
            i = end + 1
        }
        if copied == 0 { return template }
        result.append(contentsOf: bytes[copied...])
        return String(decoding: result, as: UTF8.self)
    }

    // MARK: - The tables
"""


def _count(n, word):
    return f"{n} {word}" if n == 1 else f"{n} {word}s"


def _swift_array(items, indent):
    if not items:
        return "[]"
    pad = " " * indent
    return "[\n" + "".join(f"{pad}    {swift_string(item)},\n" for item in items) + pad + "]"


def _swift_dictionary(pairs, indent):
    if not pairs:
        return "[:]"
    pad = " " * indent
    return ("[\n"
            + "".join(f"{pad}    {swift_string(key)}: {swift_string(value)},\n" for key, value in pairs)
            + pad + "]")


def kit_swift(keys, files, translations):
    """The text of KitStrings.generated.swift and a one-line summary of what is in it."""
    tables = {language: {} for language in LANGUAGES}
    listed, ja_only = [], 0
    for key in sorted(keys):
        entry = keys[key]
        if entry.get("jaOnly", False):
            tables["ja"][key] = entry["ja"]
            ja_only += 1
            continue
        listed.append(key)
        if entry.get("fixed", False):
            for language in LANGUAGES:
                tables[language][key] = entry["fixedValues"][language]
            continue
        tables["ja"][key] = entry["ja"]
        for language in TRANSLATED:
            if key in translations[language]:
                tables[language][key] = translations[language][key]

    parts = [KIT_HEADER]
    if files:
        parts.append("//\n// Sources: " + ", ".join(f"{rel} ({_count(count, 'key')})" for rel, count in files)
                     + ".\n")
    else:
        parts.append(f"//\n// Sources: none yet ({SOURCE_DIR}/kit-*.json).\n")
    parts.append("\n")
    cases = "\n".join(f"        case .{SWIFT_CASE[language]}: return {SWIFT_CASE[language]}"
                      for language in LANGUAGES)
    parts.append(KIT_FUNCTIONS.replace("@KEYS@", _swift_array(listed, 4)).replace("@CASES@", cases))
    for language in LANGUAGES:
        pairs = sorted(tables[language].items())
        parts.append(f"\n    // {language}: {_count(len(pairs), 'text')}\n")
        parts.append(f"    private static let {SWIFT_CASE[language]}: [String: String] = "
                     f"{_swift_dictionary(pairs, 4)}\n")
    parts.append("}\n")
    summary = (f"{_count(len(listed), 'key')} and {_count(ja_only, 'jaOnly key')} from "
               f"{_count(len(files), 'source file')}; texts: "
               + ", ".join(f"{language} {len(tables[language])}" for language in LANGUAGES))
    return "".join(parts), summary


def build_outputs(repo):
    """{path relative to the repository: (text, summary)} of every output; nothing is written."""
    keys, files = load_kit_sources(repo)
    translations = load_translations(repo)
    return {KIT_OUTPUT: kit_swift(keys, files, translations)}


def write_outputs(repo, outputs):
    """Writes the outputs whose text changed; prints one line per output."""
    for rel in sorted(outputs):
        text, summary = outputs[rel]
        path = os.path.join(repo, rel)
        data = text.encode("utf-8")
        try:
            with open(path, "rb") as f:
                same = f.read() == data
        except FileNotFoundError:
            same = False
        if same:
            print(f"build.py: {rel} is up to date ({summary})")
            continue
        with open(path, "wb") as f:
            f.write(data)
        print(f"build.py: wrote {rel} ({summary})")


def main(argv):
    parser = argparse.ArgumentParser(
        prog="build.py",
        description="Writes TegakiKit/Sources/DayKit/KitStrings.generated.swift from "
                    "tools/l10n/source/kit-*.json and tools/l10n/translations/*.json "
                    "(docs/M7B_CONTRACT.md §2.3).")
    parser.add_argument("repo", nargs="?", default=DEFAULT_REPO,
                        help="the repository (default: the one this script is in)")
    args = parser.parse_args(argv)
    repo = os.path.abspath(args.repo)
    try:
        if not os.path.isdir(os.path.join(repo, os.path.dirname(KIT_OUTPUT))):
            raise BuildError(f"{repo} is not the repository (it has no {os.path.dirname(KIT_OUTPUT)})")
        outputs = build_outputs(repo)
    except BuildError as e:
        print(f"build.py: {e}", file=sys.stderr)
        return 1
    write_outputs(repo, outputs)
    if not os.path.isfile(os.path.join(repo, UI_LANGUAGE_FILE)):
        print(f"build.py: note: {UI_LANGUAGE_FILE} is not there yet; {KIT_OUTPUT} uses its "
              f"UILanguage and PluralCategory (§0, K) and does not compile without them",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
