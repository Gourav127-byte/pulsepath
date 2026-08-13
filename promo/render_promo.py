from __future__ import annotations

import math
import subprocess
from pathlib import Path

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = Path(__file__).resolve().parent
WIDTH, HEIGHT, FPS, DURATION = 720, 1280, 24, 24

COLORS = {
    "ink": (5, 7, 16),
    "surface": (16, 20, 34),
    "white": (245, 246, 255),
    "muted": (163, 169, 193),
    "violet": (151, 112, 255),
    "blue": (75, 130, 255),
    "cyan": (44, 222, 235),
}

FONT_REGULAR = Path("C:/Windows/Fonts/segoeui.ttf")
FONT_SEMIBOLD = Path("C:/Windows/Fonts/seguisb.ttf")
FONT_BOLD = Path("C:/Windows/Fonts/segoeuib.ttf")


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD if bold else FONT_REGULAR
    if bold and not path.exists():
        path = FONT_SEMIBOLD
    return ImageFont.truetype(str(path), size)


def background() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT), COLORS["ink"])
    px = image.load()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            violet = max(0.0, 1.0 - math.hypot(x - 90, y - 1040) / 760)
            cyan = max(0.0, 1.0 - math.hypot(x - 690, y - 170) / 650)
            px[x, y] = (
                int(5 + 17 * violet),
                int(7 + 7 * violet + 10 * cyan),
                int(16 + 32 * violet + 25 * cyan),
            )
    return image


BASE = background()


def centered_text(
    image: Image.Image,
    text: str,
    y: int,
    size: int,
    color: tuple[int, int, int],
    *,
    bold: bool = False,
    alpha: float = 1.0,
) -> None:
    layer = Image.new("RGBA", image.size)
    draw = ImageDraw.Draw(layer)
    text_font = font(size, bold)
    box = draw.textbbox((0, 0), text, font=text_font)
    x = (WIDTH - (box[2] - box[0])) // 2
    draw.text((x, y), text, font=text_font, fill=(*color, int(255 * alpha)))
    image.alpha_composite(layer)


def glow_orb(image: Image.Image, xy: tuple[int, int], radius: int, color: tuple[int, int, int], alpha: int) -> None:
    layer = Image.new("RGBA", image.size)
    draw = ImageDraw.Draw(layer)
    x, y = xy
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(*color, alpha))
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius // 2)))


def intro_scene(t: float, second: bool = False) -> Image.Image:
    image = BASE.copy().convert("RGBA")
    glow_orb(image, (110, 920), 250, COLORS["violet"], 35)
    glow_orb(image, (620, 260), 210, COLORS["cyan"], 25)
    pulse = 0.75 + 0.25 * math.sin(t * math.pi)
    line = "One dream. A lot of learning." if second else "It started as just an idea..."
    centered_text(image, line, 545, 39 if second else 42, COLORS["white"], bold=True, alpha=pulse)
    centered_text(image, "PULSEPATH", 1125, 18, COLORS["cyan"], bold=True, alpha=0.75)
    return image


def logo_scene(t: float) -> Image.Image:
    image = BASE.copy().convert("RGBA")
    glow_orb(image, (360, 610), int(280 + 12 * math.sin(t * 4)), COLORS["violet"], 55)
    logo = Image.open(ROOT / "assets/branding/pulsepath_logo.png").convert("RGBA")
    size = int(385 + 18 * min(t, 1.0))
    logo.thumbnail((size, size), Image.Resampling.LANCZOS)
    image.alpha_composite(logo, ((WIDTH - logo.width) // 2, 355))
    centered_text(image, "Move with purpose.", 810, 30, COLORS["white"], bold=True)
    centered_text(image, "Built one step at a time.", 858, 22, COLORS["muted"])
    return image


def rounded_screenshot(path: Path, crop: tuple[int, int, int, int] | None = None) -> Image.Image:
    source = Image.open(path).convert("RGB")
    if crop:
        source = source.crop(crop)
    target_w, target_h = 630, 1120
    ratio = max(target_w / source.width, target_h / source.height)
    source = source.resize((int(source.width * ratio), int(source.height * ratio)), Image.Resampling.LANCZOS)
    left = (source.width - target_w) // 2
    top = (source.height - target_h) // 2
    source = source.crop((left, top, left + target_w, top + target_h)).convert("RGBA")
    mask = Image.new("L", source.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, target_w, target_h), radius=36, fill=255)
    source.putalpha(mask)
    return source


TODAY = rounded_screenshot(ROOT / "build/phase9a_physical/today_after_retry.png", (0, 55, 720, 1430))
SCORE = rounded_screenshot(ROOT / "build/phase9a_physical/today_after_retry.png", (0, 120, 720, 1060))
ACTIVITY = rounded_screenshot(ROOT / "build/phase9a_physical/today_after_retry.png", (0, 650, 720, 1430))
GOALS = rounded_screenshot(ROOT / "build/phase9a_physical/goals_fresh.png", (0, 55, 720, 1430))
PROFILE = rounded_screenshot(ROOT / "build/phase9a_physical/profile.png", (0, 55, 720, 1430))


def app_scene(shot: Image.Image, label: str, t: float) -> Image.Image:
    image = BASE.copy().convert("RGBA")
    shadow = Image.new("RGBA", image.size)
    ImageDraw.Draw(shadow).rounded_rectangle((35, 45, 685, 1205), radius=45, fill=(0, 0, 0, 175))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(22)))
    scale = 1.0 + min(t, 3.0) * 0.004
    w, h = int(shot.width * scale), int(shot.height * scale)
    moving = shot.resize((w, h), Image.Resampling.LANCZOS)
    image.alpha_composite(moving, ((WIDTH - w) // 2, 62 - (h - shot.height) // 2))
    badge = Image.new("RGBA", image.size)
    draw = ImageDraw.Draw(badge)
    text_font = font(31, True)
    box = draw.textbbox((0, 0), label, font=text_font)
    bw = box[2] - box[0] + 56
    draw.rounded_rectangle(((WIDTH - bw) // 2, 1138, (WIDTH + bw) // 2, 1218), radius=40, fill=(10, 13, 25, 235), outline=(*COLORS["violet"], 150), width=2)
    draw.text(((WIDTH - (box[2] - box[0])) // 2, 1157), label, font=text_font, fill=COLORS["white"])
    image.alpha_composite(badge)
    return image


def broken_scene(t: float) -> Image.Image:
    image = Image.new("RGBA", (WIDTH, HEIGHT), (*COLORS["ink"], 255))
    glow_orb(image, (360, 640), 190, COLORS["violet"], int(25 + 20 * abs(math.sin(t * 12))))
    centered_text(image, "Broken.", 565, 62, COLORS["white"], bold=True)
    centered_text(image, "Every bug taught me something.", 655, 22, COLORS["muted"])
    return image


def ending_scene(t: float) -> Image.Image:
    image = BASE.copy().convert("RGBA")
    glow_orb(image, (360, 360), 260, COLORS["violet"], 45)
    logo = Image.open(ROOT / "assets/branding/pulsepath_logo.png").convert("RGBA")
    logo.thumbnail((235, 235), Image.Resampling.LANCZOS)
    image.alpha_composite(logo, ((WIDTH - logo.width) // 2, 180))
    centered_text(image, "My first app — PulsePath", 520, 39, COLORS["white"], bold=True)
    if t > 1.2:
        centered_text(image, "Still building. Still learning.", 610, 27, COLORS["muted"])
    if t > 2.8:
        centered_text(image, "And this is only the beginning.", 685, 29, COLORS["cyan"], bold=True)
    centered_text(image, "PULSEPATH", 1110, 18, COLORS["violet"], bold=True)
    return image


def frame_at(t: float) -> Image.Image:
    if t < 2.7:
        image = intro_scene(t)
    elif t < 5.0:
        image = intro_scene(t - 2.7, second=True)
    elif t < 7.1:
        image = logo_scene(t - 5.0)
    elif t < 9.7:
        image = app_scene(TODAY, "Designed.", t - 7.1)
    elif t < 11.9:
        image = app_scene(SCORE, "Built.", t - 9.7)
    elif t < 13.2:
        image = broken_scene(t - 11.9)
    elif t < 15.3:
        image = app_scene(ACTIVITY, "Debugged.", t - 13.2)
    elif t < 17.4:
        image = app_scene(GOALS, "Built again.", t - 15.3)
    elif t < 19.2:
        image = app_scene(PROFILE, "Made personal.", t - 17.4)
    else:
        image = ending_scene(t - 19.2)

    fade = min(1.0, t / 0.45, (DURATION - t) / 0.65)
    if fade < 1:
        black = Image.new("RGBA", image.size, (0, 0, 0, 255))
        image = Image.blend(black, image, max(0.0, fade))
    return image.convert("RGB")


def run() -> None:
    OUT.mkdir(exist_ok=True)
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    silent = OUT / "pulsepath_promo_silent.mp4"
    final = OUT / "pulsepath_whatsapp_status.mp4"

    encode = subprocess.Popen(
        [
            ffmpeg, "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
            "-s", f"{WIDTH}x{HEIGHT}", "-r", str(FPS), "-i", "-",
            "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "20",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(silent),
        ],
        stdin=subprocess.PIPE,
    )
    assert encode.stdin is not None
    for index in range(DURATION * FPS):
        encode.stdin.write(frame_at(index / FPS).tobytes())
    encode.stdin.close()
    if encode.wait() != 0:
        raise SystemExit("Video encoding failed")

    audio = ROOT / "assets/audio/pulsepath_startup.wav"
    subprocess.run(
        [
            ffmpeg, "-y", "-i", str(silent), "-i", str(audio),
            "-f", "lavfi", "-i", f"sine=frequency=110:duration={DURATION}",
            "-f", "lavfi", "-i", f"sine=frequency=164.81:duration={DURATION}",
            "-filter_complex",
            "[1:a]adelay=5000|5000,volume=0.72[brand];"
            "[2:a]volume=0.035,afade=t=in:st=0:d=2,afade=t=out:st=21:d=3[low];"
            "[3:a]volume=0.018,afade=t=in:st=3:d=3,afade=t=out:st=20:d=4[high];"
            "[brand][low][high]amix=inputs=3:duration=longest:normalize=0,alimiter=limit=0.9[a]",
            "-map", "0:v:0", "-map", "[a]", "-c:v", "copy", "-c:a", "aac",
            "-b:a", "128k", "-t", str(DURATION), "-movflags", "+faststart", str(final),
        ],
        check=True,
    )
    silent.unlink(missing_ok=True)
    print(final)


if __name__ == "__main__":
    run()
