# 4. Benchmarks — and what they actually measure

## Read this before quoting any number

Two traps on this machine, both of which produce numbers that look
authoritative and mean something else:

**1. Two displays means a PCIe copy per frame.** With a display on the
SoC's Mali *and* one on the card, the compositor renders on the Mali and
copies the AMD display's frames across PCIe. Full-screen on the TV caps
around 47 FPS that way — that is the copy, not the card. **Benchmark with
only one display attached.**

**2. glmark2 at 800x600 is CPU-bound here.** The A76 cores feed the
driver, not the GPU. It is fine for A/B comparisons of the *same* GPU
across kernel changes; it is meaningless for comparing two different
GPUs.

## Numbers from this machine

Mesa 26.3-devel, KDE Plasma / Wayland, CPU governors at `performance`,
benchmark processes pinned to the A76 cluster (`taskset -c 4-7`).

### SoC GPU (Mali-G610 MC4, Panfrost/panvk), for reference

| Test | Score |
|---|---|
| glmark2 (GL) | 2738 |
| glmark2-wayland | 2929 |
| glmark2-es2 | 3108 |
| glmark2-es2-wayland | 3121 |
| vkmark | 4076 |

clpeak on the Mali: 25 GB/s memory bandwidth, 484 GFLOPS FP32,
887 GFLOPS FP16.

### RX 580 (eGPU) via `DRI_PRIME=1`

| Test | Score |
|---|---|
| glmark2 | 1394 |
| glmark2-wayland | 1057 |

Lower than the Mali — and that is trap 1 and trap 2 together, not the
card being slow. A Polaris card is several times the Mali's throughput
in any GPU-bound test. Use a native arm64 game at a real resolution, on
a single attached display, to see it.

## Reproducing

```
sudo apt install glmark2 vkmark clpeak mesa-utils
```

```
# SoC GPU
taskset -c 4-7 glmark2-es2-wayland

# eGPU (OpenGL)
DRI_PRIME=1 taskset -c 4-7 glmark2

# which card a Vulkan app will pick
vulkaninfo --summary | grep -E 'deviceName|driverName'
```

Pin the card's clocks while measuring rather than relying on the
governor, and always run the baseline again at the end (A-B-A) — if the
first and last runs do not agree, the middle number is not a result.

## Thermals

Package around 50–57 °C under load with the case open; the card's own
cooler handles it. `sensors` and `amdgpu_top`/LACT show the card's own
sensors.
