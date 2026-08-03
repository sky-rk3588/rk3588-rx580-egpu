# 1. Hardware

> Read this section fully before connecting anything. Two independent
> power supplies meet here. A ground mistake destroys the board and the
> card, not just an evening.

## The chain

```
Orange Pi 5 Plus (RK3588)
  └─ M.2 M-key 2280 slot  (pcie3x4 controller, Gen3 x4)
       └─ M.2 → PCIe x16 riser
            └─ XFX RX 580 8GB (Polaris10, DCE 11.2)
                 ├─ 12V + 5V slot power   ← ATX PSU (not the SBC!)
                 ├─ 8-pin PCIe power      ← ATX PSU, its own cable
                 └─ HDMI → 4K TV
```

The board's own supply drives the SBC only. The M.2 slot **does not
carry 12 V**, so the riser and the card are fed from a separate ATX
supply (here a Chieftec).

## Safety rules

These are not suggestions.

1. **Common ground first.** Before anything is powered, bond the ATX
   PSU ground to the SBC ground and **verify with a multimeter**:
   continuity below 1 Ω between the riser's ground and the board's
   ground. Two supplies at different potentials push their difference
   through the PCIe signal pins.
2. **Both supplies unplugged from the wall** while wiring.
3. **12 V and 5 V both connected** on the riser.
4. **The card's 8-pin comes straight from the PSU**, on its own cable —
   not daisy-chained.
5. **ATX PS_ON**: green wire, pin 16, jumpered to ground so the PSU runs
   without a motherboard.
6. **Never hot-plug.** Power order: ATX on (the card's fans twitch),
   *then* the SBC. Shutdown is the reverse: shut the SBC down first,
   then the ATX.
7. **Support the card mechanically.** A riser ribbon is not a bracket.
8. **ESD**: touch ground before handling; work on wood or an antistatic
   mat.

## What the slot gives you

| | |
|---|---|
| Slot | M.2 M-key 2280, `pcie3x4` controller (`pcie@fe150000`) |
| Link | PCIe Gen3 x4 |
| MEM64 prefetchable window | 1 GB at `0x9_0000_0000` |

That 1 GB window matters: an 8 GB card advertising Resizable BAR asks for
an 8 GB aperture, which does not fit. See
[03-troubleshooting.md](03-troubleshooting.md#resizable-bar).

## Firmware

This board boots EDK2 (UEFI) from SPI flash, then GRUB, then Linux. Two
things follow from that:

- The devicetree the kernel sees comes from **EDK2**, not from `/boot`.
  Custom DTBs go through EDK2's DTB override on the ESP, not through
  GRUB's `devicetree` command.
- EDK2 itself brings the PCIe PHY up successfully — which is the clue
  that cracked the `-110` failure. See
  [02-kernel.md](02-kernel.md#1-the-pcie-phy-never-locks).

## A note on the same slot for storage

On this board the M-key slot has shown instability under sustained Gen3
x4 load with an NVMe boot drive (system dies ~30 s into boot, with
nothing in the journal because the journal's disk is the one that
vanished). With the GPU it has been stable. If you have both, test them
separately before trusting either.
