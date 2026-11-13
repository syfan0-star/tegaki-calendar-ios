#!/usr/bin/env python3
"""The string tables of 1.2, made from their sources (docs/M7B_CONTRACT.md §2.3; D3, D4, D5).

    python3 -I tools/l10n/build.py [<repo>] [--check] [--format xcstrings|strings]

<repo> defaults to the repository this script is in. Reads

    tools/l10n/source/kit-<owner>.json       the Kit's keys with their ja text and notes, one file
                                             per owner (kit-K.json, kit-H.json)
    tools/l10n/source/app-<owner>.json       the app's keys (app-S.json, app-U.json, app-P.json):
                                             target "app" (Localizable) or "infoplist" (InfoPlist;
                                             the key is the Info.plist key, CFBundleDisplayName)
    tools/l10n/translations/<language>.json  the nine other languages (en zh-Hans zh-Hant ko fr de
                                             es it pt-BR), written by X

and writes

    TegakiKit/Sources/DayKit/KitStrings.generated.swift
        `enum KitStrings` (§0): the keys whose target is "kit" as one [String: String] table per
        language, picked with a switch over `UILanguage`, and text / format / plural on top.
    Sources/TegakiCalendar/Resources/Localizable.xcstrings, InfoPlist.xcstrings
        the String Catalogs of the app (sourceLanguage "en"; every key "extractionState": "manual",
        each language that has a text as a "translated" stringUnit, the key's comment).
    or, with --format strings (the fallback of 0-4, the lead's call),
    Sources/TegakiCalendar/Resources/<language>.lproj/Localizable.strings, InfoPlist.strings
        the same texts as .strings files for the ten languages; the catalogs are removed.
        Without --format the format the repository has is kept (the catalogs when it has neither),
        and --format xcstrings switches back (the .strings files of the ten .lproj are removed).

--check writes nothing: the exit status is 1, with one line for each file, when an output is not
what the sources give (or a file of the other format is left). Lint L-10 runs the same check.

The same files give the same bytes (keys in code point order, no dates or machine paths, and the
escapes of the Swift literals come from a fixed list, not from Python's Unicode tables, so every
Python writes the same), and a file whose text is already right is not written again. A missing
source or translations folder, or a source file without keys, is not an error: the tables are then
empty, and the generated Swift file still compiles (it needs only `UILanguage` and `PluralCategory`
of DayKit/UILanguage.swift). Anything malformed stops the build with a message and exit status 1
before anything is written.

What goes into the tables:
  - a plain key: ja from the source; each other language from its translation file when that has
    the key (at run time a language without it falls back to en, then to the key: KitStrings.text
    and the app's L.text);
  - `fixed: true`: `fixedValues`, in all ten languages (a translation of the key is not used);
  - `jaOnly: true` (Kit keys, and since 1.3 the app's "prototype.*" keys): the ja table only (a
    translation of the key is not used). A Kit key is then not listed in `KitStrings.keys`, which holds
    the keys that must have all ten languages (L-2 asks ten languages of every key but the jaOnly ones;
    KitChecks walks `keys` for the same check). The app's are the words of the prototype build of
    docs/M7C_CONTRACT.md §4.6 (D12, §8.1: ja only, not translated); only that build shows them. 1.3 also
    lets the eight new keys of §8.1 (N-1 … N-8, APP_JA_ONLY_UNTIL_TRANSLATED, by name) be jaOnly until X's
    nine languages come (§8.2); X takes "jaOnly" off each with its translations.
  - `allowJapanese` and `lines` do not change a table: they are checked here for their form (the
    contract allows only two texts in allowJapanese, and each must be in the ja) and by the lint
    for the languages (L-2, L-4).
Translations of keys that no source has (old keys) are not used.

Every *.json of the source folder is named app-<owner>.json or kit-<owner>.json, and every *.json
of the translations folder <language>.json for one of the nine languages; any other name (an iCloud
copy such as "kit-K 2.json") stops the build. Names that start with "." are skipped. A key is in
one source file only, across the app and the Kit.

`build_outputs` and `check_outputs` are also used by lint.py (L-10); `load_sources` and
`load_translations` by its L-3 and L-4.
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
APP_DIR = "Sources/TegakiCalendar"
APP_RESOURCES = APP_DIR + "/Resources"

# The ten languages (O-1) in the order of UILanguage's cases (§0), with the names of the cases.
LANGUAGES = ["ja", "en", "zh-Hans", "zh-Hant", "ko", "fr", "de", "es", "it", "pt-BR"]
SWIFT_CASE = {
    "ja": "ja", "en": "en", "zh-Hans": "zhHans", "zh-Hant": "zhHant", "ko": "ko",
    "fr": "fr", "de": "de", "es": "es", "it": "it", "pt-BR": "ptBR",
}
TRANSLATED = LANGUAGES[1:]

# The app's two tables: the target of a key → the name of its table (Localizable.xcstrings, …).
APP_TABLES = {"app": "Localizable", "infoplist": "InfoPlist"}
FORMATS = ("xcstrings", "strings")

KEY_RE = re.compile(r"^[a-z][a-zA-Z0-9]*(\.[a-z0-9][a-zA-Z0-9]*)+$")  # §2.4
INFOPLIST_KEY_RE = re.compile(r"^[A-Z][A-Za-z0-9]*$")  # an Info.plist key: CFBundleDisplayName, …
SOURCE_FILE_RE = re.compile(r"^(app|kit)-([A-Z][A-Za-z0-9]*)\.json$")  # app-S.json, kit-K.json, …
# 1.3 (docs/M7C_CONTRACT.md D12, §8.1): the app's keys that may be jaOnly — the words of the prototype
# build (SPAN_PROTOTYPE), which only the person sees, in Japanese; every other app key has all ten languages.
APP_JA_ONLY_PREFIX = "prototype."
# 1.3 (docs/M7C_CONTRACT.md §8.1, §8.2): the new words of the screen (N-1 … N-8, U's keys) are written before X
# translates them (the keys are fixed first). Until then each may be jaOnly, so L-2 and LocalizationBundleTests
# stay green; X takes "jaOnly" off each with its nine languages (L-2 then asks all ten again). These names only:
# every other app key keeps all ten languages. Until then no build but the prototype can be submitted:
# testflight.yml's step "Every word of the app in ten languages (not the prototype)" fails it. This set is empty
# before build.py goes back to 43fe366's bytes at S6 (docs/M7C.md, lead decision 1).
APP_JA_ONLY_UNTIL_TRANSLATED = frozenset((
    "settings.page.header", "settings.page.span", "settings.page.span.footer",
    "span.guide.day.oneFinger", "span.guide.day.twoFingers", "span.guide.week.oneFinger",
    "span.guide.week.twoFingers", "span.stageTwo.notice",
))
# The only texts a value other than ja may keep in kana and kanji (§2.3, L-2).
ALLOWED_JAPANESE = ("手書きを書き出す（iPad アプリ用）", "てがきカレンダー")


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


def _noncharacter(code):
    return 0xFDD0 <= code <= 0xFDEF or code & 0xFFFE == 0xFFFE


def check_text(value, where):
    """A text that goes into a table: a non-empty string that UTF-8 can hold (a lone \\ud800–\\udfff
    escape cannot be written to a Swift file) and without a noncharacter (U+FDD0–U+FDEF, U+FFFE,
    U+FFFF, U+1FFFE, …: not text; swiftc rejects "\\u{FDD0}" as an invalid scalar, so the Kit's table
    would not compile)."""
    if not isinstance(value, str) or value == "":
        raise BuildError(f"{where}: must be a non-empty string")
    try:
        value.encode("utf-8")
    except UnicodeEncodeError:
        raise BuildError(f"{where}: has a lone surrogate (a \\ud800–\\udfff escape without its pair)")
    for ch in value:
        if _noncharacter(ord(ch)):
            raise BuildError(f"{where}: has the noncharacter U+{ord(ch):04X}, which is not text")


def check_key_name(key, kind, where):
    """The name of a key: §2.4 for the Kit and the app's Localizable, the Info.plist key for
    InfoPlist. `kind` is "kit" or "app" (the file); the target is checked after the fields."""
    if kind == "kit":
        if not KEY_RE.match(key):
            raise BuildError(f"{where}: a key looks like kit.plan.monthly ({KEY_RE.pattern}, §2.4)")
        if not key.startswith("kit."):
            raise BuildError(f"{where}: a key of the Kit starts with \"kit.\" (§2.4)")


def check_key(key, entry, kind, where):
    """One key of a kit-*.json (kind "kit") or app-*.json (kind "app") file (§2.3, §2.4)."""
    check_key_name(key, kind, where)
    if not isinstance(entry, dict):
        raise BuildError(f"{where}: must be an object")
    for field in sorted(entry):
        if field not in KEY_FIELDS:
            raise BuildError(f"{where}: unknown field {field!r} (the fields are "
                             f"{', '.join(sorted(KEY_FIELDS))}; §2.3)")
        ok, what = KEY_FIELDS[field]
        if not ok(entry[field]):
            raise BuildError(f"{where}: \"{field}\" must be {what}")
    target = entry.get("target")
    if kind == "kit":
        if target != "kit":
            raise BuildError(f"{where}: \"target\" must be \"kit\" in a kit-*.json file")
    else:
        if target not in APP_TABLES:
            raise BuildError(f"{where}: \"target\" must be \"app\" or \"infoplist\" in an app-*.json "
                             f"file (a Kit key, target \"kit\", goes into a kit-*.json file)")
        if target == "infoplist":
            if not INFOPLIST_KEY_RE.match(key):
                raise BuildError(f"{where}: an \"infoplist\" key is the Info.plist key itself "
                                 f"(CFBundleDisplayName, NSCalendarsFullAccessUsageDescription)")
        else:
            if not KEY_RE.match(key):
                raise BuildError(f"{where}: a key looks like settings.input.eraserAutoReturn.title "
                                 f"({KEY_RE.pattern}, §2.4)")
            if key.startswith("kit."):
                raise BuildError(f"{where}: a key that starts with \"kit.\" is the Kit's "
                                 f"(target \"kit\", in a kit-*.json file)")
        if entry.get("jaOnly", False) and not (target == "app" and (key.startswith(APP_JA_ONLY_PREFIX)
                                                                    or key in APP_JA_ONLY_UNTIL_TRANSLATED)):
            raise BuildError(f"{where}: \"jaOnly\" is for the Kit's ja-only formats (kit.date.ja.*, "
                             f"§2.3), the prototype's {APP_JA_ONLY_PREFIX}* keys (docs/M7C_CONTRACT.md "
                             f"D12) and, until X translates them, the eight keys of §8.1; a key of the app "
                             f"has all ten languages")
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
    for text in entry.get("allowJapanese", []):
        if text not in ALLOWED_JAPANESE:
            raise BuildError(f"{where}: \"allowJapanese\" may hold only "
                             f"{' and '.join(repr(t) for t in ALLOWED_JAPANESE)} (§2.3), not {text!r}")
        if text not in entry["ja"]:
            raise BuildError(f"{where}: \"allowJapanese\" lists {text!r}, which the ja does not have")


def load_sources(repo):
    """Every key of tools/l10n/source/*.json: ({key: entry}, {key: file}, [(file, number of keys)])."""
    folder = os.path.join(repo, SOURCE_DIR)
    keys, origin, files = {}, {}, []
    if not os.path.isdir(folder):
        return keys, origin, files
    for name in sorted(os.listdir(folder)):
        if name.startswith(".") or not name.endswith(".json"):
            continue  # .DS_Store, an editor's lock file, notes
        rel = f"{SOURCE_DIR}/{name}"
        match = SOURCE_FILE_RE.match(name)
        if not match:
            raise BuildError(f"{rel}: a source file is app-<owner>.json or kit-<owner>.json "
                             f"(remove a copy such as \"kit-K 2.json\")")
        kind = match.group(1)
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
            check_key(key, data["keys"][key], kind, where)
            keys[key] = data["keys"][key]
            origin[key] = rel
        files.append((rel, len(data["keys"])))
    return keys, origin, files


def load_translations(repo):
    """{language: {key: text}} from tools/l10n/translations/<language>.json, every key of the files;
    a language without a file has none."""
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


def values_of(key, entry, translations):
    """{language: text} of one key: what its tables hold (the languages without a text are left
    out). Used by the outputs and by the lint (L-4)."""
    if entry.get("fixed", False):
        return {language: entry["fixedValues"][language] for language in LANGUAGES}
    values = {"ja": entry["ja"]}
    if entry.get("jaOnly", False):
        return values
    for language in TRANSLATED:
        if key in translations[language]:
            values[language] = translations[language][key]
    return values


# ── The Kit's Swift table ─────────────────────────────────────────────────────────────────────

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

    /// `text(key, language)` with its placeholders filled from `args` (`fill`).
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

    /// `template` with its placeholders filled from `args`, without `String(format:)` (D5): `%@`
    /// takes the next argument (the first `%@` takes `args[0]`, the second `args[1]`, …; a `%n$@`
    /// does not move this count) and `%n$@` takes `args[n - 1]` (n from 1 to 99). Nothing else is a
    /// placeholder: `%%`, `%d` and any other `%` stay as they are (numbers are formatted before they
    /// are passed). A placeholder whose argument is missing stays as it is, and a `%@` inside an
    /// argument is not filled again. The app's `L.format` and `L.plural` use the same rule.
    public static func fill(_ template: String, _ args: [String]) -> String {
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

    private static func table(_ language: UILanguage) -> [String: String] {
        switch language {
@CASES@
        }
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
            ja_only += 1
        else:
            listed.append(key)
        for language, text in values_of(key, entry, translations).items():
            tables[language][key] = text

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


# ── The app's tables ──────────────────────────────────────────────────────────────────────────

def xcstrings_path(table):
    return f"{APP_RESOURCES}/{table}.xcstrings"


def strings_path(language, table):
    return f"{APP_RESOURCES}/{language}.lproj/{table}.strings"


def _values_summary(count_keys, per_language):
    return (f"{_count(count_keys, 'key')}; texts: "
            + ", ".join(f"{language} {per_language[language]}" for language in LANGUAGES))


def catalog_json(entries, translations):
    """A String Catalog (.xcstrings) of `entries` ({key: entry}) and a one-line summary. Xcode's own
    layout: two-space indent, " : " between a name and its value, names sorted."""
    strings = {}
    per_language = {language: 0 for language in LANGUAGES}
    for key in sorted(entries):
        entry = entries[key]
        unit = {"extractionState": "manual", "localizations": {}}
        if entry.get("comment"):
            unit["comment"] = entry["comment"]
        for language, text in values_of(key, entry, translations).items():
            unit["localizations"][language] = {"stringUnit": {"state": "translated", "value": text}}
            per_language[language] += 1
        strings[key] = unit
    document = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    text = json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : ")) + "\n"
    return text, _values_summary(len(entries), per_language)


def _strings_escape(text):
    out = []
    for ch in text:
        if ch == "\\":
            out.append("\\\\")
        elif ch == "\"":
            out.append("\\\"")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20 or ord(ch) == 0x7F:
            out.append("\\U%04X" % ord(ch))
        else:
            out.append(ch)
    return "".join(out)


def strings_text(entries, translations, language, table):
    """A .strings file of one language of `entries` (the keys that have a text in it)."""
    lines = [f"/* 生成物。直さない。tools/l10n/build.py ({table}, {language}; docs/M7B_CONTRACT.md §2.3) */\n"]
    count = 0
    for key in sorted(entries):
        text = values_of(key, entries[key], translations).get(language)
        if text is None:
            continue
        comment = entries[key].get("comment")
        lines.append("\n")
        if comment:
            lines.append("/* " + comment.replace("*/", "* /") + " */\n")
        lines.append(f"\"{_strings_escape(key)}\" = \"{_strings_escape(text)}\";\n")
        count += 1
    return "".join(lines), f"{_count(count, 'text')}"


def present_format(repo):
    """The format the repository has: "xcstrings" when a catalog is there, else "strings" when a
    .strings file of the ten .lproj is, else "xcstrings"."""
    if any(os.path.exists(os.path.join(repo, xcstrings_path(table))) for table in APP_TABLES.values()):
        return "xcstrings"
    for language in LANGUAGES:
        for table in APP_TABLES.values():
            if os.path.exists(os.path.join(repo, strings_path(language, table))):
                return "strings"
    return "xcstrings"


def app_outputs(keys, translations, fmt):
    """{path: (text, summary)} of the app's tables in the format `fmt`."""
    outputs = {}
    for target, table in APP_TABLES.items():
        entries = {key: entry for key, entry in keys.items() if entry["target"] == target}
        if fmt == "xcstrings":
            outputs[xcstrings_path(table)] = catalog_json(entries, translations)
        else:
            for language in LANGUAGES:
                outputs[strings_path(language, table)] = strings_text(entries, translations, language, table)
    return outputs


def other_format_files(fmt):
    """The paths of the format that is not `fmt` (removed when `fmt` is written)."""
    if fmt == "xcstrings":
        return [strings_path(language, table) for language in LANGUAGES for table in APP_TABLES.values()]
    return [xcstrings_path(table) for table in APP_TABLES.values()]


def check_repo(repo):
    for needed in (os.path.dirname(KIT_OUTPUT), APP_DIR):
        if not os.path.isdir(os.path.join(repo, needed)):
            raise BuildError(f"{repo} is not the repository (it has no {needed})")


def build_outputs(repo, fmt=None):
    """{path relative to the repository: (text, summary)} of every output; nothing is written.
    `fmt` is "xcstrings" or "strings" for the app's tables (None: the one the repository has)."""
    keys, origin, files = load_sources(repo)
    translations = load_translations(repo)
    kit_keys = {key: entry for key, entry in keys.items() if entry["target"] == "kit"}
    kit_files = [(rel, count) for rel, count in files if os.path.basename(rel).startswith("kit-")]
    outputs = {KIT_OUTPUT: kit_swift(kit_keys, kit_files, translations)}
    outputs.update(app_outputs(keys, translations, fmt or present_format(repo)))
    return outputs


def check_outputs(repo, fmt=None):
    """[problem] of the outputs on disk against what the sources give (L-10, --check): a file that
    differs or is missing, and a file of the other format that is left. Raises BuildError when the
    sources are malformed."""
    check_repo(repo)
    fmt = fmt or present_format(repo)
    problems = []
    for rel, (text, _) in sorted(build_outputs(repo, fmt).items()):
        try:
            with open(os.path.join(repo, rel), "rb") as f:
                same = f.read() == text.encode("utf-8")
        except FileNotFoundError:
            problems.append(f"{rel} is missing")
            continue
        if not same:
            problems.append(f"{rel} is not what the sources give")
    for rel in other_format_files(fmt):
        if os.path.exists(os.path.join(repo, rel)):
            problems.append(f"{rel} is left from the {'strings' if fmt == 'xcstrings' else 'xcstrings'} format")
    return problems


def write_outputs(repo, outputs, fmt=None):
    """Writes the outputs whose text changed and removes the files of the other format; prints one
    line per output (the .strings files of one table in one line)."""
    fmt = fmt or present_format(repo)
    grouped = {}
    for rel in sorted(outputs):
        text, summary = outputs[rel]
        path = os.path.join(repo, rel)
        data = text.encode("utf-8")
        try:
            with open(path, "rb") as f:
                same = f.read() == data
        except FileNotFoundError:
            same = False
        if not same:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as f:
                f.write(data)
        if rel.endswith(".strings"):
            table = os.path.basename(rel)
            group = grouped.setdefault(table, {"wrote": 0, "parts": []})
            group["wrote"] += 0 if same else 1
            group["parts"].append(f"{rel.split('/')[-2][:-len('.lproj')]} {summary.split()[0]}")
            continue
        if same:
            print(f"build.py: {rel} is up to date ({summary})")
        else:
            print(f"build.py: wrote {rel} ({summary})")
    for table in sorted(grouped):
        group = grouped[table]
        state = f"wrote {group['wrote']} of" if group["wrote"] else "up to date:"
        print(f"build.py: {APP_RESOURCES}/<language>.lproj/{table} {state} {len(group['parts'])} "
              f"({', '.join(group['parts'])})")
    for rel in other_format_files(fmt):
        path = os.path.join(repo, rel)
        if os.path.exists(path):
            os.remove(path)
            print(f"build.py: removed {rel} (the {fmt} format is written)")
            folder = os.path.dirname(path)
            if folder.endswith(".lproj") and os.path.isdir(folder) and not os.listdir(folder):
                os.rmdir(folder)


def main(argv):
    parser = argparse.ArgumentParser(
        prog="build.py",
        description="Writes TegakiKit/Sources/DayKit/KitStrings.generated.swift and the app's "
                    "Localizable / InfoPlist tables from tools/l10n/source/*.json and "
                    "tools/l10n/translations/*.json (docs/M7B_CONTRACT.md §2.3).")
    parser.add_argument("repo", nargs="?", default=DEFAULT_REPO,
                        help="the repository (default: the one this script is in)")
    parser.add_argument("--check", action="store_true",
                        help="write nothing; exit 1 when an output is not what the sources give (L-10)")
    parser.add_argument("--format", choices=FORMATS,
                        help="the app's tables as String Catalogs (xcstrings) or as .strings files of "
                             "the ten .lproj (strings, 0-4); default: the format the repository has")
    args = parser.parse_args(argv)
    repo = os.path.abspath(args.repo)
    try:
        check_repo(repo)
        fmt = args.format or present_format(repo)
        if args.check:
            problems = check_outputs(repo, fmt)
        else:
            outputs = build_outputs(repo, fmt)
    except BuildError as e:
        print(f"build.py: {e}", file=sys.stderr)
        return 1
    if args.check:
        for problem in problems:
            print(f"build.py: {problem}", file=sys.stderr)
        if problems:
            print(f"build.py: run python3 -I tools/l10n/build.py{' --format ' + fmt if args.format else ''}",
                  file=sys.stderr)
            return 1
        print(f"build.py: every output is what the sources give ({fmt})")
        return 0
    write_outputs(repo, outputs, fmt)
    if not os.path.isfile(os.path.join(repo, UI_LANGUAGE_FILE)):
        print(f"build.py: note: {UI_LANGUAGE_FILE} is not there yet; {KIT_OUTPUT} uses its "
              f"UILanguage and PluralCategory (§0, K) and does not compile without them",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
