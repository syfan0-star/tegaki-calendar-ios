#!/usr/bin/env python3
"""The iPhone Duo's App Store photos of store-shots.yml (its store-duo jobs; docs/M7D_CONTRACT.md §7.1, §7.2, §3.8; 1.4 D2).

There is no reference line in tools/shots/ink_ref.tsv for these photos yet (they are new), so a photo whose sample
handwriting was loaded but not drawn (docs/M7D.md, D0b: whole PencilKit tiles not shown, at times on the first photo
after a boot, at times the same tiles at every launch on one host) could pass unseen. Three guards, none of them silent:

  1. In the job (the shots step, with tools/shots/ink_check.swift): a photo whose name has a line in ink_ref.tsv is
     checked against it ("ref"); a photo with none is taken twice (two launches, as the 6.9-inch set's two rounds) and the
     two takes are checked against each other both ways ("pair": two launches of a page draw the same pixels, so a take
     that lost handwriting is short against the other; duo-shots' runs 44696154794 and 44717450692, a day's runners
     apart, were 0 px short against each other on the paper of all 14 outer photos); either way at most 2 more takes,
     within 180 s a job (INK_BUDGET). The verdict of each photo goes into ink-status.tsv and the reference line of the
     photo kept into ink-ref.tsv.
  2. `check` (the job's last check): every photo of the job's sets is there, App Store's outer size, not black, no black
     band at an edge (tools/duo/shot_checks.py's `edges`: the app fills the screen), and its handwriting verdict is "ok"
     in mode ref or pair; otherwise the job fails.
  3. `across` (the job store-duo-check, after all the store-duo jobs): the same page of every language compared, for a
     host that loses the same tiles at every launch (that passes the pair check, on all the photos of its job alike).
     The handwriting is the same in every language (ScreenshotStoreInk.swift); the words, the holidays and the week start
     are not. So each photo is compared with the NEAR photos of its page most like it (in effect the same week start)
     among the other jobs' (other runners), on the paper's tiles where those agree; a photo short by MIN_SHORT pixels or
     more there fails, unless the job checked it against its reference line (mode "ref"). A loss that every runner makes
     alike, or a small one, is caught only by the reference lines.
So a photo that passed only in mode "pair" is not proven complete (a loss that repeats at every launch and is under
MIN_SHORT, or one every runner makes, the whole handwriting too, passes all three). It is never passed silently: `check`
and `across` each print a ::warning:: naming how many such photos there are (and `check` the runner's macOS, D0b's
losses being on macOS 27.2 hosts), and `across` prints the largest shortfall of a photo that passed, the noise that
MIN_SHORT has to stay above on the Duo.
The lead adds the lines of ink-ref.tsv to tools/shots/ink_ref.tsv after looking at the photos (§7.1: the owner's page
too); from then on guard 1 is the strong one ("ref"), as for build.yml's photos.

  python3 -I tools/shots/duo_store.py check <store dir> <ink-status.tsv> <set id>… [--host <the runner's macOS version>]
  python3 -I tools/shots/duo_store.py across <expected set ids, space-separated> <job>/ink-ref.tsv… [--status <ink-status.tsv>…]
  python3 -I tools/shots/duo_store.py --self-test

<store dir> holds <set>/duoOuter/<nn>-<page>.jpg. ink-status.tsv: name, mode (ref|pair), status
(ok|short|unverified|error), the take kept, the takes, pixels short, a note; tab-separated, one line a photo, the name
"store-duo/<set>/<nn>-<page>.png". ink-ref.tsv: `ink_check ref` lines of the photos kept, under the same names; the
folder that holds it names the job (env-store-duo-<group>), and a photo is never compared with one of its own job.
Standard library only; `check` reads each photo with tools/duo/shot_checks.py (imported; sips). The lines that the
upload's script (§7.2) reads keep their form: a check row's last column ("ok" or why not), the last lines "store-duo
check: …" and "store-duo across: …", and each across line. Exit 0: all good, 1: a photo fails, 2: the arguments or the
files cannot be read.
"""
import os
import re
import shutil
import statistics
import struct
import sys
import tempfile

PAGES = ("00-span", "01-week", "02-month", "03-day", "04-year")   # the 6.9-inch set's five, in its order (§7.1)
DEVICE = "duoOuter"
OUTER = (1398, 2034)                 # App Store's iPhone Duo outer screen, portrait (§7.1 [S13]); store-shots' accepted()
# The outer screen's paper in portrait, in tools/shots/ink_check.swift's 48 px tiles, both ends included: x 0–1151 (the
# paper is 1146 px wide, 382 pt; the status bar's strip, 84 pt, is right of it), y 288–1727 (the header ends at 258 and
# the paper starts at 273, the toolbar starts at 1734; duo-shots run 44717450692, every page alike). The header's words
# and the toolbar's labels differ by language and are left out.
PAPER = (0, 6, 23, 35)
NEAR = 3                             # the photos of the same page a photo is compared with (of other jobs, the most like it)
AGREE = (0.6, 1.6)                   # a tile is compared when each of them is within these times their median
MIN_COUNT = 20                       # and that median is at least this (ink_check's own floor for a tile)
# A photo fails `across` when its paper tiles miss this many pixels together (a tile counts when it fell under half of the
# median and by 8 or more, ink_check's rule, with what its 8 neighbours gained over their median). Measured with this
# rule on 1.3's complete 6.9-inch store photos (run 44454683829, 12 sets × 5 pages, the jobs of store-duo): at most 948 px
# short (zh-Hans' 04-year; then 840, 829, 524), 0 for 34 of the 60. A block of 10 × 10 tiles taken out (482 px, about one
# PencilKit tile of 512 lu on that screen) of one photo, or of all three of a job, was caught 98–99 % of the times it held
# 2,000 px or more, 95 % at 1,500–2,000, 68 % at 1,000–1,500 and 7–8 % at 300–1,000 (what is missed sits on tiles where
# the languages differ). The outer screen's paper is 13 % narrower than that screen's, its noise likely smaller too, but
# not measured: no Duo photo with the store handwriting had been taken (duo.yml does not pass --screenshot-store-ink).
# `across` prints the largest shortfall of the photos that pass; after the first run, compare it with this and set this
# again from the Duo's 60. A photo failed here that is complete (looked at) is cleared by adding its line of its job's
# ink-ref.tsv to tools/shots/ink_ref.tsv (then its job checks it against that line, and this does not fail it).
MIN_SHORT = 1200
BLACK_MEAN = 10.0                    # tools/duo/shot_checks.py's black (§3.8; the self-test checks that it is the same)
MACOS_LOSSES = re.compile(r"27\.2(\.|$)")  # the runner's macOS of D0b's losses (docs/M7D.md, D0b: image 20261119)


def name_of(set_id, page):
    return "store-duo/%s/%s.png" % (set_id, page)


# ── reading ──────────────────────────────────────────────────────────────────────────────────────────────────────────

def image_size(path):
    """(width, height) of a PNG or a JPEG from its header; ValueError when it is neither."""
    with open(path, "rb") as f:
        data = f.read(65536)
        if data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR":
            return struct.unpack(">II", data[16:24])
        if data[:2] != b"\xff\xd8":
            raise ValueError("not a PNG or a JPEG")
        f.seek(2)
        while True:
            marker = f.read(2)
            if len(marker) < 2 or marker[0] != 0xFF:
                raise ValueError("no JPEG frame header")
            while marker[1] == 0xFF:                       # fill bytes
                marker = marker[1:] + f.read(1)
            kind = marker[1]
            if kind in (0xD8, 0x01) or 0xD0 <= kind <= 0xD7:
                continue
            length = f.read(2)
            if len(length) < 2:
                raise ValueError("a cut JPEG")
            size = struct.unpack(">H", length)[0]
            if 0xC0 <= kind <= 0xCF and kind not in (0xC4, 0xC8, 0xCC):
                body = f.read(5)
                if len(body) < 5:
                    raise ValueError("a cut JPEG frame header")
                height, width = struct.unpack(">HH", body[1:5])
                return width, height
            f.seek(size - 2, 1)


def shot_checks():
    """tools/duo/shot_checks.py as a module (its reader, its `black` and `edges`)."""
    folder = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "duo")
    if folder not in sys.path:
        sys.path.insert(0, folder)
    sys.dont_write_bytecode = True       # no __pycache__ left in the checkout
    import shot_checks as module
    return module


def shot_checks_look(path):
    """(mean luma, the edges that are a black band, None) of a photo, read as tools/duo/shot_checks.py reads duo-shots'
    (`black`, §3.8; `edges`, the app fills the screen, §6's C row, C13), or (None, None, why) when it cannot be read.
    The edges are looked at only when the photo is not black."""
    sc = shot_checks()
    try:
        image = sc.load(path)
        mean = image.mean_luma()
    except (sc.ShotError, OSError, struct.error) as error:
        return None, None, str(error)
    if mean < sc.BLACK_MEAN:
        return mean, [], None
    return mean, [e for e in ("left", "right", "top", "bottom") if image.edge_black(e)], None


def read_status(paths, errors):
    """name → (mode, status, kept, takes, short, note) of ink-status.tsv files; a later line of a name wins."""
    out = {}
    for path in paths:
        try:
            lines = open(path, encoding="utf-8").read().splitlines()
        except OSError as error:
            errors.append("%s: not readable (%s)" % (path, error))
            continue
        for line in lines:
            if not line.strip():
                continue
            fields = line.split("\t")
            if len(fields) < 6:
                errors.append("%s: a line with %d fields: %r" % (path, len(fields), line))
                continue
            out[fields[0]] = tuple(fields[1:6]) + (fields[6] if len(fields) > 6 else "",)
    return out


def read_refs(paths, errors, jobs=None):
    """name → {(x, y): pixels of the four ink classes together} inside PAPER, from `ink_check ref` lines; with `jobs`
    (a dict), name → the folder of its file (its job) too."""
    out = {}
    for path in paths:
        try:
            lines = open(path, encoding="utf-8").read().splitlines()
        except OSError as error:
            errors.append("%s: not readable (%s)" % (path, error))
            continue
        for line in lines:
            fields = line.split("\t")
            if len(fields) != 4:
                if line.strip():
                    errors.append("%s: not a reference line: %r" % (path, line[:80]))
                continue
            name, size = fields[0], fields[1]
            if size != "%dx%d" % OUTER:
                errors.append("%s: %s is %s, not %dx%d" % (path, name, size, OUTER[0], OUTER[1]))
                continue
            tiles = {}
            for item in fields[3].split(";"):
                parts = item.split(",")
                if len(parts) != 4:
                    continue
                try:
                    x, y, _, n = (int(p) for p in parts)
                except ValueError:
                    continue
                if PAPER[0] <= x <= PAPER[2] and PAPER[1] <= y <= PAPER[3]:
                    tiles[(x, y)] = tiles.get((x, y), 0) + n
            out[name] = tiles
            if jobs is not None:
                jobs[name] = os.path.basename(os.path.dirname(os.path.abspath(path)))
    return out


# ── check: one job's photos ─────────────────────────────────────────────────────────────────────────────────────────

def check(store, status_path, sets, look=shot_checks_look, host="", out=sys.stdout):
    """The job's last check (docs/M7D_CONTRACT.md §7.1, §3.8). Returns the number of photos that fail. `host`: the
    runner's macOS version (sw_vers), for the warning on the photos checked only in mode "pair"."""
    errors = []
    status = read_status([status_path], errors)
    for error in errors:
        print("::error::%s" % error, file=out)
    failed = len(errors)
    pair_only = []
    print("photo | size | mean luma | edges | handwriting (mode, status, kept take of takes, px short) | verdict", file=out)
    for set_id in sets:
        for page in PAGES:
            path = os.path.join(store, set_id, DEVICE, page + ".jpg")
            name = name_of(set_id, page)
            why = []
            size = mean = edges = "-"
            if not os.path.isfile(path):
                why.append("missing")
            else:
                try:
                    w, h = image_size(path)
                    size = "%dx%d" % (w, h)
                    if (w, h) != OUTER:
                        why.append("%s is not App Store's %dx%d" % (size, OUTER[0], OUTER[1]))
                except (OSError, ValueError, struct.error) as error:
                    why.append("size not readable (%s)" % error)
                value, black_edges, unread = look(path)
                if value is None:
                    why.append("not readable (%s)" % unread)
                else:
                    mean = "%.1f" % value
                    if value < BLACK_MEAN:
                        why.append("black (mean luma %.1f < %.0f)" % (value, BLACK_MEAN))
                    elif black_edges:
                        edges = "black " + ",".join(black_edges)
                        why.append("a black band at the %s edge%s: the app does not fill the screen (shot_checks.py edges; §6's C row, C13)"
                                   % (" and ".join(black_edges), "s" if len(black_edges) > 1 else ""))
                    else:
                        edges = "ok"
            ink = status.get(name)
            if ink is None:
                why.append("no handwriting verdict")
                ink_text = "-"
            else:
                mode, verdict, kept, takes, short, note = ink
                ink_text = "%s, %s, take %s of %s, %s px short%s" % (mode, verdict, kept, takes, short, (": " + note) if note else "")
                if mode not in ("ref", "pair"):
                    why.append("handwriting checked in no known mode (%r)" % mode)
                elif verdict != "ok":
                    why.append("handwriting %s (%s)" % (verdict, note or mode))
                elif mode == "pair":
                    pair_only.append(name)
            print("%s/%s/%s.jpg | %s | %s | %s | %s | %s" % (set_id, DEVICE, page, size, mean, edges, ink_text, "; ".join(why) or "ok"), file=out)
            if why:
                failed += 1
                print("::error::store-duo %s/%s/%s.jpg: %s (docs/M7D_CONTRACT.md §7.1, §3.8)." % (set_id, DEVICE, page, "; ".join(why)), file=out)
    expected = len(sets) * len(PAGES)
    if pair_only:
        where = ""
        if host:
            where = " This runner is macOS %s%s." % (host, ", the macOS of D0b's losses (docs/M7D.md, D0b: the same tiles lost at every "
                                                     "launch on one host)" if MACOS_LOSSES.match(host) else "")
        print("::warning::store-duo: %d of %d photos have their handwriting checked only take against take (no line in "
              "tools/shots/ink_ref.tsv; ink-status.tsv mode pair): a loss that repeats at every launch, or that every runner makes "
              "(the whole handwriting too), passes here, and store-duo-check fails only one of %d px or more that the other jobs "
              "do not share.%s Look at each photo before the upload (§7.1: and the owner's page), then add the lines of "
              "env-store-duo-<group>/ink-ref.tsv to tools/shots/ink_ref.tsv." % (len(pair_only), expected, MIN_SHORT, where), file=out)
    print("store-duo check: %d photos expected, %d fail: %s" % (expected, failed, "ok" if failed == 0 else "FAILED"), file=out)
    return failed


# ── across: the same page of every language ─────────────────────────────────────────────────────────────────────────

def likeness(a, b):
    keys = set(a) | set(b)
    top = sum(max(a.get(k, 0), b.get(k, 0)) for k in keys)
    return sum(min(a.get(k, 0), b.get(k, 0)) for k in keys) / top if top else 0.0


def short_against(now, others):
    """(pixels short, tiles short, tiles compared) of `now` against the median of `others` (ink_check's rule)."""
    keys = set().union(*[set(o) for o in others]) if others else set()
    median = {}
    agreed = {}
    for k in keys:
        values = [o.get(k, 0) for o in others]
        m = statistics.median(values)
        median[k] = m
        if m >= MIN_COUNT and all(AGREE[0] * m <= v <= AGREE[1] * m for v in values):
            agreed[k] = m
    missing = tiles = 0
    for (x, y), ref in agreed.items():
        gained = 0
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx or dy:
                    near = (x + dx, y + dy)
                    gained += max(0, now.get(near, 0) - median.get(near, 0))
        got = now.get((x, y), 0) + gained
        if ref - got >= 8 and got * 2 < ref:
            missing += ref - got
            tiles += 1
    return int(missing), tiles, len(agreed)


def across(sets, refs, jobs, status=None, out=sys.stdout):
    """The same page compared across the languages, each photo with photos of other jobs only (`jobs`: name → job).
    Returns the number of failures (photos short, missing, or with fewer than 2 photos of other jobs to compare with)."""
    failed = 0
    noise = (-1, "")                     # the largest shortfall of a photo that passed here (MIN_SHORT's margin)
    unproven = []                        # photos compared here that their job did not check against a reference line
    seen = 0                             # photos compared here
    for page in PAGES:
        names = [name_of(s, page) for s in sets]
        here = [n for n in names if n in refs]
        for n in names:
            if n not in refs:
                failed += 1
                print("::error::%s: no reference line (the photo was not taken or not kept; its job's ink-ref.tsv)." % n, file=out)
        print("== %s: %d of %d languages" % (page, len(here), len(names)), file=out)
        for n in here:
            others = [m for m in here if m != n and jobs.get(m) != jobs.get(n)]
            if len(others) < 2:
                failed += 1
                print("::error::%s: fewer than 2 photos of %s from other jobs; its handwriting is not compared across the languages." % (n, page), file=out)
                continue
            ranked = sorted(((likeness(refs[n], refs[m]), m) for m in others), reverse=True)[:NEAR]
            missing, tiles, compared = short_against(refs[n], [refs[m] for _, m in ranked])
            near = ",".join(m.split("/")[1] for _, m in ranked)
            bad = missing >= MIN_SHORT
            note = ""
            if status is not None and n in status:
                note = " (in the job: %s, %s)" % (status[n][0], status[n][1])
                if bad and status[n][:2] == ("ref", "ok"):
                    bad = False
                    note += "; complete against its reference line, which decides"
            print("%-28s %6d px short in %3d of %3d tiles; compared with %s: %s%s"
                  % (n, missing, tiles, compared, near, "SHORT" if bad else "ok", note), file=out)
            seen += 1
            if status is None or status.get(n, ("",))[0] != "ref":
                unproven.append(n)
            if bad:
                failed += 1
                print("::error::%s: its handwriting is %d px short against the same page of %s (at least %d fails; docs/M7D.md, D0b). "
                      "Look at the photo: take that job again, or, the photo being complete, add its line of its job's ink-ref.tsv to "
                      "tools/shots/ink_ref.tsv (MIN_SHORT is from 1.3's 6.9-inch photos)." % (n, missing, near, MIN_SHORT), file=out)
            elif missing > noise[0]:
                noise = (missing, n)
    if noise[0] >= 0:
        print("store-duo across: the largest shortfall of a photo that passed: %d px (%s); a photo fails at %d (MIN_SHORT, set "
              "from 1.3's 6.9-inch photos, whose largest was 948)." % (noise[0], noise[1], MIN_SHORT), file=out)
    if unproven:
        print("::warning::store-duo across: %d of the %d photos compared were not checked against a reference line in their job "
              "(mode pair%s): here a photo fails only %d px or more short against the other jobs' same page, so a smaller loss, or "
              "one every runner makes alike (the whole handwriting too), passes. Look at them before the upload (§7.1), then add "
              "the jobs' ink-ref.tsv lines to tools/shots/ink_ref.tsv."
              % (len(unproven), seen, "" if status is not None else "; no ink-status.tsv given", MIN_SHORT), file=out)
    print("store-duo across: %d failures: %s" % (failed, "ok" if failed == 0 else "FAILED"), file=out)
    return failed


# ── self-test ────────────────────────────────────────────────────────────────────────────────────────────────────────

class _Rand:
    """A fixed pseudo-random sequence (the same at every run)."""

    def __init__(self, seed):
        self.state = seed

    def next(self, n):
        self.state = (self.state * 1103515245 + 12345) % 2147483648
        return self.state % n


def _tiles_line(name, tiles):
    items = ";".join("%d,%d,0,%d" % (x, y, n) for (x, y), n in sorted(tiles.items()) if n >= MIN_COUNT)
    return "%s\t%dx%d\t64\t%s" % (name, OUTER[0], OUTER[1], items)


def _made_up_pages(sets):
    """Tile maps like the real ones: the same strokes on every language (shifted by four tiles, a column, for the
    second week start), the words of each language on tiles of their own, and the shared words (the day numbers)."""
    strokes = {}
    rand = _Rand(7)
    while len(strokes) < 110:
        x, y = 1 + rand.next(18), PAPER[1] + rand.next(PAPER[3] - PAPER[1] + 1)
        strokes[(x, y)] = 40 + rand.next(300)
    pages = {}
    for i, set_id in enumerate(sets):
        shift = 4 if i % 2 else 0
        tiles = {}
        for (x, y), n in strokes.items():
            tiles[(x + shift, y)] = n
        for y in range(PAPER[1], PAPER[3] + 1, 4):              # the numbers of the days: the same in every language
            tiles[(0, y)] = tiles.get((0, y), 0) + 120
        words = _Rand(100 + i)
        for _ in range(25):                                      # words: a language's own
            k = (words.next(PAPER[2] + 1), PAPER[1] + words.next(PAPER[3] - PAPER[1] + 1))
            tiles[k] = tiles.get(k, 0) + 30 + words.next(200)
        pages[set_id] = tiles
    return pages


def self_test():
    tmp = tempfile.mkdtemp(prefix="duo-store-test-")
    try:
        return _self_test(tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _self_test(tmp):
    failures = []

    def verdict(what, ok, detail=""):
        print("%s %s%s" % ("ok  " if ok else "FAIL", what, (": " + detail) if detail else ""))
        if not ok:
            failures.append(what)

    sets = ["s%02d" % i for i in range(12)]

    # across: complete photos pass; one with a lost PencilKit tile (about 9 × 9 of ink_check's tiles on the outer screen's
    # week) fails, and so do the three of a job that lost the same tile (one runner); a few pixels less do not (the floor
    # is MIN_SHORT); a missing photo fails; a photo with no other job to compare with fails.
    job_of = dict((s, "env-store-duo-%d" % (1 + i // 3)) for i, s in enumerate(sets))

    def refs_with(change=None, only=None):
        pages = _made_up_pages(sets)
        folder = os.path.join(tmp, "across-%d" % len(os.listdir(tmp)))
        lines = {}
        for page in PAGES:
            for s in sets:
                if only and job_of[s] != only:
                    continue
                tiles = dict(pages[s])
                if change:
                    tiles = change(page, s, tiles)
                lines.setdefault(job_of[s], []).append(_tiles_line(name_of(s, page), tiles))
        paths = []
        for job, rows in sorted(lines.items()):
            os.makedirs(os.path.join(folder, job))
            paths.append(os.path.join(folder, job, "ink-ref.tsv"))
            with open(paths[-1], "w", encoding="utf-8") as f:
                f.write("\n".join(rows) + "\n")
        errors, jobs = [], {}
        refs = read_refs(paths, errors, jobs)
        return refs, jobs, errors

    def said(fn, *args):
        """(what fn returns, the lines it printed)."""
        lines = []

        class Sink:
            def write(self, text):
                lines.append(text)
        result = fn(*args, out=Sink())
        return result, "".join(lines).splitlines()

    def quiet(fn, *args):
        return said(fn, *args)[0]

    refs, jobs, errors = refs_with()
    verdict("the made-up reference lines read, with their jobs", not errors and len(refs) == 60 and len(set(jobs.values())) == 4,
            "; ".join(errors))
    verdict("across: 12 complete languages pass", quiet(across, sets, refs, jobs) == 0)

    def block(tiles):
        return dict((k, v) for k, v in tiles.items() if not (6 <= k[0] <= 14 and 10 <= k[1] <= 18))

    refs, jobs, _ = refs_with(lambda page, s, tiles: block(tiles) if (page, s) == ("01-week", "s03") else tiles)
    missing = short_against(refs[name_of("s03", "01-week")], [refs[name_of(s, "01-week")] for s in ("s01", "s07", "s09")])[0]
    verdict("across: a lost 9 × 9 block of ink fails", quiet(across, sets, refs, jobs) == 1, "%d px short" % missing)

    refs, jobs, _ = refs_with(lambda page, s, tiles: block(tiles) if page == "03-day" and job_of[s] == job_of["s06"] else tiles)
    verdict("across: the same block lost by the three photos of one job fails all three", quiet(across, sets, refs, jobs) == 3)
    ref_ok = {name_of("s06", "03-day"): ("ref", "ok", "2", "2", "0", ""), name_of("s07", "03-day"): ("pair", "ok", "2", "2", "0", "")}
    verdict("across: but not one the job found complete against its reference line", quiet(across, sets, refs, jobs, ref_ok) == 2)

    refs, jobs, _ = refs_with(lambda page, s, tiles: dict((k, v if k[0] == 0 else v // 4) for k, v in tiles.items())
                              if (page, s) == ("03-day", "s08") else tiles)
    verdict("across: a page drawn at a quarter fails", quiet(across, sets, refs, jobs) == 1)

    def lose_little(page, s, tiles):
        if (page, s) == ("02-month", "s04"):
            tiles = dict(tiles)
            tiles[sorted(k for k in tiles if k[0] != 0)[0]] = 0
        return tiles
    refs, jobs, _ = refs_with(lose_little)
    verdict("across: one tile less (under %d px) passes (the floor)" % MIN_SHORT, quiet(across, sets, refs, jobs) == 0)

    # Nothing passes silently that its job checked only take against take: one warning, and the largest shortfall that
    # passed (the noise MIN_SHORT must stay above); none when every photo was checked against its reference line. The
    # last line keeps the form the upload's script reads.
    refs, jobs, _ = refs_with(lose_little)
    pair = dict((name_of(s, p), ("pair", "ok", "2", "2", "0", "")) for s in sets for p in PAGES)
    got, text = said(across, sets, refs, jobs, pair)
    warned = [line for line in text if line.startswith("::warning::")]
    verdict("across: photos checked in their job only take against take pass with one warning naming how many",
            got == 0 and len(warned) == 1 and "60 of the 60 photos" in warned[0], "; ".join(warned))
    verdict("across: it prints the largest shortfall of a photo that passed",
            any(line.startswith("store-duo across: the largest shortfall of a photo that passed: ") and "store-duo/s04/02-month.png" in line
                for line in text))
    got, text = said(across, sets, refs, jobs)
    verdict("across: with no ink-status.tsv every photo counts as unproven", got == 0 and any("60 of the 60 photos" in line for line in text))
    ref = dict((name_of(s, p), ("ref", "ok", "2", "2", "0", "")) for s in sets for p in PAGES)
    got, text = said(across, sets, refs, jobs, ref)
    verdict("across: photos checked against their reference lines give no warning",
            got == 0 and not [line for line in text if line.startswith("::warning::")])
    verdict("across: its last line is 'store-duo across: N failures: ok|FAILED'",
            re.match(r"store-duo across: \d+ failures: (ok|FAILED)$", text[-1]) is not None, text[-1])

    refs, jobs, _ = refs_with()
    del refs[name_of("s11", "04-year")]
    verdict("across: a missing photo fails", quiet(across, sets, refs, jobs) == 1)
    refs, jobs, _ = refs_with(only=job_of["s00"])
    verdict("across: photos with no other job to compare with fail (and the 9 photos of the jobs missing)",
            quiet(across, sets, refs, jobs) == 15 + 45)

    # check: sizes from the headers; the luma is given (shot_checks.py has its own self-test).
    def png_header(w, h):
        return b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0) + b"\0" * 4

    def jpeg_header(w, h):
        app0 = b"\xff\xe0" + struct.pack(">H", 16) + b"JFIF\0" + b"\x01\x01\0\0\x01\0\x01\0\0"
        sof = b"\xff\xc0" + struct.pack(">HBHHB", 17, 8, h, w, 3) + b"\x01\x22\0\x02\x11\x01\x03\x11\x01"
        return b"\xff\xd8" + app0 + sof + b"\xff\xd9"

    sizes = []
    for maker, w, h in ((png_header, 1398, 2034), (jpeg_header, 1398, 2034), (jpeg_header, 1397, 2034)):
        path = os.path.join(tmp, "size.bin")
        with open(path, "wb") as f:
            f.write(maker(w, h))
        sizes.append(image_size(path))
    verdict("image_size reads a PNG's and a JPEG's header", sizes == [(1398, 2034), (1398, 2034), (1397, 2034)], str(sizes))

    def write_job(folder, sets_here, size=OUTER, statuses=None, skip=None, mode="pair"):
        store = os.path.join(folder, "store")
        lines = []
        for s in sets_here:
            os.makedirs(os.path.join(store, s, DEVICE), exist_ok=True)
            for page in PAGES:
                if skip == (s, page):
                    continue
                with open(os.path.join(store, s, DEVICE, page + ".jpg"), "wb") as f:
                    f.write(jpeg_header(*size))
                st = (statuses or {}).get((s, page), "ok")
                lines.append("\t".join([name_of(s, page), mode, st, "2", "2", "0", ""]))
        status = os.path.join(folder, "ink-status.tsv")
        with open(status, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        return store, status

    def lit(_):
        return 243.8, [], None

    def dark(path):
        return (0.0, [], None) if path.endswith("03-day.jpg") else lit(path)

    def banded(path):
        return (180.0, ["left", "right"], None) if path.endswith("01-week.jpg") else lit(path)

    def unreadable(_):
        return None, None, "sips could not read it"

    job = ["en", "en-GB", "ja"]
    store, status = write_job(os.path.join(tmp, "good"), job)
    verdict("check: a complete job passes", quiet(check, store, status, job, lit) == 0)
    verdict("check: a black photo fails", quiet(check, store, status, job, dark) == 3)
    verdict("check: a photo with a black band at its edges fails (the app does not fill the screen)",
            quiet(check, store, status, job, banded) == 3)
    verdict("check: a photo that cannot be read fails", quiet(check, store, status, job, unreadable) == 15)
    got, text = said(check, store, status, job, lit, "27.2")
    warned = [line for line in text if line.startswith("::warning::")]
    verdict("check: photos checked only take against take pass with one warning naming how many and D0b's macOS",
            got == 0 and len(warned) == 1 and "15 of 15 photos" in warned[0] and "macOS 27.2, the macOS of D0b" in warned[0], "; ".join(warned))
    rows = [line.split(" | ") for line in text if " | " in line and not line.startswith("photo | ")]
    verdict("check: its rows and its last line keep the form the upload's script reads",
            len(rows) == 15 and all(len(r) >= 5 and r[-1] == "ok" for r in rows)
            and re.match(r"store-duo check: \d+ photos expected, \d+ fail: (ok|FAILED)$", text[-1]) is not None, text[-1])
    got, text = said(check, store, status, job, lit, "27.0.1")
    verdict("check: on another macOS the warning names it without D0b", got == 0
            and any("macOS 27.0.1." in line and "D0b's macOS" not in line and "the macOS of D0b" not in line for line in text))
    store, status = write_job(os.path.join(tmp, "ref"), job, mode="ref")
    got, text = said(check, store, status, job, lit, "27.2")
    verdict("check: photos checked against their reference lines give no warning",
            got == 0 and not [line for line in text if line.startswith("::warning::")])
    store, status = write_job(os.path.join(tmp, "mode"), job, mode="guess")
    verdict("check: a verdict in no known mode fails", quiet(check, store, status, job, lit) == 15)

    # The reader is tools/duo/shot_checks.py's (its own self-test has its photos): a letterboxed page shows its bands, a
    # light one none, a black one only its mean.
    sc = shot_checks()
    verdict("BLACK_MEAN is tools/duo/shot_checks.py's", BLACK_MEAN == sc.BLACK_MEAN, "%s, %s" % (BLACK_MEAN, sc.BLACK_MEAN))
    looks = []
    for name, kwargs in (("band.png", {"band": 12}), ("light.png", {}), ("black.png", {"everything": sc.BLACK})):
        path = os.path.join(tmp, name)
        sc.paper_photo(path, 120, 180, **kwargs)
        value, black_edges, unread = shot_checks_look(path)
        looks.append((name, value is not None and value >= BLACK_MEAN, black_edges, unread))
    verdict("shot_checks_look: a band at the left and right, none on a light page, a black page only black",
            looks == [("band.png", True, ["left", "right"], None), ("light.png", True, [], None), ("black.png", False, [], None)],
            str(looks))
    verdict("shot_checks_look: a file that is no photo cannot be read",
            shot_checks_look(os.path.join(tmp, "size.bin"))[0] is None)
    store, status = write_job(os.path.join(tmp, "small"), job, size=(1398, 2033))
    verdict("check: a photo one pixel short of 1398x2034 fails", quiet(check, store, status, job, lit) == 15)
    store, status = write_job(os.path.join(tmp, "gone"), job, skip=("ja", "02-month"))
    verdict("check: a missing photo fails", quiet(check, store, status, job, lit) == 1)
    store, status = write_job(os.path.join(tmp, "ink"), job, statuses={("en", "00-span"): "unverified", ("ja", "04-year"): "short"})
    verdict("check: a photo whose handwriting is not ok fails", quiet(check, store, status, job, lit) == 2)
    store, status = write_job(os.path.join(tmp, "noink"), job)
    with open(status, "w", encoding="utf-8") as f:
        f.write("")
    verdict("check: no handwriting verdicts fail every photo", quiet(check, store, status, job, lit) == 15)
    verdict("check: a set the job did not shoot fails", quiet(check, store, status, ["fr"], lit) == 5)

    print("duo_store self-test: %d checks failed" % len(failures))
    return 1 if failures else 0


def main(argv):
    args = argv[1:]
    if args == ["--self-test"]:
        return self_test()
    if len(args) >= 4 and args[0] == "check":
        rest, host = args[3:], ""
        if "--host" in rest:
            at = rest.index("--host")
            if at + 1 >= len(rest):
                print(__doc__, file=sys.stderr)
                return 2
            host = rest[at + 1]
            rest = rest[:at] + rest[at + 2:]
        if not rest:
            print(__doc__, file=sys.stderr)
            return 2
        if not os.path.isdir(args[1]):
            print("::error::duo_store check: no folder %s" % args[1])
            return 2
        return 1 if check(args[1], args[2], rest, host=host) else 0
    if len(args) >= 3 and args[0] == "across":
        sets = args[1].split()
        rest = args[2:]
        refs_paths, status_paths = [], []
        while rest:
            if rest[0] == "--status":
                rest = rest[1:]
                while rest and not rest[0].startswith("--"):
                    status_paths.append(rest[0])
                    rest = rest[1:]
            else:
                refs_paths.append(rest[0])
                rest = rest[1:]
        errors, jobs = [], {}
        refs = read_refs(refs_paths, errors, jobs)
        status = read_status(status_paths, errors) if status_paths else None
        for error in errors:
            print("::error::%s" % error)
        if not sets or not refs_paths:
            print(__doc__, file=sys.stderr)
            return 2
        return 1 if across(sets, refs, jobs, status) or errors else 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
