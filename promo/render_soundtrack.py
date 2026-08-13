"""Render PulsePath's original promo soundtrack and mux it into the promo MP4.

The composition is synthesized from first principles: an original five-note
PulsePath motif, soft piano-like partials, ambient pads, pulse transients, and
the project's own startup sound. No third-party music or sampled melody is used.
"""

from __future__ import annotations

import math
import subprocess
import wave
from array import array
from pathlib import Path

import imageio_ffmpeg


ROOT = Path(__file__).resolve().parents[1]
PROMO = Path(__file__).resolve().parent
RATE = 44_100
DURATION = 24.0
FRAMES = int(RATE * DURATION)


def smoothstep(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def piano(t: float, start: float, frequency: float, length: float, gain: float) -> float:
    local = t - start
    if local < 0.0 or local >= length:
        return 0.0
    attack = smoothstep(local / 0.035)
    release = math.exp(-3.8 * local / length)
    tail = smoothstep((length - local) / 0.3)
    phase = math.tau * frequency * local
    body = math.sin(phase)
    body += 0.34 * math.sin(2.01 * phase + 0.15)
    body += 0.13 * math.sin(3.99 * phase + 0.4)
    return gain * attack * release * tail * body


def pad(t: float, start: float, end: float, frequencies: tuple[float, ...], gain: float) -> float:
    if t < start or t >= end:
        return 0.0
    local = t - start
    envelope = smoothstep(local / 1.3) * smoothstep((end - t) / 1.5)
    drift = 0.86 + 0.14 * math.sin(math.tau * 0.075 * t)
    total = 0.0
    for index, frequency in enumerate(frequencies):
        phase = math.tau * frequency * t + index * 0.73
        total += math.sin(phase) + 0.18 * math.sin(phase * 2.002)
    return gain * envelope * drift * total / len(frequencies)


def heartbeat(t: float, beat: float, gain: float) -> float:
    local = t - beat
    if not 0.0 <= local < 0.32:
        return 0.0
    first = math.exp(-35.0 * local) * math.sin(math.tau * 54.0 * local)
    second_local = local - 0.145
    second = 0.0
    if second_local >= 0.0:
        second = 0.65 * math.exp(-42.0 * second_local) * math.sin(math.tau * 61.0 * second_local)
    return gain * (first + second)


def transition(t: float, center: float, gain: float) -> float:
    local = t - (center - 0.23)
    if not 0.0 <= local < 0.46:
        return 0.0
    envelope = math.sin(math.pi * local / 0.46) ** 2
    frequency = 330.0 + 520.0 * local / 0.46
    return gain * envelope * math.sin(math.tau * frequency * local)


def read_startup_sound() -> tuple[int, list[float]]:
    path = ROOT / "assets/audio/pulsepath_startup.wav"
    with wave.open(str(path), "rb") as source:
        assert source.getnchannels() == 1 and source.getsampwidth() == 2
        rate = source.getframerate()
        samples = array("h", source.readframes(source.getnframes()))
    return rate, [sample / 32768.0 for sample in samples]


def render() -> None:
    # Original motif: D4, A4, C5, E5, D5. It rises with the product reveal and
    # resolves back to D for the final title, becoming PulsePath's sonic mark.
    motif = [
        (0.55, 293.66, 2.3, 0.15), (2.75, 440.00, 2.0, 0.14),
        (4.55, 523.25, 1.7, 0.13), (6.15, 659.25, 1.5, 0.12),
        (7.55, 587.33, 2.2, 0.14), (9.75, 440.00, 1.4, 0.13),
        (11.85, 293.66, 1.2, 0.10), (13.15, 349.23, 1.4, 0.13),
        (15.25, 440.00, 1.5, 0.14), (17.35, 523.25, 1.5, 0.14),
        (19.25, 587.33, 2.0, 0.14), (21.10, 659.25, 1.7, 0.13),
        (22.35, 587.33, 1.6, 0.16), (22.55, 293.66, 1.4, 0.10),
    ]
    beats = [7.15, 8.35, 9.55, 13.25, 14.35, 15.35, 16.35, 17.40, 18.35, 19.25, 20.25, 21.25, 22.25]
    accents = [2.70, 5.00, 7.10, 9.70, 11.90, 13.20, 15.30, 17.40, 19.20]
    startup_rate, startup = read_startup_sound()
    assert startup_rate == RATE

    pcm = array("h")
    for index in range(FRAMES):
        t = index / RATE
        value = 0.0
        value += pad(t, 0.0, 13.0, (73.42, 110.00, 146.83), 0.105)
        value += pad(t, 6.0, 23.95, (87.31, 130.81, 174.61, 220.00), 0.12)
        value += pad(t, 15.0, 24.0, (110.00, 146.83, 220.00, 293.66), 0.105)
        for note in motif:
            value += piano(t, *note)
        for beat in beats:
            value += heartbeat(t, beat, 0.12 if beat < 19.0 else 0.085)
        for accent in accents:
            value += transition(t, accent, 0.018)

        startup_index = index - int(5.0 * RATE)
        if 0 <= startup_index < len(startup):
            value += startup[startup_index] * 0.70

        # The complete piece breathes in, builds through the UI, then resolves.
        master = smoothstep(t / 0.8) * smoothstep((DURATION - t) / 1.6)
        value = math.tanh(value * 1.2) * master * 0.82
        sample = int(max(-1.0, min(1.0, value)) * 32767)
        pcm.append(sample)

    soundtrack = PROMO / "pulsepath_original_soundtrack.wav"
    with wave.open(str(soundtrack), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())

    video = PROMO / "pulsepath_whatsapp_status.mp4"
    muxed = PROMO / "pulsepath_whatsapp_status_with_original_soundtrack.mp4"
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    subprocess.run(
        [
            ffmpeg, "-y", "-i", str(video), "-i", str(soundtrack),
            "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy",
            "-c:a", "aac", "-b:a", "160k", "-t", str(DURATION),
            "-movflags", "+faststart", str(muxed),
        ],
        check=True,
    )
    print(soundtrack)
    print(muxed)


if __name__ == "__main__":
    render()
