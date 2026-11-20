#!/usr/bin/env python3
"""The checks on the iPhone Duo's photos of duo.yml's duo-shots (docs/M7D_CONTRACT.md §6's C row, §7.3, §3.8, §7.1, §4.2).

Inside the app nothing can tell that it fills the screen: in the compatibility view ("真ん中に小さく", what 1.3 built with
the old SDK shows on a Duo) the window the app sees is small too (C13). So the photos decide, and each photo of duo-shots
is checked here:

  black       the mean luma (0–255) is at least 10: a Duo's photos are black for minutes after a boot (27.2, 187146039,
              §3.8; duo.yml waits 180 s and takes a black photo again 30 s later, three times at most, with `black`)
  edges       none of the four edges is black (each of its outermost 4 lines of pixels at least 99 % dark, luma ≤ 24):
              the app fills the screen, no black band around it ("端の列が全部黒でない")
  size        a photo of the Duo is one of App Store's sizes for that screen (§7.1 [S13]): the outer screen 1398×2034
              (landscape 2034×1398), the inner 2007×2853 or 1878×2670 (the screen's pixels, enlarged for the store) and
              their landscapes; `--size-rule warn` makes a wrong size a warning ("ほかの寸法なら警告して使わない")
  measure     each photo's launch wrote at least one well-formed `duo measure:` line (§2.1, --screenshot-measure), and
              there are photos of every kind (week, day, month, year) in portrait and landscape on every Duo screen
              photographed (outer; inner with --inner), the three sheets, the two overviews, the first launch on each Duo
              screen and the iPhone 17's one first launch
  values      what §4.2, §4.7, §4.8 and §7.3 expect of the lines: a landscape photo has a line with a landscape window;
              the outer screen is not wide and the inner is (§4.2, §4.7), the Duo's plan is never an iPad's (§4.6), the
              outer portrait header has two rows and the inner one (§4.8 4); with --screenshot-pencil-phone 「指でも書く」 is
              off (§7.3); the outer landscape overview of the week and the day is capped at 3 and 5 pages (capped=true),
              the inner's is not (§4.7); the iPhone 17's first launch has 「指でも書く」 on and hinge=nil (§7.3); a Duo's
              first launch has it off exactly when PencilPhone.usesHinge is true and its screen's hinge is not nil (§4.8,
              given as --uses-hinge true|false once §4.2's measurement decided it; `unknown` only records)
  rule        with --uses-hinge true|false, §4.2's rule still holds for the lines: usesHinge is true exactly when a Duo
              screen's hinge= is not nil (nor off) and the iPhone 17's is nil; when it no longer does, the constant is to
              be decided again (PencilPhone.usesHinge, DuoLayoutUITests, duo.yml's DUO_USES_HINGE; 1.4 D1c)

The folder holds the photos, `shots.tsv` (one row per photo: file, screen outer|inner|iphone, orientation
portrait|landscape, kind week|day|month|year, variant first|pencil|overview|sheet-settings|sheet-paywall|sheet-create;
a landscape photo is already stood up) and `measure.txt` (one row per line the photo's launch logged: file, then the line
from "duo measure:" on). The line's fields (§2.1): window=<w>x<h> safe=<t,l,b,r> scale=<s> screen=<w>x<h> header=<1|2>
paper=<w>x<h> plan=<class>,<orient> cap=<on|off> V=<v> R=<r> maxPages=<n|nil> capped=<bool> wide=<bool>
hinge=<closed|partiallyOpen|fullyOpen|unknown|nil|off> origin=<app|carried|moved|person> finger=<bool>; plan, V and R may
also be nil (a page of the one-page path has no span plan), and fields the contract does not name are ignored.

  python3 -I tools/duo/shot_checks.py check <folder> [--inner] [--uses-hinge true|false|unknown] [--size-rule fail|warn]
  python3 -I tools/duo/shot_checks.py black <photo>     exit 0: black (take it again), 1: not black, 2: not readable
  python3 -I tools/duo/shot_checks.py --self-test       the checks tried on made-up photos and lines (§6: they must fail)

Standard library only. A photo is read through `sips` (macOS) as a BMP, else by the PNG reader here (slower). Never writes
in the folder.
"""
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

BLACK_MEAN = 10.0        # a photo whose mean luma is below this is black (§3.8)
DARK = 24                # a pixel at or below this luma is dark (the edges)
EDGE_LINES = 4           # an edge is black when each of its outermost 4 lines is
EDGE_DARK_SHARE = 0.99   # at least 99 % dark (a black band, not a dark corner or a 1-pixel border)
KINDS = ("week", "day", "month", "year")
ORIENTS = ("portrait", "landscape")
SHEETS = ("sheet-settings", "sheet-paywall", "sheet-create")
VARIANTS = ("first", "pencil", "overview") + SHEETS
SCREENS = ("outer", "inner", "iphone")
# App Store's sizes for the Duo's two screens (§7.1 [S13]); the inner screen's 1878×2670 is its pixels ([S18]), which
# store-shots enlarges to 2007×2853 with sips.
SIZES = {
    "outer": {"portrait": [(1398, 2034)], "landscape": [(2034, 1398)]},
    "inner": {"portrait": [(2007, 2853), (1878, 2670)], "landscape": [(2853, 2007), (2670, 1878)]},
}
CAPPED_PAGES = {"week": "3", "day": "5"}   # §4.7 (P-B6 イ): the iPhone's landscape overview cap

NUM = r"-?[0-9]+(?:\.[0-9]+)?"
FIELDS = {
    "window": r"%sx%s" % (NUM, NUM),
    "safe": r"%s(?:,%s){3}" % (NUM, NUM),
    "scale": NUM,
    "screen": r"%sx%s" % (NUM, NUM),
    "header": r"[12]",
    "paper": r"%sx%s" % (NUM, NUM),
    "plan": r"[A-Za-z][A-Za-z0-9]*,(?:portrait|landscape)|nil",
    "cap": r"on|off",
    "V": r"%s|nil" % NUM,
    "R": r"%s|nil" % NUM,
    "maxPages": r"[0-9]+|nil",
    "capped": r"true|false",
    "wide": r"true|false",
    "hinge": r"closed|partiallyOpen|fullyOpen|unknown|nil|off",
    "origin": r"app|carried|moved|person",
    "finger": r"true|false",
}
NO_HINGE = ("nil", "off")   # no hinge on that screen / no API (before iOS 27.1, Mac Catalyst)


class ShotError(Exception):
    pass


# ── reading a photo ───────────────────────────────────────────────────────────────────────────────────────────────

class Image:
    """Pixels in one buffer: `bpp` bytes a pixel, the red, green and blue bytes at `offsets` in it, rows `stride` apart
    from `start`, top row first unless `bottom_up`."""

    def __init__(self, width, height, data, start, stride, bpp, offsets, bottom_up=False):
        self.width, self.height = width, height
        self.data, self.start, self.stride, self.bpp, self.offsets = data, start, stride, bpp, offsets
        self.bottom_up = bottom_up
        self._mean, self._edges = None, {}
        if width <= 0 or height <= 0 or len(data) < start + stride * height or stride < width * bpp:
            raise ShotError("the pixels are not all there (%dx%d)" % (width, height))

    def _row_start(self, y):
        return self.start + (self.height - 1 - y if self.bottom_up else y) * self.stride

    def mean_luma(self):
        if self._mean is None:
            self._mean = self._mean_luma()
        return self._mean

    def _mean_luma(self):
        w, h, bpp = self.width, self.height, self.bpp
        if self.stride == w * bpp:
            region = self.data[self.start:self.start + self.stride * h]
            sums = [sum(region[o::bpp]) for o in self.offsets]
        else:
            sums = [0, 0, 0]
            for y in range(h):
                s = self._row_start(y)
                row = self.data[s:s + w * bpp]
                for i, o in enumerate(self.offsets):
                    sums[i] += sum(row[o::bpp])
        return (0.299 * sums[0] + 0.587 * sums[1] + 0.114 * sums[2]) / (w * h)

    @staticmethod
    def _lumas(channels):
        return [(299 * r + 587 * g + 114 * b) // 1000 for r, g, b in zip(*channels)]

    def column(self, x):
        base = self.start + x * self.bpp
        end = self.start + self.stride * self.height
        return self._lumas([self.data[base + o:end:self.stride] for o in self.offsets])

    def row(self, y):
        s = self._row_start(y)
        return self._lumas([self.data[s + o:s + self.width * self.bpp:self.bpp] for o in self.offsets])

    def edge_black(self, edge):
        """True when each of the edge's outermost EDGE_LINES lines is at least EDGE_DARK_SHARE dark."""
        if edge not in self._edges:
            self._edges[edge] = self._edge_black(edge)
        return self._edges[edge]

    def _edge_black(self, edge):
        for k in range(min(EDGE_LINES, self.width if edge in ("left", "right") else self.height)):
            if edge == "left":
                line = self.column(k)
            elif edge == "right":
                line = self.column(self.width - 1 - k)
            elif edge == "top":
                line = self.row(k)
            else:
                line = self.row(self.height - 1 - k)
            if sum(1 for v in line if v <= DARK) < EDGE_DARK_SHARE * len(line):
                return False
        return True


def _u16(data, at):
    return struct.unpack_from("<H", data, at)[0]


def _u32(data, at):
    return struct.unpack_from("<I", data, at)[0]


def _s32(data, at):
    return struct.unpack_from("<i", data, at)[0]


def parse_bmp(data):
    """A BMP of 24 or 32 bits a pixel, plain or with byte masks (what `sips -s format bmp` writes: a V5 header, top row
    first, BGRA with masks)."""
    if len(data) < 54 or data[:2] != b"BM":
        raise ShotError("not a BMP")
    start, header = _u32(data, 10), _u32(data, 14)
    if header < 40:
        raise ShotError("a BMP header of %d bytes is not read here" % header)
    width, height, bits, compression = _s32(data, 18), _s32(data, 22), _u16(data, 28), _u32(data, 30)
    if bits not in (24, 32):
        raise ShotError("a BMP of %d bits a pixel is not read here" % bits)
    bpp = bits // 8
    if compression == 0:
        offsets = (2, 1, 0)
    elif compression in (3, 6):
        at = 54 if header >= 52 else 14 + header
        masks = [_u32(data, at), _u32(data, at + 4), _u32(data, at + 8)]
        offsets = []
        for mask in masks:
            byte = next((k for k in range(bpp) if mask == 0xFF << (8 * k)), None)
            if byte is None:
                raise ShotError("a BMP mask %#x is not one byte" % mask)
            offsets.append(byte)
        offsets = tuple(offsets)
    else:
        raise ShotError("a BMP compressed with %d is not read here" % compression)
    stride = (width * bits + 31) // 32 * 4
    return Image(width, abs(height), data, start, stride, bpp, offsets, bottom_up=height > 0)


def parse_png(data):
    """A PNG of 8 or 16 bits a channel (gray, gray and alpha, RGB, RGBA, a palette of 8 bits), not interlaced."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ShotError("not a PNG")
    at, idat, palette, header = 8, [], None, None
    while at + 8 <= len(data):
        length, kind = struct.unpack_from(">I4s", data, at)
        body = data[at + 8:at + 8 + length]
        at += 12 + length
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = body
        elif kind == b"IDAT":
            idat.append(body)
        elif kind == b"IEND":
            break
    if header is None:
        raise ShotError("a PNG without IHDR")
    width, height, depth, color, _, _, interlace = header
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color)
    if channels is None or depth not in (8, 16) or (color == 3 and depth != 8) or interlace:
        raise ShotError("a PNG of color type %d, %d bits, interlace %d is not read here" % (color, depth, interlace))
    bpp = channels * depth // 8
    stride = width * bpp
    try:
        raw = zlib.decompress(b"".join(idat))
    except zlib.error as error:
        raise ShotError("the PNG's data does not inflate (%s)" % error)
    if len(raw) < (stride + 1) * height:
        raise ShotError("the PNG's data is short")
    out = bytearray(stride * height)
    prev = bytearray(stride)
    p = 0
    for y in range(height):
        kind = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        if kind == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif kind == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif kind == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif kind == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xFF
        elif kind != 0:
            raise ShotError("a PNG row with the filter %d" % kind)
        out[y * stride:(y + 1) * stride] = line
        prev = line
    if depth == 16:   # the high byte of each sample
        out = out[0::2]
        bpp //= 2
    if color == 3:
        if palette is None:
            raise ShotError("a PNG with a palette type but no PLTE")
        padded = palette + bytes(768 - len(palette)) if len(palette) < 768 else palette[:768]
        rgb = bytearray(3 * width * height)
        for c in range(3):
            rgb[c::3] = bytes(out).translate(bytes(padded[3 * i + c] for i in range(256)))
        return Image(width, height, bytes(rgb), 0, 3 * width, 3, (0, 1, 2))
    offsets = (0, 0, 0) if color in (0, 4) else (0, 1, 2)
    return Image(width, height, bytes(out), 0, width * bpp, bpp, offsets)


_cache = {}


def load(path, use_sips=None):
    """The photo's pixels: through `sips` (a BMP) when it is there, else the PNG reader."""
    try:
        st = os.stat(path)
    except OSError as error:
        raise ShotError("no photo (%s)" % error.strerror)
    if use_sips is None:
        use_sips = shutil.which("sips") is not None
    key = (os.path.realpath(path), st.st_mtime_ns, st.st_size, use_sips)
    if key in _cache:
        return _cache[key]
    if use_sips:
        with tempfile.TemporaryDirectory(prefix="shot-checks-") as tmp:
            bmp = os.path.join(tmp, "photo.bmp")
            done = subprocess.run(["sips", "-s", "format", "bmp", path, "--out", bmp], capture_output=True, text=True)
            if done.returncode != 0 or not os.path.exists(bmp):
                raise ShotError("sips could not read it (%s)" % (done.stderr.strip() or done.stdout.strip() or done.returncode))
            with open(bmp, "rb") as f:
                image = parse_bmp(f.read())
    else:
        with open(path, "rb") as f:
            image = parse_png(f.read())
    _cache[key] = image
    return image


# ── the measure lines ─────────────────────────────────────────────────────────────────────────────────────────────

def parse_measure(line):
    """(fields, problems) of a `duo measure:` line (§2.1)."""
    at = line.find("duo measure:")
    if at < 0:
        return {}, ["no \"duo measure:\""]
    fields = {}
    for token in line[at + len("duo measure:"):].split():
        if "=" in token:
            key, value = token.split("=", 1)
            fields[key] = value
    problems = ["%s= is missing" % k for k in FIELDS if k not in fields]
    problems += ["%s=%s is not %s" % (k, fields[k], FIELDS[k]) for k in FIELDS if k in fields and not re.fullmatch(FIELDS[k], fields[k])]
    return fields, problems


def size_of(text):
    w, h = text.split("x")
    return float(w), float(h)


def window_orient(fields):
    w, h = size_of(fields["window"])
    return "landscape" if w > h else "portrait"


# ── the folder ────────────────────────────────────────────────────────────────────────────────────────────────────

def read_rows(folder, errors):
    rows = []
    path = os.path.join(folder, "shots.tsv")
    try:
        f = open(path, encoding="utf-8")
    except OSError as error:
        errors.append("shots.tsv cannot be read (%s): no photo was listed" % error.strerror)
        return rows
    with f:
        for number, line in enumerate(f, start=1):
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.split("\t")
            if (len(parts) != 5 or parts[1] not in SCREENS or parts[2] not in ORIENTS or parts[3] not in KINDS
                    or parts[4] not in VARIANTS):
                errors.append("shots.tsv:%d: not <file> <outer|inner|iphone> <portrait|landscape> <kind> <variant>: %s"
                              % (number, line.replace("\t", " | ")))
                continue
            rows.append(tuple(parts))
    return rows


def read_measure(folder):
    lines = {}
    try:
        with open(os.path.join(folder, "measure.txt"), encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if "\t" in line:
                    name, text = line.split("\t", 1)
                    lines.setdefault(name, []).append(text)
    except OSError:
        pass
    return lines


def check_folder(folder, inner=False, uses_hinge="unknown", size_rule="fail", use_sips=None):
    """(errors, warnings, notes, table rows)."""
    errors, warnings, notes, table = [], [], [], []
    rows = read_rows(folder, errors)
    measures = read_measure(folder)
    hinges = {"duo": [], "iphone": []}   # each photo's hinge= (its line's), for §4.2's rule
    for name, screen, orient, kind, variant in rows:
        tag = "%s (%s %s %s %s)" % (name, screen, orient, kind, variant)
        cell = {"file": name, "where": "%s %s %s %s" % (screen, orient, kind, variant), "size": "-", "mean": "-", "edges": "-"}
        # the photo
        try:
            image = load(os.path.join(folder, name), use_sips=use_sips)
        except (ShotError, OSError, struct.error) as error:
            errors.append("%s: the photo cannot be read: %s" % (tag, error))
            image = None
        if image is not None:
            mean = image.mean_luma()
            cell.update(size="%dx%d" % (image.width, image.height), mean="%.1f" % mean)
            if mean < BLACK_MEAN:
                errors.append("%s: black (mean luma %.1f < %.0f; §3.8: still black after the retakes)" % (tag, mean, BLACK_MEAN))
            else:
                black = [e for e in ("left", "right", "top", "bottom") if image.edge_black(e)]
                cell["edges"] = "black " + ",".join(black) if black else "ok"
                if black:
                    errors.append("%s: a black band at the %s edge%s: the app does not fill the screen (§6 C row, C13)"
                                  % (tag, " and ".join(black), "s" if len(black) > 1 else ""))
            if screen in SIZES and (image.width, image.height) not in SIZES[screen][orient]:
                text = ("%s: %dx%d is not App Store's size for the Duo's %s screen in %s (%s; §7.1)"
                        % (tag, image.width, image.height, screen, orient,
                           " or ".join("%dx%d" % s for s in SIZES[screen][orient])))
                (errors if size_rule == "fail" else warnings).append(text)
        # the lines
        valid = []
        for text in measures.get(name, []):
            fields, problems = parse_measure(text)
            if problems:
                errors.append("%s: a malformed duo measure: line (%s): %s" % (tag, "; ".join(problems), text))
            else:
                valid.append(fields)
        if not valid:
            errors.append("%s: no duo measure: line from its launch (§2.1, --screenshot-measure; the app appends it to "
                          "Library/Caches/duo-measure.txt in its data container, `log show` is the fallback; "
                          "measure-sources.tsv says where each photo's lines came from)" % tag)
            table.append(cell)
            continue
        turned = [f for f in valid if window_orient(f) == orient]
        if not turned:
            errors.append("%s: no line with a %s window (%s): the screen did not turn, or no line was written after it did"
                          % (tag, orient, ", ".join("window=" + f["window"] for f in valid)))
            table.append(cell)
            continue
        f = turned[-1]
        cell.update(f)
        hinges["iphone" if screen == "iphone" else "duo"].append(f["hinge"])

        def expect(key, want, why):
            if f[key] != want:
                errors.append("%s: %s=%s, expected %s (%s)" % (tag, key, f[key], want, why))

        if screen in ("outer", "inner") and f["plan"] != "nil" and f["plan"].lower().startswith("ipad"):
            errors.append("%s: plan=%s: the Duo's span plan is the iPhone's on both screens (§4.6)" % (tag, f["plan"]))
        if screen == "outer":
            expect("wide", "false", "§4.2, §4.7: the outer screen's short side is below 600 pt")
            if orient == "portrait":
                expect("header", "2", "§4.8 4, §7.3: the outer portrait header has two rows")
        elif screen == "inner":
            expect("wide", "true", "§4.2, §4.7: the inner screen's short side is 600 pt or more")
            expect("header", "1", "§4.8 4, §7.3: the inner header has one row")
        else:
            expect("wide", "false", "an ordinary iPhone's window is never wide (§4.7)")
        if variant in ("pencil", "overview") + SHEETS:
            expect("finger", "false", "§7.3: --screenshot-pencil-phone keeps 「指でも書く」 off")
        if variant == "overview":
            if screen == "outer":
                expect("cap", "on", "§4.7: the outer screen's landscape overview is capped")
                if kind in CAPPED_PAGES:
                    expect("maxPages", CAPPED_PAGES[kind], "§4.7, §7.3: the week 3 pages, the day 5")
                expect("capped", "true", "§4.7, §7.3: the capped overview (today opens an hour before now)")
            elif screen == "inner":
                expect("cap", "off", "§4.7: the wide window's plan has no cap")
                expect("maxPages", "nil", "§4.7: no cap on the inner screen")
                expect("capped", "false", "§4.7: the inner overview is not capped (today opens at 0:00)")
        if variant == "first":
            if screen == "iphone":
                expect("finger", "true", "§7.3: an ordinary iPhone keeps 1.3's 「指でも書く」 on")
                expect("hinge", "nil", "§4.2, §7.3: no hinge on the iPhone 17")
            elif uses_hinge in ("true", "false"):
                off = uses_hinge == "true" and f["hinge"] not in NO_HINGE
                expect("finger", "false" if off else "true",
                       "§4.8, §7.3: off exactly when PencilPhone.usesHinge (%s) and the screen's hinge (%s) is not nil"
                       % (uses_hinge, f["hinge"]))
            else:
                notes.append("%s: hinge=%s finger=%s (PencilPhone.usesHinge not given: recorded only; off is expected "
                             "exactly when usesHinge is true and hinge is not nil, §4.8)" % (tag, f["hinge"], f["finger"]))
        table.append(cell)
    # §4.2's rule against the constant given (1.4 D1c): usesHinge is true exactly when a Duo screen reads a hinge and the
    # iPhone 17 reads nil. Not looked at without Duo lines (the missing rows say so) or with `unknown`.
    if uses_hinge in ("true", "false") and hinges["duo"]:
        duo_reads = any(h not in NO_HINGE for h in hinges["duo"])
        iphone_nil = bool(hinges["iphone"]) and all(h == "nil" for h in hinges["iphone"])
        if (uses_hinge == "true") != (duo_reads and iphone_nil):
            errors.append("§4.2's rule: PencilPhone.usesHinge (--uses-hinge %s) is true exactly when a Duo screen's hinge= is "
                          "not nil and the iPhone 17's is nil; here the Duo's hinge= %s, the iPhone 17's %s: decide the constant "
                          "again (PencilPhone.usesHinge, DuoLayoutUITests, DUO_USES_HINGE)"
                          % (uses_hinge, "/".join(sorted(set(hinges["duo"]))), "/".join(sorted(set(hinges["iphone"]))) or "none"))
    # what must be there
    have = {(s, o, k, v) for _, s, o, k, v in rows}
    screens = ["outer"] + (["inner"] if inner else [])
    for screen in screens:
        for orient in ORIENTS:
            for kind in KINDS:
                if not any(s == screen and o == orient and k == kind for s, o, k, v in have):
                    errors.append("missing: a photo of the %s %s on the %s screen (§4.2, §7.3)" % (kind, orient, screen))
        for kind in CAPPED_PAGES:
            if (screen, "landscape", kind, "overview") not in have:
                errors.append("missing: the %s screen's landscape overview of the %s (§7.3)" % (screen, kind))
        for sheet in SHEETS:
            if not any(s == screen and v == sheet for s, o, k, v in have):
                errors.append("missing: the %s screen's %s (§7.3)" % (screen, sheet))
        if not any(s == screen and v == "first" for s, o, k, v in have):
            errors.append("missing: the first launch on the %s screen (§7.3)" % screen)
    if not any(s == "iphone" and v == "first" for s, o, k, v in have):
        errors.append("missing: the iPhone 17's first launch (§7.3)")
    for s, o, k, v in have:
        if s == "inner" and not inner:
            warnings.append("photos of the inner screen without --inner: their rows are checked, their set is not")
            break
    return errors, warnings, notes, table


def report(folder, inner, uses_hinge, size_rule, out=sys.stdout):
    errors, warnings, notes, table = check_folder(folder, inner=inner, uses_hinge=uses_hinge, size_rule=size_rule)
    columns = ["file", "where", "size", "mean", "edges", "window", "safe", "scale", "screen", "header", "paper", "plan", "cap", "V",
               "R", "maxPages", "capped", "wide", "hinge", "origin", "finger"]
    print(" | ".join(columns), file=out)
    for cell in table:
        print(" | ".join(str(cell.get(c, "-")) for c in columns), file=out)
    hinges = {}
    for cell in table:
        if "hinge" in cell:
            hinges.setdefault(cell["where"].split()[0], set()).add(cell["hinge"])
    print("hinge= by screen: %s (§4.2: PencilPhone.usesHinge is true only when a Duo screen's is not nil and the iPhone 17's"
          " is nil)" % (", ".join("%s %s" % (s, "/".join(sorted(v))) for s, v in sorted(hinges.items())) or "none"), file=out)
    for note in notes:
        print("::notice::shot_checks: " + note, file=out)
    for warning in warnings:
        print("::warning::shot_checks: " + warning, file=out)
    for error in errors:
        print("::error::shot_checks: " + error, file=out)
    print("shot_checks: %d photos, %d error%s, %d warning%s: %s" % (len(table), len(errors), "" if len(errors) == 1 else "s",
          len(warnings), "" if len(warnings) == 1 else "s", "ok" if not errors else "FAILED"), file=out)
    return 1 if errors else 0


# ── the self-test (§6: the checks must fail on made-up photos made to fail them) ─────────────────────────────────────

def write_png(path, width, height, row_of, filters=False, color=6, depth=8, palette=None):
    """A PNG whose row y is row_of(y) (raw samples). With filters, row y uses PNG filter y % 5 (so the reader's
    unfiltering is tried); else filter 0 (fast)."""
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color]
    bpp = channels * depth // 8
    parts = []
    prev = bytes(width * bpp)
    for y in range(height):
        line = row_of(y)
        kind = y % 5 if filters else 0
        if kind == 0:
            enc = line
        else:
            enc = bytearray(len(line))
            for i in range(len(line)):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                if kind == 1:
                    pred = a
                elif kind == 2:
                    pred = b
                elif kind == 3:
                    pred = (a + b) >> 1
                else:
                    pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                    pred = a if pa <= pb and pa <= pc else b if pb <= pc else c
                enc[i] = (line[i] - pred) & 0xFF
        parts.append(bytes([kind]) + bytes(enc))
        prev = line

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, depth, color, 0, 0, 0))
    if palette is not None:
        data += chunk(b"PLTE", palette)
    data += chunk(b"IDAT", zlib.compress(b"".join(parts), 6)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(data)


PAPER = bytes((250, 248, 240, 255))
INK = bytes((40, 40, 60, 255))
BLACK = bytes((0, 0, 0, 255))


def paper_photo(path, width, height, band=0, top_bottom=0, border=0, everything=None):
    """A light page with a few ink lines; `band` px black at the left and right ("真ん中に小さく"), `top_bottom` px at the
    top and bottom, a `border` px black frame, or every pixel `everything`."""
    plain = PAPER * width
    inked = PAPER * 120 + INK * (width - 240) + PAPER * 120
    if band:
        plain = BLACK * band + PAPER * (width - 2 * band) + BLACK * band
        inked = BLACK * band + INK * (width - 2 * band) + BLACK * band
    if border:
        plain = BLACK * border + plain[4 * border:-4 * border] + BLACK * border
        inked = BLACK * border + inked[4 * border:-4 * border] + BLACK * border
    full = (everything or BLACK) * width

    def row(y):
        if everything is not None:
            return full
        if y < top_bottom or y >= height - top_bottom or y < border or y >= height - border:
            return full
        return inked if y % 97 < 3 else plain

    write_png(path, width, height, row)


def measure_line(**over):
    fields = {"window": "466.00x678.00", "safe": "44.00,0.00,20.00,0.00", "scale": "3.00", "screen": "466.00x678.00",
              "header": "2", "paper": "466.00x520.00", "plan": "iPhone,portrait", "cap": "on", "V": "1.000", "R": "2",
              "maxPages": "nil", "capped": "false", "wide": "false", "hinge": "nil", "origin": "app", "finger": "false"}
    fields.update(over)
    return "duo measure: " + " ".join("%s=%s" % (k, v) for k, v in fields.items())


def good_set(folder, images):
    """A complete outer-screen set (and the iPhone 17's first launch) with lines that meet every expectation."""
    rows, lines = [], []

    def add(screen, orient, kind, variant, image, **over):
        name = "%s-%s-%s-%s.png" % (screen, orient, kind, variant)
        if not os.path.exists(os.path.join(folder, name)):
            os.symlink(images[image], os.path.join(folder, name))
        rows.append("\t".join((name, screen, orient, kind, variant)))
        if orient == "landscape":
            over = dict(dict(window="678.00x466.00", screen="678.00x466.00", paper="600.00x256.00", plan="iPhone,landscape",
                             header="1"), **over)
        if screen == "iphone":
            over = dict(dict(window="402.00x874.00", screen="402.00x874.00", header="2"), **over)
        lines.append(name + "\t" + measure_line(**over))

    add("outer", "portrait", "week", "first", "outer", finger="true")
    for kind in KINDS:
        add("outer", "portrait", kind, "pencil", "outer")
    for sheet in SHEETS:
        add("outer", "portrait", "month", sheet, "outer")
    for kind in KINDS:
        add("outer", "landscape", kind, "pencil", "outer-landscape")
    add("outer", "landscape", "week", "overview", "outer-landscape", maxPages="3", capped="true")
    add("outer", "landscape", "day", "overview", "outer-landscape", maxPages="5", capped="true")
    add("iphone", "portrait", "week", "first", "iphone", finger="true")
    return rows, lines


def write_set(folder, rows, lines):
    with open(os.path.join(folder, "shots.tsv"), "w", encoding="utf-8") as f:
        f.write("\n".join(rows) + "\n")
    with open(os.path.join(folder, "measure.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + ("\n" if lines else ""))


def self_test():
    failed = 0

    def verdict(name, ok, detail=""):
        nonlocal failed
        failed += not ok
        print("%s %s%s" % ("ok  " if ok else "FAIL", name, (": " + detail) if detail else ""))

    has_sips = shutil.which("sips") is not None
    print("shot_checks self-test (photos read through %s)" % ("sips" if has_sips else "the PNG reader"))
    with tempfile.TemporaryDirectory(prefix="shot-checks-test-") as tmp:
        img = os.path.join(tmp, "images")
        os.makedirs(img)
        p = lambda name: os.path.join(img, name)
        paper_photo(p("outer.png"), 1398, 2034)
        paper_photo(p("outer-landscape.png"), 2034, 1398)
        paper_photo(p("iphone.png"), 1206, 2622)
        paper_photo(p("black.png"), 1398, 2034, everything=BLACK)
        paper_photo(p("nearly-black.png"), 1398, 2034, top_bottom=0, everything=bytes((6, 6, 6, 255)))
        paper_photo(p("dark-ui.png"), 1398, 2034, everything=bytes((32, 32, 36, 255)))
        paper_photo(p("letterbox.png"), 1398, 2034, band=96)
        paper_photo(p("top-bottom.png"), 1398, 2034, top_bottom=180)
        paper_photo(p("thin-border.png"), 1398, 2034, border=1)
        paper_photo(p("off-by-one-height.png"), 1398, 2035)
        paper_photo(p("off-by-one-width.png"), 1399, 2034)
        paper_photo(p("inner.png"), 2007, 2853)
        paper_photo(p("inner-pixels.png"), 1878, 2670)

        # 1. the readers: the PNG reader against known pixels, every filter and sample kind; sips against it
        width, height = 61, 37
        pixel = lambda x, y: ((x * 7 + y * 3) % 256, (x * y) % 256, (255 - x * 4) % 256, 255 - (y % 2) * 100)
        rgba_rows = [bytes(v for x in range(width) for v in pixel(x, y)) for y in range(height)]
        want_mean = sum(0.299 * r + 0.587 * g + 0.114 * b for y in range(height) for x in range(width)
                        for r, g, b, _ in [pixel(x, y)]) / (width * height)
        write_png(p("filters.png"), width, height, lambda y: rgba_rows[y], filters=True)
        image = load(p("filters.png"), use_sips=False)
        verdict("the PNG reader undoes all five filters (RGBA)",
                abs(image.mean_luma() - want_mean) < 1e-9 and (image.width, image.height) == (width, height),
                "mean %.4f, made %.4f" % (image.mean_luma(), want_mean))
        top_left = image.row(0)[0]
        r, g, b, _ = pixel(0, 0)
        verdict("the PNG reader's first pixel", top_left == (299 * r + 587 * g + 114 * b) // 1000)
        write_png(p("rgb16.png"), 5, 4, lambda y: bytes(v for x in range(5) for c in (x * 50, y * 60, 200) for v in (c, 77)),
                  color=2, depth=16)
        verdict("the PNG reader: RGB of 16 bits (the high bytes)",
                abs(load(p("rgb16.png"), use_sips=False).mean_luma()
                    - sum(0.299 * x * 50 + 0.587 * y * 60 + 0.114 * 200 for x in range(5) for y in range(4)) / 20) < 1e-9)
        write_png(p("gray.png"), 4, 3, lambda y: bytes((y * 40,) * 4), color=0, filters=True)
        verdict("the PNG reader: gray", abs(load(p("gray.png"), use_sips=False).mean_luma() - 40) < 1e-6)
        write_png(p("palette.png"), 4, 2, lambda y: bytes((0, 1, 1, 0)), color=3,
                  palette=bytes((0, 0, 0, 255, 255, 255)))
        verdict("the PNG reader: a palette", abs(load(p("palette.png"), use_sips=False).mean_luma() - 127.5) < 0.01)
        if has_sips:
            via = load(p("filters.png"), use_sips=True)
            verdict("sips (BMP) and the PNG reader read the same pixels",
                    (via.width, via.height) == (width, height) and abs(via.mean_luma() - want_mean) < 1.0,
                    "sips %.3f, made %.3f" % (via.mean_luma(), want_mean))
            big_png = load(p("letterbox.png"), use_sips=False)
            big_bmp = load(p("letterbox.png"), use_sips=True)
            verdict("sips and the PNG reader agree on a full photo",
                    abs(big_png.mean_luma() - big_bmp.mean_luma()) < 1.0 and big_png.edge_black("left") == big_bmp.edge_black("left"))
            jpg = os.path.join(img, "outer.jpg")
            subprocess.run(["sips", "-s", "format", "jpeg", p("outer.png"), "--out", jpg], capture_output=True)
            j = load(jpg) if os.path.exists(jpg) else None
            verdict("a JPEG is read through sips", j is not None and (j.width, j.height) == (1398, 2034))
        else:
            print("     (no sips here: the BMP path is not tried)")

        # 2. black, edges, sizes, one photo at a time
        for name, want_black in (("black.png", True), ("nearly-black.png", True), ("dark-ui.png", False), ("outer.png", False)):
            got = load(p(name)).mean_luma() < BLACK_MEAN
            verdict("black: %s is %sblack" % (name, "" if want_black else "not "), got == want_black)
        for name, want in (("letterbox.png", {"left", "right"}), ("top-bottom.png", {"top", "bottom"}),
                           ("thin-border.png", set()), ("outer.png", set()), ("dark-ui.png", set())):
            image = load(p(name))
            got = {e for e in ("left", "right", "top", "bottom") if image.edge_black(e)}
            verdict("edges: %s has black edges %s" % (name, sorted(want) or "none"), got == want, "found %s" % sorted(got))

        # 3. the `black` command duo.yml's retakes use
        here = os.path.abspath(__file__)
        for name, code in (("black.png", 0), ("outer.png", 1), ("missing.png", 2)):
            done = subprocess.run([sys.executable, "-I", here, "black", p(name)], capture_output=True, text=True)
            verdict("black %s exits %d" % (name, code), done.returncode == code, done.stdout.strip())

        # 4. the lines
        fields, problems = parse_measure("2026-11-21 10:00:00.1 TegakiCalendar[1:2] " + measure_line())
        verdict("a duo measure: line in a log line parses", not problems and fields["window"] == "466.00x678.00", "; ".join(problems))
        _, problems = parse_measure(measure_line().replace(" finger=false", ""))
        verdict("a line without finger= fails", problems == ["finger= is missing"], "; ".join(problems))
        _, problems = parse_measure(measure_line(hinge="half"))
        verdict("hinge=half fails", len(problems) == 1, "; ".join(problems))
        _, problems = parse_measure(measure_line(plan="nil", V="nil", R="nil") + " extra=1")
        verdict("plan, V and R may be nil, unknown fields are ignored", not problems, "; ".join(problems))

        # 5. whole folders: the good set passes, each made-up fault fails with the check meant to catch it
        images = {k: p(k + ".png") for k in ("outer", "outer-landscape", "iphone")}

        def run(name, change=None, want=None, inner=False, uses_hinge="unknown", size_rule="fail", warn=None):
            folder = os.path.join(tmp, "set-%d" % run.count)
            run.count += 1
            os.makedirs(folder)
            rows, lines = good_set(folder, images)
            if change:
                rows, lines = change(folder, rows, lines)
            write_set(folder, rows, lines)
            errors, warnings, notes, _ = check_folder(folder, inner=inner, uses_hinge=uses_hinge, size_rule=size_rule)
            if want is None:
                ok = not errors and (warn is None or any(warn in w for w in warnings))
            else:  # every fault named is found, and nothing else fails (the check meant, not another one)
                ok = (len(errors) >= 1 and all(any(w in e for e in errors) for w in want)
                      and all(any(w in e for w in want) for e in errors))
            verdict(name, ok, "; ".join(errors[:3]) if not ok or want else "")
            return errors

        run.count = 0

        def swap(target, image):
            def change(folder, rows, lines):
                os.remove(os.path.join(folder, target))
                os.symlink(p(image), os.path.join(folder, target))
                return rows, lines
            return change

        def line_of(target, **over):
            def change(folder, rows, lines):
                return rows, [l if not l.startswith(target + "\t") else l.split("\t")[0] + "\t" + measure_line(**dict(
                    {k: v for k, v in (t.split("=", 1) for t in l.split("duo measure: ")[1].split())}, **over)) for l in lines]
            return change

        def drop_row(target):
            def change(folder, rows, lines):
                return [r for r in rows if not r.startswith(target + "\t")], [l for l in lines if not l.startswith(target + "\t")]
            return change

        run("the good set passes")
        run("the good set passes with --uses-hinge false", uses_hinge="false")
        run("a black photo (still black after the retakes)", swap("outer-portrait-month-pencil.png", "black.png"), ["black"])
        run("\"真ん中に小さく\": black bands at the left and right", swap("outer-portrait-week-pencil.png", "letterbox.png"),
            ["left and right edges"])
        run("black bands at the top and bottom", swap("outer-portrait-day-pencil.png", "top-bottom.png"), ["top and bottom edges"])
        run("a photo one pixel too tall", swap("outer-portrait-year-pencil.png", "off-by-one-height.png"), ["1398x2035"])
        run("a photo one pixel too wide", swap("outer-portrait-year-pencil.png", "off-by-one-width.png"), ["1399x2034"])
        run("a wrong size with --size-rule warn is a warning", swap("outer-portrait-year-pencil.png", "off-by-one-width.png"),
            size_rule="warn", warn="1399x2034")
        run("the inner screen's pixels on the outer screen", swap("outer-portrait-year-pencil.png", "inner-pixels.png"),
            ["1878x2670"])
        run("a missing photo", lambda f, r, l: (os.remove(os.path.join(f, "outer-portrait-month-sheet-paywall.png")) or (r, l)),
            ["cannot be read"])
        run("a launch without a duo measure: line",
            lambda f, r, l: (r, [x for x in l if not x.startswith("outer-portrait-month-pencil.png\t")]), ["no duo measure"])
        run("a malformed line", lambda f, r, l: (r, [x.replace(" origin=app", "") if x.startswith("outer-portrait-week-pencil.png")
                                                       else x for x in l]), ["origin= is missing", "no duo measure"])
        run("the outer screen read as wide", line_of("outer-portrait-week-pencil.png", wide="true"), ["wide=true"])
        run("the outer portrait header in one row", line_of("outer-portrait-day-pencil.png", header="1"), ["header=1"])
        run("the Duo planned as an iPad", line_of("outer-portrait-week-pencil.png", plan="iPad11,portrait"), ["§4.6"])
        run("--screenshot-pencil-phone with 「指でも書く」 on", line_of("outer-portrait-month-sheet-create.png", finger="true"),
            ["finger=true"])
        run("the iPhone 17 with a hinge", line_of("iphone-portrait-week-first.png", hinge="closed"), ["hinge=closed"])
        run("the iPhone 17 with 「指でも書く」 off", line_of("iphone-portrait-week-first.png", finger="false"), ["finger=false"])
        run("the outer overview not capped", line_of("outer-landscape-week-overview.png", maxPages="nil", capped="false"),
            ["maxPages=nil", "capped=false"])
        run("the outer day overview capped at 3", line_of("outer-landscape-day-overview.png", maxPages="3"), ["maxPages=3"])
        run("a landscape photo whose lines are all portrait",
            line_of("outer-landscape-month-pencil.png", window="466.00x678.00"), ["did not turn"])
        run("usesHinge true, the outer hinge closed, 「指でも書く」 still on",
            line_of("outer-portrait-week-first.png", hinge="closed"), ["finger=true"], uses_hinge="true")
        run("usesHinge true, the outer hinge closed, 「指でも書く」 off",
            line_of("outer-portrait-week-first.png", hinge="closed", finger="false"), uses_hinge="true")
        run("usesHinge false, 「指でも書く」 off on the first launch (and the outer hinge against §4.2's rule)",
            line_of("outer-portrait-week-first.png", hinge="closed", finger="false"), ["finger=false", "§4.2's rule"],
            uses_hinge="false")

        def outer_closed(first_finger):
            """Run 44696154794's hinges: every outer line hinge=closed (the iPhone 17's nil); the first launch's finger given."""
            def change(folder, rows, lines):
                for row in list(rows):
                    name = row.split("\t")[0]
                    if name.startswith("outer-"):
                        over = dict(hinge="closed", **({"finger": first_finger} if name == "outer-portrait-week-first.png" else {}))
                        rows, lines = line_of(name, **over)(folder, rows, lines)
                return rows, lines
            return change

        run("run 44696154794's hinges with usesHinge true, the first launch off: passes", outer_closed("false"), uses_hinge="true")
        run("run 44696154794's hinges with usesHinge true, the first launch still on", outer_closed("true"), ["finger=true"],
            uses_hinge="true")
        run("usesHinge true, but no Duo screen reads a hinge (§4.2's rule)", None, ["§4.2's rule"], uses_hinge="true")
        run("usesHinge false, but the outer screen reads a hinge and the iPhone 17 none (§4.2's rule)",
            line_of("outer-portrait-week-first.png", hinge="closed"), ["§4.2's rule"], uses_hinge="false")
        run("usesHinge true, but the iPhone 17 reads a hinge too (§4.2's rule)",
            lambda f, r, l: line_of("iphone-portrait-week-first.png", hinge="closed")(f, *outer_closed("false")(f, r, l)),
            ["hinge=closed", "§4.2's rule"], uses_hinge="true")
        run("no landscape month", drop_row("outer-landscape-month-pencil.png"), ["missing: a photo of the month landscape"])
        run("no week overview", drop_row("outer-landscape-week-overview.png"), ["overview of the week"])
        run("no settings sheet", drop_row("outer-portrait-month-sheet-settings.png"), ["sheet-settings"])
        run("no iPhone 17", drop_row("iphone-portrait-week-first.png"), ["iPhone 17's first launch"])
        run("--inner without inner photos", None, ["on the inner screen", "inner screen's"], inner=True)

        def with_inner(folder, rows, lines):
            def add(orient, kind, variant, image, **over):
                name = "inner-%s-%s-%s.png" % (orient, kind, variant)
                os.symlink(p(image + ".png"), os.path.join(folder, name))
                rows.append("\t".join((name, "inner", orient, kind, variant)))
                base = dict(window="669.00x951.00", screen="669.00x951.00", header="1", wide="true", cap="off",
                            paper="669.00x800.00", plan="iPhone,portrait")
                if orient == "landscape":
                    base.update(window="951.00x669.00", screen="951.00x669.00", paper="951.00x446.00", plan="iPhone,landscape")
                base.update(over)
                lines.append(name + "\t" + measure_line(**base))
            add("portrait", "week", "first", "inner", finger="true")
            for kind in KINDS:
                add("portrait", kind, "pencil", "inner-pixels" if kind == "day" else "inner")
            for sheet in SHEETS:
                add("portrait", "month", sheet, "inner")
            for kind in KINDS:
                add("landscape", kind, "pencil", "inner-landscape")
            for kind in CAPPED_PAGES:
                add("landscape", kind, "overview", "inner-landscape")
            return rows, lines

        paper_photo(p("inner-landscape.png"), 2853, 2007)
        run("the inner screen's set passes (2007x2853 and 1878x2670)", with_inner, inner=True)
        run("the inner screen read as not wide",
            lambda f, r, l: line_of("inner-portrait-week-pencil.png", wide="false")(f, *with_inner(f, r, l)), ["wide=false"],
            inner=True)
        run("the inner overview capped",
            lambda f, r, l: line_of("inner-landscape-day-overview.png", maxPages="5", capped="true", cap="on")(f, *with_inner(f, r, l)),
            ["maxPages=5", "capped=true", "cap=on"], inner=True)
        run("an outer photo of the inner screen's size",
            lambda f, r, l: swap("outer-landscape-week-pencil.png", "inner-landscape.png")(f, r, l), ["2853x2007"])

    print("shot_checks self-test: %s" % ("ok" if not failed else "%d FAILED" % failed))
    return 1 if failed else 0


def main(argv):
    args = argv[1:]
    if args == ["--self-test"]:
        return self_test()
    if len(args) == 2 and args[0] == "black":
        try:
            mean = load(args[1]).mean_luma()
        except (ShotError, OSError, struct.error) as error:
            print("%s: not readable (%s)" % (args[1], error))
            return 2
        print("%s: mean luma %.1f: %s" % (args[1], mean, "black" if mean < BLACK_MEAN else "not black"))
        return 0 if mean < BLACK_MEAN else 1
    if len(args) >= 2 and args[0] == "check":
        folder, rest = args[1], args[2:]
        inner, uses_hinge, size_rule = False, "unknown", "fail"
        while rest:
            if rest[0] == "--inner":
                inner, rest = True, rest[1:]
            elif rest[0] == "--uses-hinge" and len(rest) > 1 and rest[1] in ("true", "false", "unknown"):
                uses_hinge, rest = rest[1], rest[2:]
            elif rest[0] == "--size-rule" and len(rest) > 1 and rest[1] in ("fail", "warn"):
                size_rule, rest = rest[1], rest[2:]
            else:
                print(__doc__, file=sys.stderr)
                return 2
        if not os.path.isdir(folder):
            print("shot_checks: no folder %s" % folder, file=sys.stderr)
            return 2
        return report(folder, inner, uses_hinge, size_rule)
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
