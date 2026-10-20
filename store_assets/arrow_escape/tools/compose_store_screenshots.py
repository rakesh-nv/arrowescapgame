"""Composes Play Store screenshots from real captures of Arrow Escape.

Every phone screen / board crop below is pixel data captured from the app on a
physical device (adb screencap or the user's own device screenshots). Only the
surrounding marketing layout (background, text, device frame) is drawn here.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps
import os

ROOT = "D:/AndroidStudioProjects/arrowescapegame"
RAW = f"{ROOT}/store_assets/arrow_escape/raw_captures"
OUT = f"{ROOT}/store_assets/arrow_escape/play_store_screenshots"
LOGO = f"{ROOT}/android/app/src/main/res/playstore-icon.png"
os.makedirs(OUT, exist_ok=True)

W, H = 1080, 1920
NAVY = (26, 35, 64)          # AppColors.navyDark 0xFF1A2340
BLUE = (37, 99, 235)         # escaping-arrow / primary button blue in the app
SLATE = (91, 100, 120)
F_BOLD = "C:/Windows/Fonts/segoeuib.ttf"
F_SEMI = "C:/Windows/Fonts/seguisb.ttf"
STATUS_BAR = 105             # crop the device status bar (clock/battery/net)


def font(path, size):
    return ImageFont.truetype(path, size)


def background():
    img = Image.new("RGB", (W, H), "white")
    px = img.load()
    for y in range(H):
        t = y / H
        c = tuple(int(255 + (e - 255) * t) for e in (240, 244, 252))
        for x in range(W):
            px[x, y] = c
    # faint dot grid, echoing the dots drawn on the in-game board
    d = ImageDraw.Draw(img)
    for y in range(560, H, 40):
        a = min(1.0, (y - 560) / 500)
        col = tuple(int(c0 + (c1 - c0) * a) for c0, c1 in zip((240, 244, 252), (214, 221, 236)))
        for x in range(20, W, 40):
            d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=col)
    return img


def rounded_mask(size, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), r, fill=255)
    return m


def shadow_paste(base, layer, xy, blur=38, offset=(0, 26), opacity=70):
    alpha = layer.split()[-1]
    sh = Image.new("RGBA", (layer.width + blur * 4, layer.height + blur * 4), (0, 0, 0, 0))
    sh_alpha = Image.new("L", sh.size, 0)
    sh_alpha.paste(alpha.point(lambda v: v * opacity // 255), (blur * 2, blur * 2))
    sh_alpha = sh_alpha.filter(ImageFilter.GaussianBlur(blur))
    sh = Image.new("RGBA", sh.size, NAVY + (0,))
    sh.putalpha(sh_alpha)
    base.alpha_composite(sh, (xy[0] - blur * 2 + offset[0], xy[1] - blur * 2 + offset[1]))
    base.alpha_composite(layer, xy)


def phone(path, width, crop_status=True):
    """Real screenshot inside a simple modern device frame."""
    shot = Image.open(path).convert("RGB")
    if crop_status:
        shot = shot.crop((0, STATUS_BAR, shot.width, shot.height))
    bezel = max(10, width // 42)
    sw = width - 2 * bezel
    sh = round(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    r_out = width // 9
    frame = Image.new("RGBA", (width, sh + 2 * bezel), (0, 0, 0, 0))
    body = Image.new("RGBA", frame.size, NAVY + (255,))
    frame.paste(body, (0, 0), rounded_mask(frame.size, r_out))
    scr = shot.convert("RGBA")
    scr.putalpha(rounded_mask(scr.size, r_out - bezel))
    frame.alpha_composite(scr, (bezel, bezel))
    # subtle highlight edge on the frame
    ImageDraw.Draw(frame).rounded_rectangle(
        (1, 1, frame.width - 2, frame.height - 2), r_out, outline=(60, 72, 110, 255), width=2)
    return frame


def logo_row(img, y=70):
    icon = Image.open(LOGO).convert("RGBA").resize((84, 84), Image.LANCZOS)
    tile = Image.new("RGBA", (84, 84), (255, 255, 255, 255))
    tile.alpha_composite(icon)
    tile.putalpha(rounded_mask((84, 84), 20))
    d = ImageDraw.Draw(img)
    f = font(F_BOLD, 40)
    label = "Arrow Escape"
    tw = d.textlength(label, font=f)
    total = 84 + 22 + tw
    x0 = int((W - total) / 2)
    shadow_paste(img, tile, (x0, y), blur=10, offset=(0, 6), opacity=45)
    d.text((x0 + 84 + 22, y + 42), label, font=f, fill=NAVY, anchor="lm")


def headline(img, line1, line2, sub, y=200):
    d = ImageDraw.Draw(img)
    f = font(F_BOLD, 88)
    d.text((W / 2, y), line1, font=f, fill=NAVY, anchor="mt")
    d.text((W / 2, y + 104), line2, font=f, fill=BLUE, anchor="mt")
    fs = font(F_SEMI, 38)
    d.text((W / 2, y + 236), sub, font=fs, fill=SLATE, anchor="mt")


def pill(img, text, center, fill=BLUE, fg=(255, 255, 255), size=32, pad=(28, 14)):
    d = ImageDraw.Draw(img)
    f = font(F_BOLD, size)
    tw = d.textlength(text, font=f)
    w, h = int(tw + pad[0] * 2), size + pad[1] * 2
    x, y = int(center[0] - w / 2), int(center[1] - h / 2)
    layer = Image.new("RGBA", (w, h), fill + (255,))
    layer.putalpha(rounded_mask((w, h), h // 2))
    shadow_paste(img, layer, (x, y), blur=12, offset=(0, 8), opacity=50)
    d.text((x + w / 2, y + h / 2 + 1), text, font=f, fill=fg, anchor="mm")


def card(src, box, scale_to, radius=36, border=None):
    im = Image.open(src).convert("RGB").crop(box).resize(scale_to, Image.LANCZOS).convert("RGBA")
    im.putalpha(rounded_mask(scale_to, radius))
    if border:
        ImageDraw.Draw(im).rounded_rectangle(
            (1, 1, scale_to[0] - 2, scale_to[1] - 2), radius, outline=border, width=5)
    return im


def save(img, name):
    p = f"{OUT}/{name}"
    img.convert("RGB").save(p, "PNG", optimize=True)
    print(p, Image.open(p).size)


# 1 ─ Core gameplay ───────────────────────────────────────────────────────
img = background().convert("RGBA")
logo_row(img)
headline(img, "Tap. Slide.", "Escape!", "Clear every arrow from the board")
ph = phone(f"{RAW}/01_gameplay_level13_start.png", 660)
shadow_paste(img, ph, ((W - ph.width) // 2, 515))
save(img, "01_core_gameplay.png")

# 2 ─ Clear the arrows ────────────────────────────────────────────────────
img = background().convert("RGBA")
logo_row(img)
headline(img, "Only Free Arrows", "Slide Out", "Tap an arrow whose path to the edge is clear")
ph = phone(f"{RAW}/07_daily_arrow_escaping_frame2.png", 640)
shadow_paste(img, ph, (60, 540))
# real before/after crops of the same escaping arrow
crop = (560, 715, 1000, 935)
c1 = card(f"{RAW}/06_daily_arrow_escaping_frame1.png", crop, (420, 210), border=BLUE + (255,))
c2 = card(f"{RAW}/07_daily_arrow_escaping_frame2.png", crop, (420, 210), border=BLUE + (255,))
shadow_paste(img, c1, (610, 760))
shadow_paste(img, c2, (610, 1150))
pill(img, "1  Tap", (820, 742))
pill(img, "2  It slides away", (820, 1132))
d = ImageDraw.Draw(img)
for yy in range(990, 1110, 22):  # dotted connector between the two steps
    d.ellipse((816, yy, 826, yy + 10), fill=BLUE)
save(img, "02_clear_the_arrows.png")

# 3 ─ Bigger challenges ───────────────────────────────────────────────────
img = background().convert("RGBA")
logo_row(img)
headline(img, "Bigger Boards,", "Bigger Challenges", "200 levels across 8 worlds, up to 60×60")
UP = f"{RAW}/user_provided"
left = phone(f"{UP}/Screenshot_2026-10-09-22-30-57-43.jpg", 520)   # Level 2 · 32×32
right = phone(f"{UP}/Screenshot_2026-10-10-12-24-44-68.jpg", 520)  # Level 9 · 39×39
center = phone(f"{UP}/Screenshot_2026-10-09-22-30-33-85.jpg", 660)  # Daily · 51×51
shadow_paste(img, left, (-120, 640), opacity=45)
shadow_paste(img, right, (W - 520 + 120, 640), opacity=45)
shadow_paste(img, center, ((W - 660) // 2, 540), opacity=80)
save(img, "03_bigger_challenges.png")

# 4 ─ Daily challenge ─────────────────────────────────────────────────────
img = background().convert("RGBA")
logo_row(img)
headline(img, "A New Puzzle", "Every Day", "Keep your streak going and earn +50 coins")
back = phone(f"{RAW}/04_daily_challenge_screen.png", 520)
front = phone(f"{RAW}/05_daily_challenge_board.png", 560)
shadow_paste(img, back, (24, 560), opacity=50)
shadow_paste(img, front, (W - 560 - 24, 680), opacity=80)
save(img, "04_daily_challenge.png")

# 5 ─ Themes ──────────────────────────────────────────────────────────────
img = background().convert("RGBA")
logo_row(img)
headline(img, "Unlock New", "Themes", "43 themes to collect with the coins you earn")
back = phone(f"{RAW}/09_themes_top.png", 520)
front = phone(f"{RAW}/11_daily_board_ocean_theme.png", 560)
shadow_paste(img, back, (24, 560), opacity=50)
shadow_paste(img, front, (W - 560 - 24, 680), opacity=80)
save(img, "05_unlock_themes.png")

# 6 ─ Every puzzle is a picture (real board crops) ───────────────────────
def board_crop(path, y0=560, y1=2060):
    im = Image.open(path).convert("RGB")
    px = im.load()
    xs, ys = [], []
    for y in range(y0, y1, 3):
        for x in range(0, im.width, 3):
            r, g, b = px[x, y]
            if r < 50 and g < 60 and 45 < b < 100:
                xs.append(x); ys.append(y)
    x0, x1, yy0, yy1 = min(xs), max(xs), min(ys), max(ys)
    cx, cy = (x0 + x1) / 2, (yy0 + yy1) / 2
    side = max(x1 - x0, yy1 - yy0) + 60
    canvas = Image.new("RGB", (side, side), px[8, 1500])
    canvas.paste(im.crop((int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))).crop((0, 0, side, side)), (0, 0))
    sx0, sy0 = int(cx - side / 2), int(cy - side / 2)
    canvas = Image.new("RGB", (side, side), px[8, 1500])
    src = im.crop((max(0, sx0), max(0, sy0), min(im.width, sx0 + side), min(im.height, sy0 + side)))
    canvas.paste(src, (max(0, -sx0), max(0, -sy0)))
    return canvas

img = background().convert("RGBA")
logo_row(img)
headline(img, "Every Puzzle", "Is a Picture", "Cars, dinosaurs, music notes and more")
tiles = [
    (f"{UP}/Screenshot_2026-10-09-22-30-57-43.jpg", "Car"),
    (f"{UP}/Screenshot_2026-10-10-12-24-44-68.jpg", "Dinosaur"),
    (f"{UP}/Screenshot_2026-10-10-12-26-10-68.jpg", "Motorcycle"),
    (f"{RAW}/01_gameplay_level13_start.png", "Dinosaur Footprint"),
    (f"{RAW}/05_daily_challenge_board.png", "Smiling Face"),
    (f"{UP}/Screenshot_2026-10-09-22-30-33-85.jpg", "Musical Note"),
]
tw, th = 440, 400
gx, gy = (W - 2 * tw - 40) // 2, 560
fl = font(F_SEMI, 32)
for i, (p, name) in enumerate(tiles):
    c = board_crop(p).resize((tw - 40, tw - 40), Image.LANCZOS)
    t = Image.new("RGBA", (tw, th), (255, 255, 255, 255))
    t.paste(c.resize((th - 90, th - 90), Image.LANCZOS),
            ((tw - (th - 90)) // 2, 16))
    ImageDraw.Draw(t).text((tw / 2, th - 38), name, font=fl, fill=NAVY, anchor="mm")
    t.putalpha(rounded_mask((tw, th), 34))
    x = gx + (i % 2) * (tw + 40)
    y = gy + (i // 2) * (th + 36)
    shadow_paste(img, t, (x, y), blur=24, offset=(0, 14), opacity=40)
save(img, "06_every_puzzle_a_picture.png")
