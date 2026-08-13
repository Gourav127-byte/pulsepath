# PulsePath promotional video

Standalone 24-second vertical promo assembled from the real PulsePath logo,
original startup sound, and physical-device Today, Goals, and Profile captures.
No Flutter or backend production source is involved.

Render again with:

```powershell
python -m venv .\promo\.venv
.\promo\.venv\Scripts\python.exe -m pip install Pillow imageio-ffmpeg
.\promo\.venv\Scripts\python.exe .\promo\render_promo.py
```

Output: `promo/pulsepath_whatsapp_status.mp4` (720×1280, H.264/AAC).

Render the original PulsePath cinematic soundtrack and muxed promo with:

```powershell
.\promo\.venv\Scripts\python.exe .\promo\render_soundtrack.py
```

Soundtrack: `promo/pulsepath_original_soundtrack.wav`  
Final scored video: `promo/pulsepath_whatsapp_status_with_original_soundtrack.mp4`

## V2 cinematic trailer

```powershell
.\promo\.venv\Scripts\python.exe .\promo\render_promo_v2.py
```

- `pulsepath_promo_v2_sound_design.mp4`: subtle original PulsePath effects
- `pulsepath_promo_v2_music_ready.mp4`: silent master for licensed music
- `pulsepath_v2_sound_design.wav`: standalone effects mix
