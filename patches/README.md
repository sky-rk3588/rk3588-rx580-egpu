# Patches — who wrote what

Applied on a Collabora `rockchip-v7.0` tree. Authorship matters more than
convenience here, so it is spelled out per patch.

| Patch | Author | Origin |
|---|---|---|
| `arm64-mm-Handle-alignment-faults-*` | **Mario Bălănică** | `arm-pcie-gpu-patches` 0001 |
| `arm64-mm-Force-Device-mappings-for-PCIe-MMIO` | **Mario Bălănică** | `arm-pcie-gpu-patches` 0002 |
| `drm-Force-writecombined-mappings-for-DMA` | **Mario Bălănică** | `arm-pcie-gpu-patches` 0003 |
| `fixup-alignment-c-adapt-to-v7-0-*` | Igor Paunović | build fixup for the above on this tree |
| `drm-ttm-arm64-use-pgprot-dmacoherent-*` | Igor Paunović | based on yanghaku's fix, validated on RPi5/RK3588 |
| `phy-rockchip-snps-pcie3-rk3588-relax-SRAM-init-*` | Igor Paunović | this project |
| `drm-amd-display-extend-420-pixel-phase-lock-wait-*` | Igor Paunović | this project (cosmetic, see note) |
| `arm64-dts-rockchip-opi5plus-enable-DisplayPort-over-USB-C` | Igor Paunović | this project — see [docs/06](../docs/06-usbc-displayport.md) |

**The three arm64 PCIe/GPU patches are Mario Bălănică's work.** They were
carried into this tree and tested here; nothing about them was invented
by this project. If you are building on them, go to his series rather
than to these copies — they may be newer there.

The `fixup-alignment-c` patch only adapts Mario's 0001 to this kernel:
`kernel_neon_begin()/end()` gained a state argument in v7.0.

The `drm-amd-display-extend-420-pixel-phase-lock-wait` patch widens a
register poll whose bit never asserts on this hardware. It removes log
spam; it is **not** the fix for the green HDR picture — that one is
upstream, see [../docs/02-kernel.md](../docs/02-kernel.md#4-hdr-output-is-green).

## Applying

```
git am *.patch
```

Order does not matter between the independent ones, but
`fixup-alignment-c-*` must come after `arm64-mm-Handle-alignment-faults-*`.
