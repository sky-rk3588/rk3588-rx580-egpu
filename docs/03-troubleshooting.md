# 3. Troubleshooting

Symptom first. Each entry says how to tell it apart from its neighbours.

---

## `probe with driver rockchip-dw-pcie failed with error -110`

Appears **with the slot empty too** — that is the tell. It is the PHY,
not the card, not the power supply, despite what the message says.

```
phy phy-fee80000.phy.1: lock failed 0x7, ...
```

`0x7` where the driver wants `0xf`. See
[02-kernel.md §1](02-kernel.md#1-the-pcie-phy-never-locks).

If you see `-110` **only with a card installed**, that is a different
problem — check power and the riser first.

---

## The card is not in `lspci`

```
lspci | grep -i -E 'vga|display|amd'
```

Nothing? Then the link never came up. Check, in this order:

```
dmesg | grep -i -E 'pcie|phy'
```

- `phy lock failed` → the PHY patch above
- `link up` present but no device → riser, seating, card power
- nothing about `pcie3x4` at all → the controller did not probe

`glxinfo` is **not** a test for this. It reports the default GPU, which
is the SoC's. Use `lspci` and `vulkaninfo --summary`.

---

## `ring test on gfx failed (-110)`

The card enumerated, firmware loaded, the first ring never completes.
Coherency. See [02-kernel.md §2](02-kernel.md#2-amdgpu-loads-the-ring-test-times-out).

---

## Resizable BAR

An 8 GB card advertising ReBAR asks for an 8 GB prefetchable aperture.
This board's MEM64 window is **1 GB**. The request cannot be satisfied
and BAR assignment fails.

```
options amdgpu rebar=0
```

Module parameters here apply **only across a reboot** — `rmmod amdgpu`
fails while the HDMI audio component holds a reference.

---

## HDR picture is green / washed out

Two different things, do not confuse them:

| | Green cast, only in HDR | Pale/flat, HDR *and* on other monitors |
|---|---|---|
| Cause | DCE BT.2020 CSC bypass | compositor mapping SDR content into HDR |
| Fix | kernel, see [02-kernel.md §4](02-kernel.md#4-hdr-output-is-green) | raise the compositor's SDR brightness |

The second one is not a bug. With HDR on, a compositor renders SDR
content (desktop, wallpaper, most browser video) at a chosen nit level —
200 by default in KWin, which looks dim on a TV that does 1000. In KDE:

```
kscreen-doctor output.<NAME>.sdr-brightness.350
```

**Diagnostic rule of thumb:** if two monitors on two *different drivers*
look equally wrong, the compositor is doing it, not the driver.

---

## Browser HDR video looks flat while the TV's own app looks great

Expected, and not a driver problem. Browsers here hardware-decode 10-bit
HDR and then tone-map it to SDR for display; the compositor shows that
at its SDR brightness. For real passthrough use a player that negotiates
HDR with the compositor — see [05-gaming.md](05-gaming.md#video-playback).

---

## GPU VM faults during benchmarks

```
amdgpu: ... VM fault ... read from TC
```

Seen here, contained — nothing crashed and scores were reproducible.
Ruled out: runtime PM (`runpm=0` changed nothing). Suspected: page-table
write ordering over non-coherent PCIe. A cheap next experiment is
`amdgpu.vm_update_mode=3` (CPU writes PTEs instead of SDMA), which is
diagnostic either way.

---

## Full-screen on the TV caps at ~47 FPS

Not the card. With two displays, the compositor renders on the SoC's GPU
and the frame is copied across PCIe to the AMD card. Windowed tests on
the same scene run an order of magnitude faster.

If you want the card to do the compositing too, look at
`KWIN_DRM_DEVICES`, or simply run with only the card's display attached.

---

## Overclocking notes

If you use LACT:

- Its profile must be applied **on every boot** (`lactd` service).
- Polaris shows idle memory-clock flicker on automatic DPM; pinning the
  VRAM state stops it.
- Validated here: 1450 MHz core at 1.2 V, memory 2025 MHz. 1500 MHz was
  not stable at that voltage — three hard freezes, one with no log at
  all (GPU hang taking the CPU's MMIO access with it).
- Benchmark with only one display attached, or the numbers measure the
  cross-GPU copy instead of the card.
