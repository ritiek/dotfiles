#!/usr/bin/env python3
# Waveshare 2.13" V4 e-paper page: 3h voltage graph + this week's average sleep.
# Reads Home Assistant's recorder DB read-only (runs as root on radrubble).
import json
import math
import signal
import sqlite3
import sys
import time
from datetime import date, datetime, timedelta
import gpiod
import spidev
from gpiod.line import Direction, Value
from PIL import Image, ImageDraw, ImageFont

CHIP, SPI_BUS = "/dev/gpiochip3", 3
RST, DC, BUSY = 1, 17, 10
W, H = 122, 250
DB = "file:/var/lib/hass/home-assistant_v2.db?mode=ro"
VOLT = "sensor.zebronics_zeb_sp116_voltage"
SLEEP = "sensor.redmi_note_11_sleep_segment"
CONF = "sensor.redmi_note_11_sleep_confidence"

gpio = gpiod.request_lines(CHIP, consumer="epaper", config={
    (RST, DC): gpiod.LineSettings(direction=Direction.OUTPUT, output_value=Value.ACTIVE),
    BUSY: gpiod.LineSettings(direction=Direction.INPUT),
})
spi = spidev.SpiDev(SPI_BUS, 0)
spi.max_speed_hz, spi.mode = 10_000_000, 0


def put(pin, v):
    gpio.set_value(pin, Value.ACTIVE if v else Value.INACTIVE)


def wait_busy(timeout=30):
    t0 = time.time()
    while gpio.get_value(BUSY) == Value.ACTIVE:
        if time.time() - t0 > timeout:
            raise TimeoutError("BUSY stuck high")
        time.sleep(0.01)


def cmd(c, *data):
    put(DC, 0)
    spi.writebytes([c])
    if data:
        put(DC, 1)
        spi.writebytes2(bytes(data))


def ram(reg, buf):
    cmd(reg)
    put(DC, 1)
    spi.writebytes2(buf)


def window():
    cmd(0x11, 0x03)
    cmd(0x44, 0x00, (W - 1) >> 3)
    cmd(0x45, 0x00, 0x00, (H - 1) & 0xFF, (H - 1) >> 8)
    cmd(0x4E, 0x00)
    cmd(0x4F, 0x00, 0x00)


def reset(ms=20):
    for v, t in ((1, ms), (0, 2), (1, ms)):
        put(RST, v)
        time.sleep(t / 1000)


def full(buf):
    reset()
    wait_busy()
    cmd(0x12)
    wait_busy()
    cmd(0x01, 0xF9, 0x00, 0x00)
    window()
    cmd(0x3C, 0x05)
    cmd(0x21, 0x00, 0x80)
    cmd(0x18, 0x80)
    wait_busy()
    ram(0x24, buf)
    ram(0x26, buf)  # base image for later partial refreshes
    cmd(0x22, 0xF7)
    cmd(0x20)
    wait_busy()


def partial(buf):
    reset(1)
    cmd(0x3C, 0x80)
    cmd(0x01, 0xF9, 0x00, 0x00)
    window()
    ram(0x24, buf)
    cmd(0x22, 0xFF)
    cmd(0x20)
    wait_busy()


F = lambda s: ImageFont.load_default(size=s)


def num(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None  # unavailable/unknown -> gap


def fetch():
    db = sqlite3.connect(DB, uri=True)
    mid = lambda e: db.execute("SELECT metadata_id FROM states_meta WHERE entity_id=?", (e,)).fetchone()[0]
    now = time.time()
    t0 = now - 3 * 3600
    v, s = mid(VOLT), mid(SLEEP)
    # Voltage is only recorded on change: carry the last value before the window.
    prev = db.execute("SELECT state FROM states WHERE metadata_id=? AND last_updated_ts<? "
                      "ORDER BY last_updated_ts DESC LIMIT 1", (v, t0)).fetchone()
    volt = ([(t0, num(prev[0]))] if prev else []) + [
        (t, num(x)) for t, x in db.execute(
            "SELECT last_updated_ts, state FROM states WHERE metadata_id=? AND last_updated_ts>=? "
            "ORDER BY last_updated_ts", (v, t0))]
    monday = date.today() - timedelta(days=date.today().weekday())
    since = datetime.combine(monday - timedelta(days=1), datetime.min.time()).timestamp()
    segs = {}
    for (attrs,) in db.execute(
            "SELECT a.shared_attrs FROM states s JOIN state_attributes a USING(attributes_id) "
            "WHERE s.metadata_id=? AND s.last_updated_ts>=?", (s, since)):
        a = json.loads(attrs)
        if a.get("status") == "successful":
            segs[a["start"]] = a["end"]  # same segment is re-recorded after restarts
    conf = [(t, num(x)) for t, x in db.execute(
        "SELECT last_updated_ts, state FROM states WHERE metadata_id=? AND last_updated_ts>=? "
        "ORDER BY last_updated_ts", (mid(CONF), since))]
    db.close()

    # Everything is counted on the day you woke up.
    seg = {}
    for start, end in segs.items():
        d = datetime.fromtimestamp(end / 1000).date()
        seg[d] = seg.get(d, 0) + (end - start) / 3.6e6
    # Fallback estimate: asleep while confidence >= 80, gaps <= 20 min merged,
    # runs >= 1h. Matches the phone's good segments within ~0.1h.
    runs = []
    for (ta, a), (tb, _) in zip(conf, conf[1:]):
        if a is None or a < 80:
            continue
        if runs and ta - runs[-1][1] <= 1200:
            runs[-1][1] = tb
        else:
            runs.append([ta, tb])
    if runs and (conf[-1][1] or 0) >= 80 and runs[-1][1] == conf[-1][0]:
        runs.pop()  # still asleep: tonight isn't finished yet
    est = {}
    for a, b in runs:
        if b - a >= 3600:
            d = datetime.fromtimestamp(b).date()
            est[d] = est.get(d, 0) + (b - a) / 3600

    # Monday..today only; None = no data that day. A segment total under 3h
    # (e.g. phone logged just the last hour) falls back to the estimate.
    days, estd = [None] * 7, [False] * 7
    for i in range((date.today() - monday).days + 1):
        d = monday + timedelta(days=i)
        s_, e_ = seg.get(d, 0), est.get(d, 0)
        if s_ >= 3 or s_ >= e_:
            days[i] = s_ or None
        else:
            days[i], estd[i] = e_, True
    return now, volt, days, estd


def render():
    now, volt, days, estd = fetch()
    img = Image.new("1", (H, W), 255)  # landscape 250x122
    d = ImageDraw.Draw(img)

    # Voltage: step graph, last 3h
    nums = [x for _, x in volt if x is not None]
    cur = next((x for _, x in reversed(volt) if x is not None), None)
    d.text((2, -1), f"{cur:.1f}V" if cur is not None else "--V", font=F(20), fill=0)
    if nums:
        lo, hi = min(nums), max(nums)
        d.text((2, 21), f"min {lo:.0f}  max {hi:.0f}", font=F(11), fill=0)
        lo, hi = math.floor((lo - 1) / 5) * 5, math.ceil((hi + 1) / 5) * 5
    gx0, gx1, gy0, gy1 = 24, 146, 38, 108
    d.rectangle((gx0, gy0, gx1, gy1), outline=0)
    for i, lbl in enumerate(("-3h", "-2h", "-1h", "now")):
        x = gx0 + i * (gx1 - gx0) / 3
        d.line((x, gy1, x, gy1 + 2), fill=0)
        d.text((x, gy1 + 3), lbl, font=F(10), fill=0, anchor="ma" if 0 < i < 3 else ("la" if i == 0 else "ra"))
    if nums:
        X = lambda t: gx0 + (t - (now - 3 * 3600)) / (3 * 3600) * (gx1 - gx0)
        Y = lambda v: gy1 - (v - lo) / (hi - lo) * (gy1 - gy0)
        step = 5
        while (hi - lo) / step > 5:  # outages can stretch the range; keep labels legible
            step += 5
        for v in range(lo, hi + 1, step):
            d.text((gx0 - 2, Y(v)), str(v), font=F(9), fill=0, anchor="rm")
            for x in range(gx0 + 2, gx1, 3):
                d.point((x, Y(v)), fill=0)
        pts = volt + [(now, None)]
        for (ta, a), (tb, b) in zip(pts, pts[1:]):
            if a is None:
                continue
            d.line((X(ta), Y(a), X(tb), Y(a)), fill=0, width=2)
            if b is not None:
                d.line((X(tb), Y(a), X(tb), Y(b)), fill=0, width=2)

    d.line((152, 0, 152, W), fill=0)

    # Sleep: Mon-Sun bars; average over the days so far that have data.
    # Hollow bar = estimated from sleep confidence.
    got = [h for h in days if h is not None]
    print("sleep", [h and round(h, 1) for h in days], "est", estd)
    d.text((157, -1), "Sleep avg", font=F(11), fill=0)
    d.text((157, 11), f"{sum(got) / len(got):.1f}h" if got else "--", font=F(24), fill=0)
    by0, by1 = 42, 106
    Yh = lambda h: by1 - min(h, 10) / 10 * (by1 - by0)
    for h in range(0, 11, 2):  # y-axis: hours, dotted every 2h
        d.text((165, Yh(h)), str(h), font=F(9), fill=0, anchor="rm")
        for x in range(168, 250, 3):
            d.point((x, Yh(h)), fill=0)
    for i, (h, e) in enumerate(zip(days, estd)):
        x = 169 + i * 11
        if h is None:
            d.line((x, by1, x + 7, by1), fill=0)
        else:
            d.rectangle((x, Yh(h), x + 7, by1), fill=255 if e else 0, outline=0)
        d.text((x + 4, by1 + 3), "MTWTFSS"[i], font=F(10), fill=0, anchor="ma")
    img.save("/tmp/epd_ha.png")  # preview copy of what's on the panel
    return img.rotate(270, expand=True).tobytes()


def stop(*_):
    sys.exit(0)


signal.signal(signal.SIGTERM, stop)

try:
    full(render())
    n = 0
    while True:
        time.sleep(300 - time.time() % 300 + 1)
        n += 1
        # Full refresh every 30 min clears partial-refresh ghosting.
        (full if n % 6 == 0 else partial)(render())
finally:
    cmd(0x10, 0x01)  # deep sleep; last image stays on the panel
    time.sleep(0.1)
    put(RST, 0)
    spi.close()
    gpio.release()
