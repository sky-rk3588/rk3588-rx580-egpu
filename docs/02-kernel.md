# 2. The kernel patches

Base: Collabora `rockchip-v7.0`. Patches are in [`../patches/`](../patches/).
Apply in the order below; each section says what breaks without it and
whether upstream already has a fix.

```
git am ../patches/*.patch
```

---

## 1. The PCIe PHY never locks

**Symptom** — on every boot, *with the slot empty*:

```
phy phy-fee80000.phy.1: lock failed 0x7, check input refclk and power supply
rockchip-dw-pcie a40000000.pcie: phy lock failed
rockchip-dw-pcie a40000000.pcie: probe with driver rockchip-dw-pcie failed with error -110
```

The controller never probes, so no card in that slot exists as far as
Linux is concerned. The message blames the reference clock and the power
supply, and it is wrong on both counts.

**Cause** — `phy-rockchip-snps-pcie3.c` polls `PHY{0,1}_STATUS1` for
SRAM init and requires `(reg & 0xf) == 0xf`. This silicon reports
`0x7`: bits 0–2 set, bit 3 never. The board's own EDK2 firmware brings
the same PHY up happily, because it checks **bit 0 only** — and so does
mainline Linux. The stricter mask is what fails here.

**Patch** — `phy-rockchip-snps-pcie3-rk3588-relax-SRAM-init-check-to.patch`

**Upstream** — mainline already checks bit 0; this only affects trees
carrying the stricter check.

---

## 2. `amdgpu` loads, the ring test times out

**Symptom**

```
amdgpu: ... ring test on gfx failed (-110)
```

The card enumerates, BARs are assigned, firmware loads, and then the
first command ring never completes.

**Cause** — arm64 PCIe here is not I/O-coherent in the way amdgpu
assumes. TTM maps buffers cached; the GPU reads stale data.

**Patch** — `drm-ttm-arm64-use-pgprot-dmacoherent-for-cached-mappings.patch`

Uses `pgprot_dmacoherent` for cached mappings so the CPU side is
non-cacheable-but-bufferable, which is what a non-snooping PCIe master
needs.

---

## 3. Unaligned MMIO traps and wrong MMIO attributes

**Symptom** — alignment faults, or subtly wrong register reads, once the
driver starts touching the card in anger.

**Cause** — arm64 requires Device memory attributes for MMIO and does not
permit unaligned access to it; the generic mapping paths do not
guarantee that for PCIe BARs.

**Patches** (Mario Bălănică's arm64 PCIe/GPU series)

```
arm64-mm-Handle-alignment-faults-arm-pcie-gpu-patches.patch
arm64-mm-Force-Device-mappings-for-PCIe-MMIO.patch
drm-Force-writecombined-mappings-for-DMA.patch
fixup-alignment-c-adapt-to-v7-0-kernel-neon-begin-end-API.patch
```

The last one is a build fixup only: `kernel_neon_begin()/end()` gained a
state argument in this tree.

**Credit** — the three functional patches are Mario Bălănică's work; the
author tested them with an RX 580 over an M.2 adapter. This project
carries them, it did not invent them.

---

## 4. HDR output is green

**Symptom** — with HDR enabled on an HDMI TV, the picture is washed out
with a heavy green cast. SDR on the same cable is fine. DisplayPort is
fine.

**Cause** — a 4K60 10-bit HDR mode on HDMI 2.0 does not fit in RGB, so
the stream becomes YCbCr 4:2:0, and with the compositor asking for
BT.2020 the output color space becomes `COLOR_SPACE_2020_YCBCR_LIMITED`.
On DCE (pre-Vega) `global_color_matrix[]` had **no BT.2020 entry**, so
`dce110_opp_set_csc_default()` programmed no matrix and
`configure_graphics_mode()` left `OUTPUT_CSC_GRPH_MODE` at 0 — bypass.
RGB pixels then go into the 4:2:0 formatter while the AVI infoframe says
YCbCr: luma lands on the green channel, Cb/Cr sit near mid scale.

**Upstream** — fixed in mainline by commit `51e6668ab4ba`
("drm/amd/display: add missing CSC entries for BT.2020 for DCE IPs"),
with the coefficients themselves corrected by Nathan Lucas in
[this series](https://lore.kernel.org/all/cover.1785616749.git.nlucasgit@gmail.com/)
(tested on this hardware). **If your kernel is new enough you do not need
anything here** — check whether `global_color_matrix[]` in
`drivers/gpu/drm/amd/display/dc/dce/dce_transform.c` has
`COLOR_SPACE_2020_YCBCR_LIMITED`.

Also included: `drm-amd-display-extend-420-pixel-phase-lock-wait-in-DCE.patch`,
which widens the `FMT_420_PIXEL_PHASE_LOCKED` poll. On this hardware that
bit never asserts and the timeout is harmless — the patch only stops the
log spam. It is **not** the green-picture fix, though it looked like it
for a while.

---

## Module parameters

In `/etc/modprobe.d/amdgpu-rebar.conf`:

```
options amdgpu rebar=0 runpm=0 ppfeaturemask=0xfff7ffff
```

- `rebar=0` — required, see
  [03-troubleshooting.md](03-troubleshooting.md#resizable-bar)
- `runpm=0` — runtime PM off. Not required for correctness here; it was
  set while chasing an unrelated fault and kept.
- `ppfeaturemask` — unlocks the overdrive interface for LACT.

## Building

```
make -j$(nproc) bindeb-pkg     # or your distro's usual route
```

Cross-compiling on a faster arm64 machine and copying the `.deb` across
is a lot quicker than building on the SBC. If your distribution keeps
out-of-tree modules in DKMS, remember that **every new kernel needs those
rebuilt** — the packages usually do it for you, but check.
