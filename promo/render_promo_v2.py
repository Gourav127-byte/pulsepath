from __future__ import annotations

import math
import subprocess
import wave
from array import array
from pathlib import Path

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = Path(__file__).resolve().parent
W, H, FPS, LENGTH = 1080, 1920, 24, 24
INK = (2, 4, 11)
WHITE = (246, 247, 255)
MUTED = (164, 170, 194)
VIOLET = (151, 112, 255)
BLUE = (73, 127, 255)
CYAN = (45, 221, 235)
FONT = Path("C:/Windows/Fonts/segoeui.ttf")
BOLD = Path("C:/Windows/Fonts/segoeuib.ttf")


def fnt(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(BOLD if bold else FONT), size)


def ease(x: float) -> float:
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def backdrop() -> Image.Image:
    small = Image.new("RGB", (270, 480), INK)
    pixels = small.load()
    for y in range(480):
        for x in range(270):
            v = max(0.0, 1 - math.hypot(x - 35, y - 395) / 245)
            c = max(0.0, 1 - math.hypot(x - 250, y - 55) / 205)
            pixels[x, y] = (int(2 + 20 * v), int(4 + 7 * v + 14 * c), int(11 + 43 * v + 34 * c))
    return small.resize((W, H), Image.Resampling.BICUBIC)


BASE = backdrop()
LOGO = Image.open(ROOT / "assets/branding/pulsepath_logo.png").convert("RGBA")


def text_center(image: Image.Image, text: str, y: int, size: int, color=WHITE, bold=False, alpha=255, tracking=0) -> None:
    layer = Image.new("RGBA", image.size)
    draw = ImageDraw.Draw(layer)
    font = fnt(size, bold)
    if tracking:
        widths = [draw.textlength(char, font=font) for char in text]
        total = sum(widths) + tracking * (len(text) - 1)
        x = (W - total) / 2
        for char, width in zip(text, widths):
            draw.text((x, y), char, font=font, fill=(*color, alpha))
            x += width + tracking
    else:
        box = draw.textbbox((0, 0), text, font=font)
        draw.text(((W - box[2] + box[0]) / 2, y), text, font=font, fill=(*color, alpha))
    image.alpha_composite(layer)


def glow(image: Image.Image, x: int, y: int, radius: int, color, alpha: int) -> None:
    # Render broad light at 1/8 resolution. It is visually identical after the
    # soft upscale, while avoiding a huge full-frame Gaussian blur every frame.
    divisor = 8
    layer = Image.new("RGBA", (W // divisor, H // divisor))
    draw = ImageDraw.Draw(layer)
    sx, sy, sr = x // divisor, y // divisor, max(1, radius // divisor)
    draw.ellipse((sx - sr, sy - sr, sx + sr, sy + sr), fill=(*color, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(max(1, sr // 2)))
    image.alpha_composite(layer.resize((W, H), Image.Resampling.BILINEAR))


def opening(t: float) -> Image.Image:
    image = BASE.copy().convert("RGBA")
    glow(image, 260, 1030, 430, VIOLET, 36)
    glow(image, 920, 340, 310, CYAN, 22)
    a = int(255 * ease(t / 0.75) * ease((2 - t) / 0.35))
    text_center(image, "It started with a dream.", 865, 57, WHITE, True, a)
    text_center(image, "PULSEPATH", 1715, 21, CYAN, True, int(a * 0.72), 5)
    return image


def line_progress(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], progress: float, width: int = 8) -> None:
    lengths = [math.dist(points[i], points[i + 1]) for i in range(len(points) - 1)]
    remaining = sum(lengths) * progress
    visible = [points[0]]
    for index, length in enumerate(lengths):
        if remaining >= length:
            visible.append(points[index + 1])
            remaining -= length
        elif remaining > 0:
            p, q = points[index], points[index + 1]
            ratio = remaining / length
            visible.append((int(p[0] + (q[0] - p[0]) * ratio), int(p[1] + (q[1] - p[1]) * ratio)))
            break
        else:
            break
    if len(visible) > 1:
        draw.line(visible, fill=CYAN, width=width, joint="curve")


def startup(t: float) -> Image.Image:
    # Faithful standalone rendering of the real Flutter startup sequence:
    # aurora -> rings/logo -> portal/pulse/stat chips -> wave/flash.
    p = t / 3.0
    image = BASE.copy().convert("RGBA")
    cx, cy = W // 2, 755
    opening_p = ease(p / 0.38)
    portal_p = ease((p - 0.31) / 0.42)
    finish = ease((p - 0.70) / 0.23)
    glow(image, cx, cy, int(410 + 35 * math.sin(t * 2.3)), VIOLET, int(45 * opening_p))
    layer = Image.new("RGBA", image.size)
    draw = ImageDraw.Draw(layer)
    ring_alpha = int(150 * opening_p * max(0, 1 - ease((p - 0.45) / 0.18)))
    for radius, color in [(225, VIOLET), (175, BLUE), (125, CYAN)]:
        r = int(radius * (0.55 + opening_p * 0.45))
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(*color, ring_alpha), width=3)
    image.alpha_composite(layer)

    logo_alpha = opening_p * max(0, 1 - ease((p - 0.43) / 0.17))
    logo = LOGO.copy()
    logo.thumbnail((240, 240), Image.Resampling.LANCZOS)
    logo.putalpha(logo.getchannel("A").point(lambda value: int(value * logo_alpha)))
    image.alpha_composite(logo, ((W - logo.width) // 2, cy - logo.height // 2))

    if portal_p > 0:
        portal = Image.new("RGBA", image.size)
        pd = ImageDraw.Draw(portal)
        scale = 0.72 + portal_p * 0.28
        pw, ph = int(330 * scale), int(490 * scale)
        box = (cx - pw // 2, cy - ph // 2, cx + pw // 2, cy + ph // 2)
        pd.rounded_rectangle(box, radius=pw // 2, fill=(8, 11, 27, 248), outline=(*CYAN, int(210 * portal_p)), width=7)
        image.alpha_composite(portal)
        pulse = Image.new("RGBA", image.size)
        pts = [(cx - 235, cy), (cx - 100, cy), (cx - 70, cy - 95), (cx - 38, cy + 85), (cx, cy - 45), (cx + 45, cy + 28), (cx + 85, cy), (cx + 235, cy)]
        line_progress(ImageDraw.Draw(pulse), pts, ease((p - 0.38) / 0.20), 10)
        image.alpha_composite(pulse)
        for x, y, value, label, start in [
            (95, 605, "7,842", "STEPS", 0.49), (785, 745, "77", "DAILY SCORE", 0.54), (130, 895, "46", "ACTIVE MIN", 0.59)
        ]:
            a = int(235 * ease((p - start) / 0.13) * max(0, 1 - ease((p - 0.72) / 0.10)))
            chip = Image.new("RGBA", image.size)
            cd = ImageDraw.Draw(chip)
            cd.rounded_rectangle((x, y, x + 205, y + 112), radius=27, fill=(16, 15, 36, a), outline=(255, 255, 255, int(a * 0.12)), width=2)
            cd.text((x + 25, y + 19), value, font=fnt(29, True), fill=(*WHITE, a))
            cd.text((x + 25, y + 65), label, font=fnt(14), fill=(*MUTED, a))
            image.alpha_composite(chip)

    title_alpha = int(255 * ease((p - 0.20) / 0.16) * max(0, 1 - ease((p - 0.48) / 0.13)))
    text_center(image, "PulsePath", 1025, 45, WHITE, True, title_alpha)
    text_center(image, "MOVE  •  BUILD  •  REPEAT", 1090, 17, MUTED, False, title_alpha, 4)
    text_center(image, "So I started building.", 1535, 38, WHITE, True, int(255 * ease(t / 0.55)))

    if finish > 0:
        wave = Image.new("RGBA", image.size)
        wd = ImageDraw.Draw(wave)
        y = int(H * 0.63 + H * 0.24 * (1 - finish))
        polygon = [(0, y), (200, y - 80), (390, y + 30), (570, y - 42), (790, y - 110), (W, y - 35), (W, H), (0, H)]
        wd.polygon(polygon, fill=(*VIOLET, int(210 * finish)))
        image.alpha_composite(wave)
        glow(image, cx, cy, int(35 + finish * 420), CYAN, int(100 * math.sin(finish * math.pi)))
    return image


def load_screen(filename: str) -> Image.Image:
    source = Image.open(ROOT / filename).convert("RGB").crop((0, 55, 720, 1430))
    return source


TODAY = load_screen("build/phase9a_physical/today_after_retry.png")
GOALS = load_screen("build/phase9a_physical/goals_fresh.png")
PROFILE = load_screen("build/phase9a_physical/profile.png")


def screen_scene(source: Image.Image, label: str, t: float, duration: float, zoom=1.0, focus_y=0.5, small_label=None) -> Image.Image:
    image = BASE.copy().convert("RGBA")
    glow(image, 540, 1020, 520, VIOLET, 28)
    frame_w, frame_h = 900, 1660
    scale = max(frame_w / source.width, frame_h / source.height) * (zoom + 0.018 * ease(t / duration))
    shot = source.resize((int(source.width * scale), int(source.height * scale)), Image.Resampling.LANCZOS).convert("RGBA")
    x = (W - shot.width) // 2
    travel = max(0, shot.height - frame_h)
    y = 105 - int(travel * focus_y)
    mask = Image.new("L", (frame_w, frame_h))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, frame_w, frame_h), radius=54, fill=255)
    viewport = Image.new("RGBA", (frame_w, frame_h))
    viewport.alpha_composite(shot, (x - 90, y - 105))
    viewport.putalpha(mask)
    shadow = Image.new("RGBA", (W // 4, H // 4))
    ImageDraw.Draw(shadow).rounded_rectangle((19, 23, 251, 448), radius=16, fill=(0, 0, 0, 190))
    shadow = shadow.filter(ImageFilter.GaussianBlur(9)).resize((W, H), Image.Resampling.BILINEAR)
    image.alpha_composite(shadow)
    image.alpha_composite(viewport, (90, 105))
    text_center(image, label, 1570, 53, WHITE, True)
    if small_label:
        text_center(image, small_label, 1645, 21, CYAN, True, 230, 3)
    return image


def development(t: float) -> Image.Image:
    image = Image.new("RGBA", (W, H), (*INK, 255))
    words = [("BROKE.", 0.0, 0.85), ("DEBUGGED.", 0.9, 1.85), ("REBUILT.", 1.9, 3.0)]
    for word, start, end in words:
        if start <= t < end:
            local = (t - start) / (end - start)
            color = MUTED if word == "BROKE." else (CYAN if word == "REBUILT." else WHITE)
            glow(image, 540, 930, int(180 + 80 * local), VIOLET, 25 if word != "REBUILT." else 55)
            jitter = int(math.sin(t * 47) * 5 * (1 - local)) if word == "BROKE." else 0
            layer = Image.new("RGBA", image.size)
            d = ImageDraw.Draw(layer)
            font = fnt(69, True)
            box = d.textbbox((0, 0), word, font=font)
            d.text(((W - box[2] + box[0]) / 2 + jitter, 870), word, font=font, fill=(*color, int(255 * ease(local / 0.22))))
            image.alpha_composite(layer)
    return image


def finale(t: float) -> Image.Image:
    image = BASE.copy().convert("RGBA")
    glow(image, 540, 675, int(410 + 25 * math.sin(t * 1.8)), VIOLET, 52)
    glow(image, 760, 545, 270, CYAN, 24)
    logo = LOGO.copy()
    size = int(345 + 25 * ease(t / 2.0))
    logo.thumbnail((size, size), Image.Resampling.LANCZOS)
    image.alpha_composite(logo, ((W - logo.width) // 2, 360))
    a1 = int(255 * ease(t / 0.6))
    text_center(image, "My first app.", 850, 42, MUTED, False, a1)
    text_center(image, "PulsePath.", 915, 76, WHITE, True, a1)
    if t > 1.35:
        text_center(image, "From an idea to something real.", 1085, 34, CYAN, True, int(255 * ease((t - 1.35) / 0.6)))
    if t > 3.0:
        text_center(image, "And I'm just getting started.", 1190, 25, MUTED, False, int(255 * ease((t - 3.0) / 0.6)))
    return image


def raw_scene(t: float) -> Image.Image:
    if t < 2: return opening(t)
    if t < 5: return startup(t - 2)
    if t < 8: return screen_scene(TODAY, "DESIGNED.", t - 5, 3, 1.0, 0.05, "DAILY SCORE")
    if t < 11: return screen_scene(GOALS, "BUILT.", t - 8, 3, 1.0, 0.08, "GOALS & PROGRESS")
    if t < 14: return development(t - 11)
    if t < 15.25: return screen_scene(TODAY, "Daily Score", t - 14, 1.25, 1.08, 0.05)
    if t < 16.5: return screen_scene(TODAY, "Activity", t - 15.25, 1.25, 1.12, 0.72)
    if t < 17.75: return screen_scene(GOALS, "Goals", t - 16.5, 1.25, 1.08, 0.20)
    if t < 19: return screen_scene(PROFILE, "Profile", t - 17.75, 1.25, 1.08, 0.68)
    return finale(t - 19)


def frame(t: float) -> Image.Image:
    image = raw_scene(t).convert("RGB")
    # Short cinematic dips smooth scene changes without template-like wipes.
    nearest = min(abs(t - cut) for cut in [0, 2, 5, 8, 11, 14, 15.25, 16.5, 17.75, 19, 24])
    if nearest < 0.13:
        image = Image.blend(Image.new("RGB", (W, H), INK), image, 0.55 + 0.45 * nearest / 0.13)
    global_fade = min(1.0, t / 0.4, (24 - t) / 0.75)
    return Image.blend(Image.new("RGB", (W, H), INK), image, max(0, global_fade))


def render_sound_design() -> Path:
    rate = 44_100
    samples = array("h", [0]) * (rate * LENGTH)
    def add(start: float, duration: float, frequency: float, gain: float, shimmer=False):
        first, count = int(start * rate), int(duration * rate)
        for i in range(count):
            if first + i >= len(samples): break
            p = i / count
            env = math.sin(math.pi * p) ** 2
            freq = frequency * (1 + (1.5 * p if shimmer else 0))
            value = gain * env * math.sin(math.tau * freq * i / rate)
            samples[first + i] = max(-32767, min(32767, samples[first + i] + int(value * 32767)))
    for beat in [5.0, 8.0, 11.0, 12.0, 13.0, 14.0, 15.25, 16.5, 17.75, 19.0]:
        add(beat - 0.11, 0.35, 64, 0.055)
    for cut in [2.0, 5.0, 8.0, 11.0, 14.0, 19.0]:
        add(cut - 0.28, 0.55, 390, 0.022, True)
    with wave.open(str(ROOT / "assets/audio/pulsepath_startup.wav"), "rb") as src:
        startup = array("h", src.readframes(src.getnframes()))
    offset = int(2 * rate)
    for i, value in enumerate(startup):
        samples[offset + i] = max(-32767, min(32767, samples[offset + i] + int(value * 0.72)))
    # Gentle end fade leaves room for a licensed music track above it.
    for i in range(int(2 * rate)):
        index = len(samples) - int(2 * rate) + i
        samples[index] = int(samples[index] * (1 - i / (2 * rate)))
    path = OUT / "pulsepath_v2_sound_design.wav"
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(rate); wav.writeframes(samples.tobytes())
    return path


def run() -> None:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    silent = OUT / "pulsepath_promo_v2_music_ready.mp4"
    process = subprocess.Popen([
        ffmpeg, "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(silent)
    ], stdin=subprocess.PIPE)
    assert process.stdin
    for index in range(FPS * LENGTH): process.stdin.write(frame(index / FPS).tobytes())
    process.stdin.close()
    if process.wait(): raise SystemExit("V2 video render failed")
    sound = render_sound_design()
    scored = OUT / "pulsepath_promo_v2_sound_design.mp4"
    subprocess.run([
        ffmpeg, "-loglevel", "error", "-y", "-i", str(silent), "-i", str(sound), "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy",
        "-c:a", "aac", "-b:a", "128k", "-t", str(LENGTH), "-movflags", "+faststart", str(scored)
    ], check=True)
    print(silent); print(scored); print(sound)


if __name__ == "__main__": run()
