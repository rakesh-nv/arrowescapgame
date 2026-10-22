"""ASO screenshot set (B) for Arrow Escape.

Same rule as the other compose scripts: every phone screen and board is real
pixel data, either a device capture or a board rendered by the game's own
ArrowBoardWidget (render_boards_test.dart). Only the marketing layout is drawn.

ASO choices: keyword-led headlines (arrow puzzle, maze, offline, levels) in
large type that stays readable in search-result thumbnails, the strongest
selling points in the first three slots, and short benefit chips.

Output: listing/en-US/images/phoneScreenshots_aso/*.png (1080x1920, RGB).
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import glob
import os

ROOT = "D:/AndroidStudioProjects/arrowescapegame"
RAW = f"{ROOT}/store_assets/arrow_escape/raw_captures"
V12 = f"{RAW}/v12"
REND = f"{V12}/rendered"
UP = f"{RAW}/user_provided"
OUT = f"{ROOT}/store_assets/arrow_escape/listing/en-US/images/phoneScreenshots_aso"
LOGO = f"{ROOT}/android/app/src/main/res/playstore-icon.png"
os.makedirs(OUT, exist_ok=True)

W, H = 1080, 1920
NAVY = (26, 35, 64)
BLUE = (37, 99, 235)
SLATE = (91, 100, 120)
F_BOLD = "C:/Windows/Fonts/segoeuib.ttf"
F_SEMI = "C:/Windows/Fonts/seguisb.ttf"
STATUS_BAR = 105


def font(path, size):
    return ImageFont.truetype(path, size)


def background(dots_from=600):
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line((0, y, W, y), fill=tuple(int(255 + (e - 255) * t) for e in (238, 243, 252)))
    for y in range(dots_from, H, 40):
        a = min(1.0, (y - dots_from) / 500)
        col = tuple(int(c0 + (c1 - c0) * a) for c0, c1 in zip((238, 243, 252), (212, 220, 236)))
        for x in range(20, W, 40):
            d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=col)
    return img.convert("RGBA")


def rounded_mask(size, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), r, fill=255)
    return m


def shadow_paste(base, layer, xy, blur=38, offset=(0, 26), opacity=70):
    alpha = layer.split()[-1]
    sh_alpha = Image.new("L", (layer.width + blur * 4, layer.height + blur * 4), 0)
    sh_alpha.paste(alpha.point(lambda v: v * opacity // 255), (blur * 2, blur * 2))
    sh_alpha = sh_alpha.filter(ImageFilter.GaussianBlur(blur))
    sh = Image.new("RGBA", sh_alpha.size, NAVY + (0,))
    sh.putalpha(sh_alpha)
    base.alpha_composite(sh, (xy[0] - blur * 2 + offset[0], xy[1] - blur * 2 + offset[1]))
    base.alpha_composite(layer, xy)


def phone(path, width):
    shot = Image.open(path).convert("RGB")
    shot = shot.crop((0, STATUS_BAR, shot.width, shot.height))
    bezel = max(10, width // 42)
    sw = width - 2 * bezel
    sh = round(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    r_out = width // 9
    frame = Image.new("RGBA", (width, sh + 2 * bezel), (0, 0, 0, 0))
    frame.paste(Image.new("RGBA", frame.size, NAVY + (255,)), (0, 0), rounded_mask(frame.size, r_out))
    scr = shot.convert("RGBA")
    scr.putalpha(rounded_mask(scr.size, r_out - bezel))
    frame.alpha_composite(scr, (bezel, bezel))
    ImageDraw.Draw(frame).rounded_rectangle(
        (1, 1, frame.width - 2, frame.height - 2), r_out, outline=(60, 72, 110, 255), width=2)
    return frame


def icon_tile(size, radius):
    icon = Image.open(LOGO).convert("RGBA").resize((size, size), Image.LANCZOS)
    tile = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    tile.alpha_composite(icon)
    tile.putalpha(rounded_mask((size, size), radius))
    return tile


def brand(img, y=56):
    tile = icon_tile(72, 18)
    d = ImageDraw.Draw(img)
    f = font(F_BOLD, 36)
    label = "Arrow Escape"
    tw = d.textlength(label, font=f)
    x0 = int((W - (72 + 18 + tw)) / 2)
    shadow_paste(img, tile, (x0, y), blur=10, offset=(0, 6), opacity=45)
    d.text((x0 + 72 + 18, y + 36), label, font=f, fill=NAVY, anchor="lm")


def headline(img, line1, line2, y=168, size=104):
    d = ImageDraw.Draw(img)
    f = font(F_BOLD, size)
    for s in range(size, 60, -4):  # shrink a long line to fit the width
        f = font(F_BOLD, s)
        if max(d.textlength(line1, font=f), d.textlength(line2, font=f)) <= W - 90:
            break
    d.text((W / 2, y), line1, font=f, fill=NAVY, anchor="mt")
    d.text((W / 2, y + f.size + 14), line2, font=f, fill=BLUE, anchor="mt")
    return y + 2 * f.size + 14


def chips(img, labels, y):
    """Row of short benefit chips (outlined, navy text)."""
    d = ImageDraw.Draw(img)
    f = font(F_BOLD, 32)
    pad, gap, h = 26, 16, 64
    widths = [int(d.textlength(t, font=f)) + pad * 2 for t in labels]
    x = (W - sum(widths) - gap * (len(labels) - 1)) // 2
    for t, w in zip(labels, widths):
        layer = Image.new("RGBA", (w, h), (255, 255, 255, 255))
        layer.putalpha(rounded_mask((w, h), h // 2))
        ImageDraw.Draw(layer).rounded_rectangle((1, 1, w - 2, h - 2), h // 2,
                                                outline=(205, 216, 240, 255), width=3)
        shadow_paste(img, layer, (x, y), blur=10, offset=(0, 6), opacity=30)
        d.text((x + w / 2, y + h / 2 + 1), t, font=f, fill=NAVY, anchor="mm")
        x += w + gap


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


def rendered(level):
    return glob.glob(f"{REND}/level{level:04d}_*.png")[0]


def board_card(path, side, label=None, sub=None, radius=34):
    """Rendered board on a rounded card, with an optional caption below."""
    cap = 92 if label else 0
    c = Image.new("RGBA", (side, side + cap), (255, 255, 255, 255))
    b = Image.open(path).convert("RGB").resize((side - 24, side - 24), Image.LANCZOS)
    b = b.convert("RGBA")
    b.putalpha(rounded_mask(b.size, radius - 10))
    c.alpha_composite(b, (12, 12))
    if label:
        d = ImageDraw.Draw(c)
        d.text((side / 2, side + 10), label, font=font(F_BOLD, 34), fill=NAVY, anchor="mt")
        if sub:
            d.text((side / 2, side + 52), sub, font=font(F_SEMI, 26), fill=SLATE, anchor="mt")
    c.putalpha(rounded_mask(c.size, radius))
    return c


def save(img, name):
    p = f"{OUT}/{name}"
    img.convert("RGB").save(p, "PNG", optimize=True)
    print(p, Image.open(p).size)


# 1 ─ Hero: what it is, with the top keywords ─────────────────────────────
img = background()
brand(img)
y = headline(img, "Arrow Maze", "Puzzle Game")
chips(img, ["1,000 levels", "Play offline", "40 worlds"], y + 34)
ph = phone(f"{RAW}/01_gameplay_level13_start.png", 680)
shadow_paste(img, ph, ((W - ph.width) // 2, y + 140))
save(img, "01_arrow_maze_puzzle.png")

# 2 ─ How to play ─────────────────────────────────────────────────────────
img = background()
brand(img)
y = headline(img, "Tap an Arrow,", "Clear Its Path")
chips(img, ["Easy to learn", "Hard to master"], y + 34)
ph = phone(f"{RAW}/07_daily_arrow_escaping_frame2.png", 620)
shadow_paste(img, ph, (50, y + 150))
crop = (560, 715, 1000, 935)  # real before/after crops of the same escaping arrow
c1 = card(f"{RAW}/06_daily_arrow_escaping_frame1.png", crop, (420, 210), border=BLUE + (255,))
c2 = card(f"{RAW}/07_daily_arrow_escaping_frame2.png", crop, (420, 210), border=BLUE + (255,))
shadow_paste(img, c1, (610, y + 340))
shadow_paste(img, c2, (610, y + 730))
pill(img, "1  Tap a free arrow", (820, y + 322))
pill(img, "2  It slides away", (820, y + 712))
d = ImageDraw.Draw(img)
for yy in range(y + 570, y + 690, 22):
    d.ellipse((816, yy, 826, yy + 10), fill=BLUE)
pill(img, "Blocked? You lose a life", (820, y + 1010), fill=NAVY, size=28)
save(img, "02_how_to_play.png")

# 3 ─ Progression: real boards from level 1 to 1,000 ──────────────────────
img = background()
brand(img)
y = headline(img, "1,000 Levels", "From Easy to Expert")
chips(img, ["Bigger boards", "Longer arrows", "Smarter puzzles"], y + 34)
cards = [
    (rendered(1), 420, "Level 1", "43 arrows", (70, y + 170)),
    (rendered(250), 470, "Level 250", "95 arrows", (540, y + 330)),
    (rendered(1000), 560, "Level 1,000", "169 arrows", (70, y + 700)),
]
for path, side, label, sub, xy in cards:
    shadow_paste(img, board_card(path, side, label, sub), xy, blur=26, offset=(0, 16), opacity=45)
pill(img, "Every level is solvable", (850, H - 300), size=30)
save(img, "03_1000_levels.png")

# 4 ─ New level map ───────────────────────────────────────────────────────
img = background()
brand(img)
y = headline(img, "Explore 40 Worlds", "On a New Map")
chips(img, ["Forest", "Desert", "Neon City", "Space"], y + 34)
left = phone(f"{V12}/15_map_world2.png", 520)
right = phone(f"{V12}/15_map_world8.png", 520)
center = phone(f"{V12}/14_level_map.png", 660)
shadow_paste(img, left, (-120, y + 240), opacity=45)
shadow_paste(img, right, (W - 520 + 120, y + 240), opacity=45)
shadow_paste(img, center, ((W - 660) // 2, y + 140), opacity=80)
save(img, "04_explore_40_worlds.png")

# 5 ─ Picture puzzles (real rendered boards) ──────────────────────────────
img = background()
brand(img)
y = headline(img, "Every Maze", "Is a Picture")
chips(img, ["Animals", "Vehicles", "Mandalas", "& more"], y + 34)
tiles = [
    (rendered(1), "Cat"), (rendered(60), "Crown"),
    (rendered(250), "Elephant"), (rendered(500), "Butterfly"),
]
side = 440
for i, (p, name) in enumerate(tiles):
    x = (W - 2 * side - 40) // 2 + (i % 2) * (side + 40)
    yy = y + 150 + (i // 2) * (side + 92 + 36)
    shadow_paste(img, board_card(p, side, name), (x, yy), blur=24, offset=(0, 14), opacity=40)
save(img, "05_picture_puzzles.png")

# 6 ─ Offline + helpers ───────────────────────────────────────────────────
img = background()
brand(img)
y = headline(img, "Play Offline,", "Anytime")
chips(img, ["No Wi-Fi needed", "Hints", "Undo"], y + 34)
ph = phone(f"{RAW}/02_gameplay_level13_hint.png", 660)
shadow_paste(img, ph, ((W - ph.width) // 2, y + 140))
save(img, "06_play_offline.png")

# 7 ─ Daily challenge ─────────────────────────────────────────────────────
img = background()
brand(img)
y = headline(img, "A New Puzzle", "Every Day")
chips(img, ["Daily streak", "+50 coins"], y + 34)
back = phone(f"{RAW}/04_daily_challenge_screen.png", 520)
front = phone(f"{RAW}/05_daily_challenge_board.png", 560)
shadow_paste(img, back, (24, y + 160), opacity=50)
shadow_paste(img, front, (W - 560 - 24, y + 280), opacity=80)
save(img, "07_daily_challenge.png")

# 8 ─ Themes (themes screen + real boards in four themes) ─────────────────
img = background()
brand(img)
y = headline(img, "Collect", "43 Themes")
chips(img, ["Earn coins", "Unlock new looks"], y + 34)
back = phone(f"{RAW}/09_themes_top.png", 500)
shadow_paste(img, back, (40, y + 170), opacity=55)
themed = [(rendered(120), "Neon Glow"), (rendered(180), "Galaxy"),
          (rendered(90), "Sakura Garden"), (rendered(140), "Golden Luxury")]
side = 235
for i, (p, name) in enumerate(themed):
    x = 565 + (i % 2) * (side + 20)
    yy = y + 190 + (i // 2) * (side + 92 + 24)
    shadow_paste(img, board_card(p, side, name), (x, yy), blur=20, offset=(0, 12), opacity=45)
save(img, "08_collect_43_themes.png")
