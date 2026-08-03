# 5. Gaming

## The thing to understand first

This host is **arm64**. Almost every commercial game is **x86-64**. So
there are two very different situations:

| | What runs | What the FPS measures |
|---|---|---|
| **Native arm64 game** | GPU + CPU directly | the graphics card |
| **x86 game** | x86→arm64 translation, then GPU | mostly the translation layer |

Both are worth testing, but only the first tells you what the card can
do. A low number on an x86 title is usually the CPU translating, not the
RX 580 struggling.

## Measured here (x86 titles, through emulation)

Steam, 4K output on the TV:

| Game | Settings | FPS | Notes |
|---|---|---|---|
| War Thunder | 4K low | 50–60 | test flight |
| Counter-Strike: Source | 4K high | ~60 | comfortable |
| CS:GO | 4K low | 20–40 | varies with server and player count |

At 1440p these improve substantially — 4K here was for testing, not for
playing. The bottleneck at low settings is the CPU side.

## Native arm64 titles — the honest test

All of these are in Debian/Ubuntu and build for arm64, so **no emulation
at all**:

```
sudo apt install supertuxkart 0ad luanti neverball openarena
```

| Game | Why it is useful | Load |
|---|---|---|
| **SuperTuxKart** | modern renderer, real shaders, easy to reach a steady scene | GPU |
| **0 A.D.** | large unit counts, big draw-call load | CPU-heavy |
| **Luanti** (Minetest) | huge view distances, simple shaders | mixed |
| **OpenArena** | old but pushes very high frame rates | tests the display path |
| **Neverball** | light, good for a smoke test | light |

Suggested method, so numbers are comparable:

1. One display attached (the card's) — otherwise you measure the
   cross-GPU copy, not the GPU. See
   [03-troubleshooting.md](03-troubleshooting.md#full-screen-on-the-tv-caps-at-47-fps).
2. Fixed resolution and settings, written down.
3. Same scene each run; three runs, report the middle one.

## On-screen numbers

MangoHud gives FPS, frame times, GPU clock and temperature as an
overlay, and can log to CSV:

```
sudo apt install mangohud goverlay
```

Steam: right-click the game → Properties → Launch Options:

```
mangohud %command%
```

Shortcuts (default): `Right Shift + F12` toggles the overlay,
`Left Shift + F2` starts/stops logging. `mangoplot *.csv` turns a log
into a frame-time graph. Compare **1% lows**, not averages — the average
hides the stutter you actually feel.

For OpenGL programs that MangoHud does not hook:

```
GALLIUM_HUD=fps,frametime glmark2
```

## Video playback

Two separate abilities that are easy to confuse:

- **Hardware decoding** — the card's UVD handles H.264, HEVC 8/10-bit
  and VP9. It does **not** do AV1 (Polaris predates it), so an AV1
  stream falls back to software and drops frames badly at 4K.
- **HDR output** — sending PQ/BT.2020 to the TV instead of tone-mapping
  to SDR first. Browsers here do the first but not the second.

`mpv` does both, if you point it at the card and ask for the colorspace
hint:

```
LIBVA_DRIVER_NAME=radeonsi \
MESA_VK_DEVICE_SELECT=1002:67df \
mpv --vo=gpu-next --gpu-api=vulkan \
    --target-colorspace-hint=yes \
    --hwdec=vaapi --vaapi-device=/dev/dri/renderD129 \
    <file-or-url>
```

Adjust the render node (`ls -l /sys/class/drm/renderD*/device/driver` to
find which is `amdgpu`) and the PCI id for your card. For YouTube, ask
yt-dlp for VP9 rather than AV1:

```
--ytdl-format='bestvideo[vcodec^=vp09.02]+bestaudio/bestvideo[vcodec!^=av01]+bestaudio'
```

If the TV switches itself into HDR mode and highlights start to pop, the
passthrough is working.
