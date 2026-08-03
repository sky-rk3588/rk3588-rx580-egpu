# RX 580 as an external GPU on an Orange Pi 5 Plus (RK3588, arm64)

An 8 GB Polaris card, running over the board's M.2 M-key slot, driving a
4K HDR TV — and playing games at 4K.

```
Orange Pi 5 Plus (RK3588, 8x Cortex-A76/A55, arm64)
  └─ M.2 M-key (pcie3x4, Gen3 x4)
       └─ riser → PCIe x16 slot → XFX RX 580 8GB (Polaris10, DCE 11.2)
            └─ HDMI → Sony 65" 4K HDR10 TV
```

Everything here runs on **mainline-style kernels** (a Collabora rockchip
tree, v7.0). No vendor BSP, no closed drivers: `amdgpu` + Mesa `radeonsi`
+ `radv`, exactly as on a PC.

## Why this is not obvious

Plugging a PCIe graphics card into an ARM SBC fails in ways an x86 user
never sees. Four of them, in the order you hit them:

1. **The link never comes up.** The RK3588 PCIe 3.0 PHY is checked for
   SRAM init with a stricter mask than the hardware ever reports.
2. **`amdgpu` loads, then the ring test times out with `-110`.** ARM's
   PCIe is not cache-coherent the way amdgpu assumes.
3. **Unaligned MMIO traps.** The card's registers are mapped with
   attributes that arm64 does not allow for device memory.
4. **HDR output is green.** The DCE color-space conversion is left in
   bypass for BT.2020.

Each has a fix in [`patches/`](patches/), each is explained in
[`docs/`](docs/). Three of the four are relevant to *any* AMD card on
*any* RK3588 board; the fourth to any pre-Vega AMD card on any host.

## Results

Measured on this machine, Mesa 26.3-devel, KDE Plasma on Wayland.

### Synthetic

| | Mali-G610 (SoC) | RX 580 (eGPU) |
|---|---|---|
| glmark2 (windowed 800x600) | 2738 | 1394 * |
| vkmark | 4076 | — |

\* The Mali number is *not* the card being slower. glmark2 at 800x600 is
CPU-bound here, and the eGPU path additionally copies each frame across
PCIe. See [docs/04-benchmarks.md](docs/04-benchmarks.md) for what these
numbers do and do not mean — the card's real figure is a different test.

### Games at 4K

x86 titles run through emulation on this ARM host, so these numbers are
as much a measure of the translation layer as of the GPU:

| Game | Settings | FPS |
|---|---|---|
| War Thunder | 4K, low | 50–60 |
| Counter-Strike: Source | 4K, high | ~60 |
| CS:GO | 4K, low | 20–40 (server dependent) |

**Native arm64 games skip emulation entirely** and are the honest test of
the card. See [docs/05-gaming.md](docs/05-gaming.md).

### Display

- 3840x2160 @ 60 Hz, HDR10, 10-bit, YCbCr 4:2:0 — working
- A second 4K display runs simultaneously off the SoC's own Mali/VOP2
- HDMI audio over the card works

**Bonus, same board, no card involved:** the Orange Pi 5 Plus also has a
DisplayPort controller wired to its USB-C port that mainline never enables.
A devicetree change turns it on and gives a *third* independent 4K display
straight from the SoC — see
[docs/06-usbc-displayport.md](docs/06-usbc-displayport.md).

## Quick start

Read [docs/01-hardware.md](docs/01-hardware.md) **before** connecting
anything. Two power supplies share one ground here; getting that wrong
destroys hardware, not just an evening.

```
docs/01-hardware.md      wiring, PSU, riser, what kills the board
docs/02-kernel.md        the patches, what each one fixes, how to build
docs/03-troubleshooting.md   symptom → cause → fix
docs/04-benchmarks.md    how these numbers were taken
docs/05-gaming.md        Steam, emulation, native arm64 titles
```

## Status and scope

This is a working setup, documented so someone else can reproduce it —
not a product. The kernel patches are carried locally; where a fix is
already upstream or in review, that is stated in
[docs/02-kernel.md](docs/02-kernel.md) with the commit or the list link,
so you can tell what you still need to apply and what your kernel may
already have.

Reports from other boards and other AMD cards are very welcome — open an
issue with your board, card, kernel version and `dmesg`.

## Credits

- **Mario Bălănică** — the arm64 PCIe/GPU patch series this builds on
- **Collabora** — the rockchip kernel tree
- The amdgpu, Mesa and rockchip upstream developers

## License

Kernel patches: GPL-2.0, as the kernel. Documentation: CC BY 4.0.
