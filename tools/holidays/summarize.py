#!/usr/bin/env python3
"""What changed between two HolidayData folders, in Japanese, one line per change (docs/M7B_CONTRACT.md §5.1, §5.11).

    python3 -I tools/holidays/summarize.py <old HolidayData> <new HolidayData>

For the yearly update (README.md): the owner and the lead read this before the new data goes into
the app. It always lists, per country (sorted by code, with its Japanese name from
iso-regions.txt):

  - a country that is new or gone;
  - a subdivision code that is gone (a recorded setting "XX-<code>" then shows the whole country)
    and one whose code was renamed (old -> new; gen.py writes these into `renamed`), and new ones;
  - the years whose number of national holidays changed by 20% or more (runs of years are joined);
  - a change of lastOfficialYear, notice or coverage.

and ends with the totals. Needs only the standard library (any python3 runs it), reads only the
two folders, and writes nothing.
"""
import datetime as dt
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EPOCH = dt.date(2000, 1, 1)
CHANGE = 0.2  # a year is listed when its number of national holidays moved by this share or more


def names_ja():
    out = {}
    path = os.path.join(HERE, "iso-regions.txt")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                code, _, name = line.rstrip("\n").partition("\t")
                out[code] = name or code
    return out


def load(folder):
    with open(os.path.join(folder, "index.json"), encoding="utf-8") as f:
        index = {c["code"]: c for c in json.load(f)["countries"]}
    counts = {}
    for code in index:
        with open(os.path.join(folder, f"{code}.json"), encoding="utf-8") as f:
            days = json.load(f)["days"]
        per_year = {}
        for i in range(0, len(days), 2):
            y = (EPOCH + dt.timedelta(days=days[i])).year
            per_year[y] = per_year.get(y, 0) + 1
        counts[code] = per_year
    source = {}
    path = os.path.join(folder, "SOURCE.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            source = json.load(f)
    return index, counts, source


def years_text(a, b):
    return f"{a} 年" if a == b else f"{a}〜{b} 年"


def coverage_text(c):
    return f"{c['from']}〜{c['until']} 年"


def changed_years(old, new):
    """[(first, last, old counts, new counts)] of the runs of years that moved by CHANGE or more."""
    out = []
    for y in range(2000, 2100):
        a, b = old.get(y, 0), new.get(y, 0)
        if a == b or (a and abs(b - a) / a < CHANGE):
            continue
        if out and out[-1][1] == y - 1:
            out[-1][1] = y
            out[-1][2].append(a)
            out[-1][3].append(b)
        else:
            out.append([y, y, [a], [b]])
    return out


def count_text(values):
    lo, hi = min(values), max(values)
    return f"{lo}" if lo == hi else f"{lo}〜{hi}"


def main(argv):
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    old_index, old_counts, old_source = load(argv[1])
    new_index, new_counts, new_source = load(argv[2])
    ja = names_ja()
    lines = []

    def say(code, text):
        lines.append(f"{ja.get(code, code)}（{code}）: {text}")

    for code in sorted(set(old_index) | set(new_index)):
        old, new = old_index.get(code), new_index.get(code)
        if old is None:
            say(code, "新しく入った国・地域")
            continue
        if new is None:
            say(code, "無くなった国・地域（この国を選んでいた端末は「なし」になる）")
            continue
        old_subs = {s["code"]: s for s in old.get("subdivisions", [])}
        new_subs = {s["code"]: s for s in new.get("subdivisions", [])}
        new_lower = {c.lower() for c in new_subs}
        renamed_now = {k: v for k, v in (new.get("renamed") or {}).items() if k not in (old.get("renamed") or {})}
        for old_code, new_code in sorted(renamed_now.items()):
            say(code, f"州・地域のコードが変わった {old_code} → {new_code}（renamed に入っている）")
        for c in sorted(old_subs):
            if c.lower() not in new_lower and c not in renamed_now:
                say(code, f"州・地域 {c}（{old_subs[c]['display']}）が無くなった（選んでいた端末は国全体になる。全国と同じになったか、ライブラリから消えた）")
        for c in sorted(new_subs):
            if c.lower() not in {x.lower() for x in old_subs} and c not in renamed_now.values():
                say(code, f"新しい州・地域 {c}（{new_subs[c]['display']}）")
        for c in sorted(set(old_subs) & set(new_subs)):
            if old_subs[c]["display"] != new_subs[c]["display"]:
                say(code, f"州・地域 {c} の表示名 {old_subs[c]['display']} → {new_subs[c]['display']}")
        if old.get("lastOfficialYear") != new.get("lastOfficialYear"):
            say(code, f"公式の表の最後の年 {old.get('lastOfficialYear')} → {new.get('lastOfficialYear')}")
        if old.get("notice") != new.get("notice"):
            say(code, f"政府の発表で決まる国 {old.get('notice')} → {new.get('notice')}")
        if old.get("coverage") != new.get("coverage"):
            say(code, f"データの揃っている年 {coverage_text(old['coverage'])} → {coverage_text(new['coverage'])}")
        for first, last, a, b in changed_years(old_counts[code], new_counts[code]):
            if not any(a):
                say(code, f"{years_text(first, last)}に全国の祝日が新しく入った（0 → {count_text(b)} 件）")
            elif not any(b):
                say(code, f"{years_text(first, last)}の全国の祝日が無くなった（{count_text(a)} → 0 件）")
            else:
                share = round(100 * (sum(b) - sum(a)) / sum(a))
                say(code, f"{years_text(first, last)}の全国の祝日 {count_text(a)} → {count_text(b)} 件（{share:+d}%）")
        a, b = sum(old_counts[code].values()), sum(new_counts[code].values())
        if a != b:
            say(code, f"全国の祝日の合計 {a:,} → {b:,} 件（{b - a:+,}）")

    for line in lines:
        print(line)
    o_ver, n_ver = old_source.get("version", "?"), new_source.get("version", "?")
    print(f"合計: python-holidays {o_ver} → {n_ver}、国・地域 {len(old_index)} → {len(new_index)}、"
          f"全国の祝日 {sum(sum(c.values()) for c in old_counts.values()):,} → {sum(sum(c.values()) for c in new_counts.values()):,} 件、"
          f"全国と差のある州・地域 {sum(len(c.get('subdivisions', [])) for c in old_index.values())} → "
          f"{sum(len(c.get('subdivisions', [])) for c in new_index.values())}、変化 {len(lines)} 行")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
