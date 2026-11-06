#!/usr/bin/env python3
"""The holiday data of 1.2: python-holidays -> TegakiKit/HolidayData (docs/M7B_CONTRACT.md §5.1, §5.2).

    <venv>/bin/python -I tools/holidays/gen.py <outdir> [--previous <old HolidayData>] [--report <file>]

<venv> has exactly the versions of tools/holidays/requirements.txt (gen.py stops otherwise); see
tools/holidays/README.md for making it. The venv and the downloaded wheels live outside the
repository, and nothing is run from inside them.

Writes into <outdir>:

    <CC>.json        one file per country, format "tegaki-holidays/1" (§5.2): every country that
                     python-holidays knows by a two-letter code which is also in iso-regions.txt
                     (Foundation's regions; so the alias "UK" of GB is not written)
    index.json       per country: code, langs, ui, subdivisions [code, display, names, local],
                     renamed, lastOfficialYear, notice, coverage [from, until] (§5.1)
    SOURCE.json      library, version, the sha256 of this generator, years, the sha256 of every
                     other file written, the Python and package versions, the sha256 of each
                     installed package's RECORD and of the two licence files
    LICENSE-python-holidays.txt, CONTRIBUTORS-python-holidays.txt
                     byte-for-byte copies of holidays-<version>.dist-info/licenses/{LICENSE,CONTRIBUTORS}

and removes the <CC>.json files of <outdir> that this run does not write (a country the library
dropped). Nothing else in <outdir> is touched.

The same library, inputs and generator give the same bytes: everything is walked in sorted order,
JSON is written with sorted keys and no spaces, and no date or path of this machine goes in (run
it twice and `diff -r` the two outputs; README.md). Python's string and date hashes change from run
to run under -I, so no output may depend on the order of a set.

What is written (§5.2):
  - Only the "public" category, observed days included, years 2000-2099.
  - Names in the columns `langs`: langs[0] is the country's default language ("en" when the
    library has none), then the columns that one of the app's ten languages uses (`ui`).
  - The default language decides which holiday is on which day. The other columns are the
    translations of those same holidays, found through the library's own message catalogs (the
    library assigns observed days by sorting the names, in each language separately, so the same
    date can carry a different holiday in another language).
  - Library suffixes are classified with the column's own labels: observed (flag 2), estimated
    (flag 1; the suffix is taken off the name, the app adds its own), substituted days off
    (flag 4; the name stays the library's template with %s, filled by the app from substFrom).
    A label that is only "%s" is not used (it would match every name), and a text that is one of
    the country's own message ids is a name, not a label around one (Labels.classify).
    Where the country takes islamic_show_estimated, the names without the suffix are checked
    against what islamic_show_estimated=False gives; two names of a day that are one name once
    the suffix is off are written once.
  - lastOfficialYear: the last year of the library's special tables, or of PUBLISHED_AND_COMPARED
    when that is later (§5.1).
  - CN and VN: every holiday after lastOfficialYear gets the estimated flag; CN's rule-made
    observed days after lastOfficialYear are not written (0-29).
  - Subdivisions are written only when they differ from the country (add / remove). A code with
    letters outside [A-Za-z0-9 ] (BR "São Paulo Capital") is written folded to ASCII ("Sao Paulo
    Capital", 0-28); its display name keeps the library's spelling.
  - renamed (§5.11): the subdivision codes of the previous data (--previous, by default the
    index.json already in <outdir>) that this library no longer has but knows as an alias.
  - coverage (0-30) counts a year's holidays as distinct names, without the substituted days off
    (Country.build says why); one low year between two full ones does not end it (coverage_range).
"""
import argparse
import collections
import datetime as dt
import hashlib
import importlib.metadata as metadata
import inspect
import json
import os
import re
import statistics
import sys
import unicodedata
import warnings

# python-holidays falls back to the process's locale variables when it is given no language; the
# output must not depend on the shell it runs in. Cleared before the library is imported.
for _name in ("LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"):
    os.environ.pop(_name, None)

import holidays  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ISO_REGIONS = os.path.join(HERE, "iso-regions.txt")
REQUIREMENTS = os.path.join(HERE, "requirements.txt")

FORMAT = "tegaki-holidays/1"
INDEX_FORMAT = "tegaki-holidays-index/1"
Y0, Y1 = 2000, 2099
EPOCH = dt.date(2000, 1, 1)
UI_LANGS = ["ja", "en", "zh-Hans", "zh-Hant", "ko", "fr", "de", "es", "it", "pt-BR"]
F_ESTIMATED, F_OBSERVED, F_SUBSTITUTED = 1, 2, 4

# Countries whose days off and working weekends are set each year by a government notice (0-29).
NOTICE = ["BY", "CN", "KZ", "RU", "TW", "UZ", "VN"]
# The library's special tables only have a year when that year moves a day, so a published year with
# nothing to move looks unpublished. These are the last years whose published calendar was compared
# with this data, day by day, and matched (docs/M7B.md, section "TW"). Compare again and raise them
# at the yearly update (§5.11).
PUBLISHED_AND_COMPARED = {"KZ": 2026, "TW": 2027}
# Of those, the ones whose holidays after the library's last official year are all estimates, and
# the one whose observed days after it are made by a rule that its law does not have (0-29).
ESTIMATED_AFTER_NOTICE = ["CN", "VN"]
NO_OBSERVED_AFTER_NOTICE = ["CN"]

# coverage (0-30): the years whose number of national holidays is at least this share of the
# median of COVERAGE_BASE.
COVERAGE_SHARE = 0.8
COVERAGE_BASE = range(2015, 2025)
COVERAGE_ANCHOR = 2020

SUBDIVISION_CODE = re.compile(r"[A-Za-z0-9 ]{1,40}\Z")      # 0-28
ISO_LIKE = re.compile(r"[A-Z0-9]{1,3}\Z")                    # not `local` (§5.2)
ABBREVIATION = re.compile(r"[A-Z0-9]{1,3}\Z")                # not a `display` (§5.2)
DATE_FORMAT = re.compile(r"(?:[^%]|%[Ymd])*\Z")              # substFmt: %Y %m %d only (§5.2)

HANS = ["zh_CN", "zh_SG"]
HANT = ["zh_TW", "zh_HK", "zh_MO"]
FAMILY = {"ja": "ja", "en": "en", "ko": "ko", "fr": "fr", "de": "de", "es": "es", "it": "it", "pt-BR": "pt"}
PREFERRED = {"ja": ["ja_JP"], "en": ["en_US", "en_GB"], "ko": ["ko_KR"], "fr": ["fr_FR"], "de": ["de_DE"],
             "es": ["es_ES"], "it": ["it_IT"], "pt": ["pt_BR", "pt", "pt_PT"]}


class GenError(Exception):
    """Something this generator was not built for; the message says what. Nothing is written."""


def offset(day):
    return (day - EPOCH).days


def dump(obj):
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), sort_keys=True) + "\n"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


# MARK: - Inputs

def read_iso_regions(path=ISO_REGIONS):
    codes = []
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, 1):
            code = line.rstrip("\n").split("\t", 1)[0]
            if not re.fullmatch(r"[A-Z]{2}", code):
                raise GenError(f"iso-regions.txt:{number}: {code!r} is not a two-letter region")
            codes.append(code)
    if codes != sorted(set(codes)):
        raise GenError("iso-regions.txt: the codes are not sorted or not unique")
    return codes


def read_pins(path=REQUIREMENTS):
    """{normalized name: version} of the `name==version` lines of requirements.txt."""
    pins = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"\s*([A-Za-z0-9][A-Za-z0-9._-]*)==([^\s;\\]+)", line)
            if m:
                pins[m.group(1).lower().replace("_", "-")] = m.group(2)
    if "holidays" not in pins:
        raise GenError("requirements.txt has no holidays==<version>")
    return pins


def installed():
    """{normalized name: (version, distribution)} of the packages in this Python."""
    out = {}
    for dist in metadata.distributions():
        name = (dist.metadata["Name"] or "").lower().replace("_", "-")
        if name:
            out[name] = (dist.version, dist)
    return out


def check_pins(pins, have):
    wrong = []
    for name, version in sorted(pins.items()):
        got = have.get(name, (None,))[0]
        if got != version:
            wrong.append(f"{name}=={version} (this Python has {got or 'none'})")
    if holidays.__version__ != pins["holidays"]:
        wrong.append(f"import holidays gives {holidays.__version__}")
    if wrong:
        raise GenError("the venv is not requirements.txt: " + "; ".join(wrong))


def record_digest(dist):
    for f in dist.files or ():
        if f.name == "RECORD" and str(f.parent).endswith(".dist-info"):
            # A script of the package is listed with its hash, and its first line holds the venv's own path.
            lines = f.locate().read_bytes().splitlines(keepends=True)
            return sha256(b"".join(line for line in lines if not line.startswith(b"../../../bin/")))
    raise GenError(f"{dist.metadata['Name']}: no RECORD in its dist-info")


def licence_files(dist):
    """(LICENSE bytes, CONTRIBUTORS bytes) of holidays' dist-info."""
    found = {}
    for f in dist.files or ():
        parts = f.parts
        if len(parts) >= 3 and parts[0].endswith(".dist-info") and parts[1] == "licenses" and parts[-1] in ("LICENSE", "CONTRIBUTORS"):
            found[parts[-1]] = f.locate()
    if set(found) != {"LICENSE", "CONTRIBUTORS"}:
        raise GenError("holidays' dist-info has no licenses/LICENSE and licenses/CONTRIBUTORS")
    return found["LICENSE"].read_bytes(), found["CONTRIBUTORS"].read_bytes()


# MARK: - The library

def make(cc, subdiv, language, years=range(Y0, Y1 + 1), notes=None, **kwargs):
    """country_holidays with the library's warnings kept (sorted later) instead of printed."""
    args = dict(years=years, language=language, **kwargs)
    if subdiv is not None:
        args["subdiv"] = subdiv
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        inst = holidays.country_holidays(cc, **args)
    if notes is not None:
        for w in caught:
            notes.add(f"{cc}{'-' + subdiv if subdiv else ''}: {w.category.__name__}: {w.message}")
    return inst


def catalogs(tr):
    """The message catalogs behind an instance's `tr` (its own, then its parent's)."""
    out = []
    t = getattr(tr, "__self__", None)
    while t is not None:
        cat = getattr(t, "_catalog", None)
        if cat:
            out.append(cat)
        t = getattr(t, "_fallback", None)
    return out


def last_official_year(inst):
    """The largest year of the library's special tables (special_* dicts keyed by year, on the
    country class, its Static classes and the instance), or None (§5.1)."""
    names = set(vars(inst))
    for klass in type(inst).__mro__:
        names |= set(vars(klass))
    years = []
    for name in sorted(names):
        if name.startswith("special_"):
            value = getattr(inst, name, None)
            if isinstance(value, dict) and value and all(isinstance(y, int) and not isinstance(y, bool) for y in value):
                years.append(max(value))
    return max(years) if years else None


def pick_column(ui, cc, default, supported):
    """The library language whose names the app shows for the UI language `ui`, or None."""
    if ui == "zh-Hans":
        order = ([default] if default in HANS else []) + HANS
    elif ui == "zh-Hant":
        own = "zh_" + cc
        order = ([default] if default in HANT else []) + ([own] if own in HANT else []) + HANT
    else:
        fam = FAMILY[ui]
        order = []
        if default and (default == fam or default.startswith(fam + "_")):
            order.append(default)
        order += [fam + "_" + cc, fam] + PREFERRED[fam]
        order += sorted(x for x in supported if x.split("_")[0] == fam)
    for code in order:
        if code in supported:
            return code
    return None


class Labels:
    """A column's translated suffix labels, as patterns (§5.2)."""

    def __init__(self, inst):
        tr = inst.tr

        def label(attr):
            value = getattr(inst, attr, None)
            if not value:  # tr("") is the catalog header, never a label
                return None
            text = tr(value)
            if text.count("%s") != 1 or text.strip() == "%s" or "%" in text.replace("%s", ""):
                return None
            return text

        def pattern(text):
            if text is None:
                return None
            pre, post = text.split("%s")
            return re.compile(re.escape(pre) + "(.+)" + re.escape(post) + r"\Z", re.S)

        self.observed = label("observed_label")
        self.observed_before = label("observed_label_before")
        self.observed_estimated = label("observed_estimated_label")
        self.estimated = label("estimated_label")
        self.substituted = label("substituted_label")
        fmt = getattr(inst, "substituted_date_format", None)
        self.subst_format = tr(fmt) if fmt else "%Y-%m-%d"
        if not DATE_FORMAT.match(self.subst_format):
            raise GenError(f"{inst.country}: the substituted date format {self.subst_format!r} has a directive other than %Y %m %d")
        self.rx_observed = [p for p in (pattern(self.observed), pattern(self.observed_before)) if p]
        self.rx_observed_estimated = pattern(self.observed_estimated)
        self.rx_estimated = pattern(self.estimated)
        self.rx_substituted = pattern(self.substituted)
        self.plain = frozenset()  # the column's translations of the message ids (Country sets it)

    def short_of_template(self):
        """The short name of a substituted day: the template before its first "（" or " (" (§5.2).
        "" when that leaves nothing (the app then shows kit.holiday.dayOff)."""
        text = self.substituted
        cut = [i for i in (text.find("（"), text.find(" (")) if i >= 0]
        head = text[:min(cut)].strip() if cut else ""
        return "" if "%" in head else head

    def classify(self, text):
        """(flags, full, short, substituted-from text or None) of a name in this column.

        A text that is the translation of one of the country's message ids is a holiday's own
        name, so nothing is taken off it, even when it looks like a label around another name
        (MY "Cuti Peristiwa" against the observed label "Cuti %s", GN "Lendemain de la Tabaski"
        against "Lendemain de la %s"). The estimated label is tried before the observed ones, so
        "Lendemain de la Tabaski (estimé)" is that name, estimated, and not the observed day of
        "Tabaski"."""
        if self.rx_substituted:
            m = self.rx_substituted.match(text)
            if m:
                return F_SUBSTITUTED, self.substituted, self.short_of_template(), m.group(1)
        flags, core = 0, text
        for _ in range(3):
            if core in self.plain:
                break
            m = self.rx_estimated.match(core) if self.rx_estimated else None
            if m:
                flags, core = flags | F_ESTIMATED, m.group(1)
                continue
            m = self.rx_observed_estimated.match(core) if self.rx_observed_estimated else None
            if m:
                flags, core = flags | F_OBSERVED | F_ESTIMATED, m.group(1)
                continue
            m = next((x for x in (rx.match(core) for rx in self.rx_observed) if x), None)
            if m:
                flags, core = flags | F_OBSERVED, m.group(1)
                continue
            break
        if flags & F_ESTIMATED:
            full = self.observed % core if (flags & F_OBSERVED and self.observed) else core
        else:
            full = text
        return flags, full, core, None


class Translator:
    """Default-language names -> another column, through the library's catalogs: a name is a
    message id's translation, or a "%s" message (a label) around another name."""

    def __init__(self, tr_default, msgids):
        self.tr_default = tr_default
        self.reverse = collections.defaultdict(set)
        templates = []
        for m in msgids:
            self.reverse[tr_default(m)].add(m)
            if m.count("%s") == 1 and "%" not in m.replace("%s", ""):
                text = tr_default(m)
                if text.count("%s") == 1 and text.strip() != "%s":
                    pre, post = text.split("%s")
                    rx = re.compile(re.escape(pre) + "(.+)" + re.escape(post) + r"\Z", re.S)
                    templates.append((-(len(pre) + len(post)), m, rx))
        templates.sort(key=lambda t: (t[0], t[1]))
        self.templates = templates
        self.cache = {}

    def candidates(self, text, tr, column):
        key = (column, text)
        if key not in self.cache:
            self.cache[key] = self._candidates(text, tr, 0)
        return self.cache[key]

    def _candidates(self, text, tr, depth):
        out = [tr(m) for m in sorted(self.reverse.get(text, ()))]
        if depth < 3:
            for _, m, rx in self.templates:
                hit = rx.match(text)
                if hit:
                    for inner in self._candidates(hit.group(1), tr, depth + 1):
                        try:
                            out.append(tr(m) % inner)
                        except (TypeError, ValueError):
                            pass
        if not out:
            out.append(tr(text) if text else text)
        unique = []
        for x in out:
            if x not in unique:
                unique.append(x)
        return unique


# MARK: - One country

class Country:
    def __init__(self, cc, stats, notes):
        self.cc, self.stats, self.notes = cc, stats, notes
        probe = make(cc, None, None, years=(), notes=notes)
        self.default = probe.default_language
        supported = tuple(probe.supported_languages or ())
        if self.default is None:
            if supported:
                raise GenError(f"{cc}: languages {supported} but no default language")
            self.ui_columns = {"en": "en"}
        else:
            self.ui_columns = {ui: c for ui in UI_LANGS for c in [pick_column(ui, cc, self.default, supported)] if c}
        self.d_col = self.default or "en"
        self.cols = [self.d_col] + sorted(set(self.ui_columns.values()) - {self.d_col})
        self.language_arg = {c: (None if self.default is None else c) for c in self.cols}
        self.loy = max((y for y in (last_official_year(probe), PUBLISHED_AND_COMPARED.get(cc)) if y is not None), default=None)
        self.notice = cc in NOTICE

        # Subdivisions (0-28): the data code is the library's code, folded to ASCII when it has
        # other letters (BR "São Paulo Capital" -> "Sao Paulo Capital").
        self.subdivisions = []  # (data code, library code)
        seen = {}
        for code in probe.subdivisions or ():
            data_code = code
            if not SUBDIVISION_CODE.match(code):
                data_code = "".join(ch for ch in unicodedata.normalize("NFKD", code) if not unicodedata.combining(ch))
                if not SUBDIVISION_CODE.match(data_code):
                    raise GenError(f"{cc}: the subdivision code {code!r} cannot be written as [A-Za-z0-9 ]{{1,40}}")
                self.stats["folded subdivision codes"].append(f"{cc}-{code} -> {data_code}")
            folded = data_code.lower()
            if folded in seen:
                raise GenError(f"{cc}: the subdivision codes {seen[folded]!r} and {code!r} differ only in case")
            seen[folded] = code
            self.subdivisions.append((data_code, code))
        self.subdivisions.sort()
        aliases = getattr(probe, "subdivisions_aliases", {}) or {}
        self.aliases = collections.defaultdict(list)
        for alias, code in aliases.items():  # the library's order (dicts keep it)
            self.aliases[code].append(alias)

        # The catalogs of every language the library has for this country give the message ids.
        msgids = set()
        for lang in sorted(set(supported) | {self.default} - {None}):
            inst = make(cc, None, lang, years=(), notes=notes)
            for cat in catalogs(inst.tr):
                msgids |= {m for m in cat if isinstance(m, str) and m}
        self.national = {c: make(cc, None, self.language_arg[c], notes=notes) for c in self.cols}
        self.labels = {c: Labels(self.national[c]) for c in self.cols}
        for c in self.cols:
            tr = self.national[c].tr
            self.labels[c].plain = frozenset(tr(m) for m in msgids)
        self.translator = Translator(self.national[self.d_col].tr, sorted(msgids))
        self.names, self.name_index, self.flags = [], {}, []
        self.shorts = {}

    # Name rows: (full per column, short per column, flags) -> number.
    def name_id(self, fulls, shorts, flags):
        key = (tuple(fulls), tuple(shorts), flags)
        if key not in self.name_index:
            self.name_index[key] = len(self.names)
            self.names.append(list(fulls))
            self.flags.append(flags)
            if list(shorts) != list(fulls):
                self.shorts[len(self.names) - 1] = list(shorts)
        return self.name_index[key]

    def translate(self, insts, col, day, text, year_names):
        """The `col` text of the default-language name `text` on `day`."""
        tr = insts[col].tr
        cands = self.translator.candidates(text, tr, col)
        counter = year_names(col, day.year)
        for c in cands:
            if counter[c]:
                self.stats["names translated through the catalogs"] += 1
                return c
        here_default = insts[self.d_col].get_list(day)
        here = insts[col].get_list(day)
        if len(here_default) == 1 and len(here) == 1:
            self.stats["names taken from the same day (catalog had no match)"] += 1
            self.stats["translation fallbacks"].append(f"{self.cc} {col} {day}: {text} -> {here[0]} (same day)")
            return here[0]
        self.stats["names translated without a match in that language (gettext only)"] += 1
        self.stats["translation fallbacks"].append(f"{self.cc} {col} {day}: {text} -> {cands[0]} (gettext)")
        return cands[0]

    def region(self, insts):
        """{day: [(default text, flags, full per column, short per column, substituted-from day or
        None)]} of one region (`insts`: its instance per column), in the library's order of each day."""
        dcol = self.d_col
        caches = {}

        def year_names(col, year):
            if col not in caches:
                by_year = collections.defaultdict(collections.Counter)
                inst = insts[col]
                for d in inst:
                    by_year[d.year].update(inst.get_list(d))
                caches[col] = by_year
            return caches[col][year]

        labels_d = self.labels[dcol]
        out = {}
        chosen = collections.defaultdict(collections.Counter)  # (col, year) -> texts chosen
        for day in sorted(d for d in insts[dcol] if Y0 <= d.year <= Y1):
            row = []
            for text in insts[dcol].get_list(day):
                flags, _, _, subst_from = labels_d.classify(text)
                fulls, shorts = [], []
                for col in self.cols:
                    lab = self.labels[col]
                    if flags & F_SUBSTITUTED:
                        if not lab.substituted:
                            raise GenError(f"{self.cc}: no substituted label in {col}")
                        fulls.append(lab.substituted)
                        shorts.append(lab.short_of_template())
                        continue
                    ctext = text if col == dcol else self.translate(insts, col, day, text, year_names)
                    if col != dcol:
                        chosen[(col, day.year)][ctext] += 1
                    cflags, cfull, cshort, _ = lab.classify(ctext)
                    if cflags != flags:
                        self.stats["columns whose suffix differs from the default language"] += 1
                        self.stats["suffix differences"].append(f"{self.cc} {col} {day}: {text!r} ({flags}) / {ctext!r} ({cflags})")
                    fulls.append(cfull)
                    shorts.append(cshort)
                frm = None
                if flags & F_SUBSTITUTED:
                    try:
                        frm = dt.datetime.strptime(subst_from, labels_d.subst_format).date()
                    except ValueError:
                        raise GenError(f"{self.cc} {day}: {text!r}: {subst_from!r} is not {labels_d.subst_format!r}")
                else:
                    # Two names of a day that are one name once the estimate suffix is off (AZ
                    # 2072-01-05 "Qurban bayrami (müşahidə olunur)" and "… (müşahidə olunur, təxmini)")
                    # are one holiday, as islamic_show_estimated=False has it; it keeps both flags.
                    same = next((i for i, r in enumerate(row) if not r[1] & F_SUBSTITUTED and r[2][0] == fulls[0]), None)
                    if same is not None:
                        t, f, fu, sh, fr = row[same]
                        row[same] = (t, f | flags, fu, sh, fr)
                        self.stats["names of a day joined once their estimate suffix was off"] += 1
                        continue
                row.append((text, flags, fulls, shorts, frm))
            if row:
                out[day] = row
        # Every translated year must hold the same names as the library's own instance of that
        # language (the days may differ: that is the observed-day order, see the docstring).
        for (col, year), counter in sorted(chosen.items()):
            have = collections.Counter(year_names(col, year))
            lab = self.labels[col]
            if lab.rx_substituted:
                have = collections.Counter({k: v for k, v in have.items() if not lab.rx_substituted.match(k)})
            if have != counter:
                self.stats["years whose translated names differ from the library's"] += 1
                self.stats["translation year differences"].append(
                    f"{self.cc} {col} {year}: library only {sorted((have - counter).elements())}, here only {sorted((counter - have).elements())}")
        return out

    def finish(self, raw):
        """Applies 0-29 (estimated after the notice; no CN observed days) and makes name numbers.
        -> {day: [(default text, name number, substituted-from day)]}"""
        out = {}
        for day, row in raw.items():
            after = self.loy is not None and day.year > self.loy
            kept = []
            for text, flags, fulls, shorts, frm in row:
                if after and self.cc in NO_OBSERVED_AFTER_NOTICE and flags & F_OBSERVED:
                    self.stats["CN observed days not written (after the last official year)"] += 1
                    continue
                if after and self.cc in ESTIMATED_AFTER_NOTICE:
                    flags |= F_ESTIMATED
                kept.append((text, self.name_id(fulls, shorts, flags), frm))
            if kept:
                out[day] = kept
        return out

    def instances(self, library_code):
        return {c: make(self.cc, library_code, self.language_arg[c], notes=self.notes) for c in self.cols}

    def check_estimated(self, raw):
        """The estimate suffixes are taken off with the column's label (the flag must be kept, so the
        library cannot be asked for names without them). Where the country takes
        islamic_show_estimated (§5.2), its own names without the suffix must be what that gives."""
        klass = type(self.national[self.d_col])
        if "islamic_show_estimated" not in inspect.signature(klass.__init__).parameters:
            return
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")  # the same warnings as the instance it is compared with
            plain = klass(years=range(Y0, Y1 + 1), language=self.language_arg[self.d_col], islamic_show_estimated=False)
        lab = self.labels[self.d_col]
        for day in sorted(set(raw) | {d for d in plain if Y0 <= d.year <= Y1}):
            names = [n for n in plain.get_list(day) if not (lab.rx_substituted and lab.rx_substituted.match(n))]
            if any(lab.classify(n)[0] & F_ESTIMATED for n in names):
                continue  # an estimate of another calendar (Hindu, Chinese): islamic_show_estimated keeps it
            ours = collections.Counter(fulls[0] for _, flags, fulls, _, _ in raw.get(day, []) if not flags & F_SUBSTITUTED)
            theirs = collections.Counter(names)
            if ours != theirs:
                raise GenError(f"{self.cc} {day}: without the estimate suffix the names are {sorted(ours.elements())}, "
                               f"islamic_show_estimated=False gives {sorted(theirs.elements())}")
        self.stats["countries whose suffix removal matches islamic_show_estimated=False"] += 1

    def build(self):
        cc = self.cc
        raw_national = self.region(self.national)
        self.check_estimated(raw_national)
        national = self.finish(raw_national)
        nat_default = self.national[self.d_col]
        workdays = sorted(d for d in nat_default.weekend_workdays if Y0 <= d.year <= Y1)
        if self.notice and self.loy is not None and any(d.year > self.loy for d in workdays):
            raise GenError(f"{cc}: working weekends after the last official year {self.loy}")

        days, subst_from = [], []
        for day in sorted(national):
            for _, nid, frm in national[day]:
                days += [offset(day), nid]
                if frm is not None:
                    subst_from += [offset(day), offset(frm)]

        subdivisions, index_subdivisions = [], []
        for data_code, library_code in self.subdivisions:
            insts = self.instances(library_code)
            if sorted(d for d in insts[self.d_col].weekend_workdays if Y0 <= d.year <= Y1) != workdays:
                self.stats["subdivisions whose working weekends differ (not written)"].append(f"{cc}-{data_code}")
            sub = self.finish(self.region(insts))
            add, add_from, remove = [], [], []
            for day in sorted(set(sub) | set(national)):
                n_texts = [t for t, _, _ in national.get(day, [])]
                s_texts = [t for t, _, _ in sub.get(day, [])]
                for t, nid, frm in national.get(day, []):
                    if t not in s_texts:
                        remove += [offset(day), nid]
                for t, nid, frm in sub.get(day, []):
                    if t not in n_texts:
                        add += [offset(day), nid]
                        if frm is not None:
                            add_from += [offset(day), offset(frm)]
            if not (add or remove):
                self.stats["subdivisions without a difference (not written)"] += 1
                continue
            item = {"code": data_code}
            if add:
                item["add"] = add
            if add_from:
                item["addFrom"] = add_from
            if remove:
                item["remove"] = remove
            subdivisions.append(item)
            names = list(self.aliases.get(library_code, []))
            if data_code != library_code and library_code not in names:
                names.append(library_code)
            display = next((a for a in self.aliases.get(library_code, []) if not ABBREVIATION.match(a)), library_code)
            index_subdivisions.append({"code": data_code, "display": display, "names": names,
                                       "local": not bool(ISO_LIKE.match(data_code))})

        per_year = collections.Counter(day.year for day, row in national.items() for _ in row)
        # coverage counts the holidays of a year, not its days: the distinct short names in the
        # default language, without the substituted days off (an observed day has the short name
        # of its holiday, a three-day festival is one holiday). Counting days would end the
        # coverage of a notice country at its last official year (its working-weekend swaps are
        # known only up to there, so CN 2027 would read "no data" instead of "before the notice",
        # 0-29) and of TW at 2021 (2022 simply had fewer swapped days).
        holidays_per_year = collections.defaultdict(set)
        for day, row in national.items():
            for _, nid, _ in row:
                if not self.flags[nid] & F_SUBSTITUTED:
                    holidays_per_year[day.year].add(self.shorts.get(nid, self.names[nid])[0])
        coverage = coverage_range(collections.Counter({y: len(v) for y, v in holidays_per_year.items()}))

        record = {
            "format": FORMAT, "country": cc, "source": f"python-holidays {holidays.__version__}",
            "years": [Y0, Y1], "epoch": EPOCH.isoformat(),
            "langs": self.cols,
            "ui": {ui: self.cols.index(c) for ui, c in sorted(self.ui_columns.items())},
            "names": self.names,
            "substFmt": [self.labels[c].subst_format for c in self.cols],
            "short": {str(k): v for k, v in sorted(self.shorts.items())},
            "flags": self.flags,
            "days": days,
            "substFrom": subst_from,
            "workdays": [offset(d) for d in workdays],
            "subdivisions": subdivisions,
        }
        index = {
            "code": cc, "langs": self.cols, "ui": record["ui"],
            "subdivisions": index_subdivisions, "renamed": {},
            "lastOfficialYear": self.loy, "notice": self.notice,
            "coverage": {"from": coverage[0], "until": coverage[1]},
        }
        facts = {"perYear": {str(y): per_year.get(y, 0) for y in range(Y0, Y1 + 1)},
                 "holidaysPerYear": {str(y): len(holidays_per_year.get(y, ())) for y in range(Y0, Y1 + 1)},
                 "entries": len(days) // 2, "names": len(self.names),
                 "subdivisionEntries": sum((len(s.get("add", [])) + len(s.get("remove", []))) // 2 for s in subdivisions),
                 "estimatedNames": sum(1 for f in self.flags if f & F_ESTIMATED),
                 "substituted": len(subst_from) // 2, "workdays": len(workdays)}
        return record, index, facts


def coverage_range(per_year):
    """(from, until) of 0-30: the run of years with at least COVERAGE_SHARE of the median count of
    COVERAGE_BASE that contains COVERAGE_ANCHOR, else the longest run (the earliest of equal ones).
    One year below the line does not end a run when it has holidays and the years on both sides
    are at the line (SK 2026: 11 holidays against a line of 12, then 13 a year to 2099; the setting
    would say the data stops in 2025). A year at the end of the data, or next to another low year,
    is not such a year (UA 2022: 3 holidays, then none). `per_year` is the number of holidays of
    each year (see Country.build)."""
    threshold = COVERAGE_SHARE * statistics.median(per_year.get(y, 0) for y in COVERAGE_BASE)

    def at_line(y):
        return per_year.get(y, 0) >= threshold

    def counts(y):
        return at_line(y) or (Y0 < y < Y1 and per_year.get(y, 0) > 0 and at_line(y - 1) and at_line(y + 1))

    runs, start = [], None
    for y in range(Y0, Y1 + 2):
        good = y <= Y1 and counts(y)
        if good and start is None:
            start = y
        elif not good and start is not None:
            runs.append((start, y - 1))
            start = None
    for run in runs:
        if run[0] <= COVERAGE_ANCHOR <= run[1]:
            return run
    return max(runs, key=lambda r: (r[1] - r[0], -r[0]))


# MARK: - renamed (§5.11)

def renamed_codes(cc, previous_country, index_subdivisions, aliases):
    """old code -> today's code. Kept from the previous data (`--previous`) and extended with the
    codes it had that this version no longer has but names as an alias (case-insensitively)."""
    if previous_country is None:
        return {}
    today = {s["code"].lower(): s["code"] for s in index_subdivisions}
    alias_to = {}
    for code, names in aliases.items():
        for a in names:
            alias_to.setdefault(a.lower(), code)
    out = {}
    for old, new in sorted((previous_country.get("renamed") or {}).items()):
        target = today.get(new.lower()) or today.get(alias_to.get(new.lower(), "").lower())
        if target:
            out[old] = target
    for s in previous_country.get("subdivisions") or []:
        old = s["code"]
        if old.lower() in today or old in out:
            continue
        target = alias_to.get(old.lower())
        if target and target.lower() in today:
            out[old] = today[target.lower()]
    return out


# MARK: - Main

def generate(outdir, previous=None, report=None, check_versions=True):
    iso = set(read_iso_regions())
    pins = read_pins()
    have = installed()
    if check_versions:
        check_pins(pins, have)
    codes = sorted(c for c in holidays.list_supported_countries() if len(c) == 2 and c in iso)
    if "UK" in codes:
        raise GenError("UK is in iso-regions.txt")

    previous_index = {}
    prev_dir = previous if previous is not None else outdir
    prev_path = os.path.join(prev_dir, "index.json")
    if os.path.exists(prev_path):
        with open(prev_path, encoding="utf-8") as f:
            previous_index = {c["code"]: c for c in json.load(f)["countries"]}

    stats = collections.defaultdict(int)
    for k in ("folded subdivision codes", "translation fallbacks", "suffix differences",
              "translation year differences", "subdivisions whose working weekends differ (not written)"):
        stats[k] = []
    notes = set()
    files, index_rows, facts = {}, [], {}
    for cc in codes:
        country = Country(cc, stats, notes)
        record, index, fact = country.build()
        index["renamed"] = renamed_codes(cc, previous_index.get(cc), index["subdivisions"],
                                         {d: country.aliases.get(l, []) for d, l in country.subdivisions})
        files[f"{cc}.json"] = dump(record).encode("utf-8")
        index_rows.append(index)
        facts[cc] = fact

    files["index.json"] = dump({"format": INDEX_FORMAT, "source": f"python-holidays {holidays.__version__}",
                                "countries": index_rows}).encode("utf-8")
    dist = have["holidays"][1]
    licence, contributors = licence_files(dist)
    files["LICENSE-python-holidays.txt"] = licence
    files["CONTRIBUTORS-python-holidays.txt"] = contributors
    with open(os.path.abspath(__file__), "rb") as f:
        generator = sha256(f.read())
    with open(ISO_REGIONS, "rb") as f:
        iso_digest = sha256(f.read())
    deps = sorted(pins)
    source = {
        "library": "python-holidays", "version": holidays.__version__, "generator": generator,
        "isoRegions": iso_digest, "years": [Y0, Y1],
        "python": ".".join(str(x) for x in sys.version_info[:3]),
        "packages": {name: have[name][0] for name in deps if name in have},
        "records": {name: record_digest(have[name][1]) for name in deps if name in have},
        "licenses": {name: sha256(files[name]) for name in ("LICENSE-python-holidays.txt", "CONTRIBUTORS-python-holidays.txt")},
        "files": {name: sha256(data) for name, data in sorted(files.items())},
    }
    files["SOURCE.json"] = dump(source).encode("utf-8")

    os.makedirs(outdir, exist_ok=True)
    for name in sorted(os.listdir(outdir)):
        if re.fullmatch(r"[A-Z]{2}\.json", name) and name not in files:
            os.remove(os.path.join(outdir, name))
            print(f"gen.py: removed {name} (not in python-holidays {holidays.__version__})", file=sys.stderr)
    written = 0
    for name, data in sorted(files.items()):
        path = os.path.join(outdir, name)
        old = None
        if os.path.exists(path):
            with open(path, "rb") as f:
                old = f.read()
        if old != data:
            with open(path, "wb") as f:
                f.write(data)
            written += 1
    # The licence files are copies: read them back and compare with the dist-info (§5.1).
    for name, original in (("LICENSE-python-holidays.txt", licence), ("CONTRIBUTORS-python-holidays.txt", contributors)):
        with open(os.path.join(outdir, name), "rb") as f:
            if f.read() != original:
                raise GenError(f"{name} is not a byte-for-byte copy of the dist-info file")

    total = sum(len(v) for k, v in files.items() if re.fullmatch(r"[A-Z]{2}\.json", k))
    print(f"gen.py: python-holidays {holidays.__version__}: {len(codes)} countries, "
          f"{sum(f['entries'] for f in facts.values())} national entries, "
          f"{total} bytes of country files, index {len(files['index.json'])} bytes; "
          f"{written} of {len(files)} files written to {outdir}", file=sys.stderr)
    for key in sorted(stats):
        value = stats[key]
        if isinstance(value, list):
            print(f"  {key}: {len(value)}", file=sys.stderr)
            for line in sorted(value)[:20]:
                print(f"    {line}", file=sys.stderr)
        else:
            print(f"  {key}: {value}", file=sys.stderr)
    print(f"  library warnings: {len(notes)}", file=sys.stderr)
    for line in sorted(notes)[:30]:
        print(f"    {line}", file=sys.stderr)
    if report:
        with open(report, "w", encoding="utf-8") as f:
            f.write(json.dumps({"facts": facts, "stats": {k: (sorted(v) if isinstance(v, list) else v) for k, v in sorted(stats.items())},
                                "warnings": sorted(notes)}, ensure_ascii=False, indent=1, sort_keys=True) + "\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description="python-holidays -> TegakiKit/HolidayData")
    parser.add_argument("outdir")
    parser.add_argument("--previous", help="the HolidayData of the last version, for `renamed` (default: <outdir>)")
    parser.add_argument("--report", help="also write the per-country counts and the generator's notes as JSON here")
    args = parser.parse_args(argv)
    if not sys.flags.isolated:
        print("gen.py: run it with python -I (docs/M7B_CONTRACT.md §5.1)", file=sys.stderr)
        return 2
    try:
        generate(args.outdir, previous=args.previous, report=args.report)
    except GenError as e:
        print(f"gen.py: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
