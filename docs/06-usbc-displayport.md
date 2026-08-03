# 6. DisplayPort over USB-C — enabling a third display

The Orange Pi 5 Plus has a DisplayPort controller wired to its data USB-C
port. Mainline never enables it, so the port does USB only. This is the
devicetree change that turns it on, and the evidence that the hardware is
really there.

Result on this board: a third independent 4K display, driven by the SoC,
alongside the two HDMI outputs — no kernel rebuild, only a devicetree.

## Is the hardware actually wired?

Worth checking before touching anything, because SoC support does not mean
board support.

**Three independent confirmations on the 5 Plus:**

1. The Xunlong schematic (OPI5_PLUS_V11_20230519, sheet 26) shows the RK3588
   balls named `TYPEC0_SBU1/DP0_AUXP` and `TYPEC0_SBU2/DP0_AUXN` carrying live
   nets to the receptacle's SBU1/SBU2 pins — while the board's **second**
   Type-C has SuperSpeed lanes but **no SBU nets at all**. Deliberate, not
   boilerplate.
2. The stock DTS already carries `sbu1-dc-gpios` / `sbu2-dc-gpios` on the phy.
   Those GPIOs exist only to bias the SBU lines for DP AUX; the driver drives
   them in lockstep with the DP AUX polarity selection.
3. Orange Pi's own spec: *"1x Type-C with DP TX 1.4A"*.

**Test it on your board in 30 seconds, no changes required.** Plug a USB-C
DP adapter or cable into the data Type-C port, then:

```
for d in /sys/class/typec/port0-partner/port0-partner.*; do
    echo "svid=$(cat $d/svid) active=$(cat $d/active)"
done
```

`svid=ff01` is DisplayPort Alt Mode. If it appears, the connector, the PD
chain and the cable are all good and only the devicetree is missing.
`active=no` at this stage is expected. If nothing appears at all, stop —
no devicetree change will help until PD works.

## Why it does not work out of the box

Two independent blockers, both in the devicetree:

1. **`phy-rockchip-usbdp` registers its DRM aux bridge only if graph port 3
   exists.** The stock board DTS gives the phy a single bare `port`, which is
   graph port 0, so no bridge is ever created, `dw-dp` finds nothing to attach
   to, and `dp0` never binds.
2. **The connector has no `altmodes` node**, so the Type-C class registers no
   DisplayPort alt mode and TCPM could never enter one even with a perfect
   graph.

## The change

See [`../patches/`](../patches/) — enable `dp0`, route it from **VP2**,
convert the phy graph to the four-port shape and the xhci graph to the
two-port shape, and declare the alt mode on the connector.

**Why VP2:** VOP2 has four video ports, but `rk3588_vop_video_ports[]` gives
VP0/VP1/VP2 a 4096x2304 limit with 10-bit output while **VP3 is capped at
2048x1536 with no 10-bit path**. VP0 and VP1 drive the two HDMI outputs here,
so VP2 is both the free one and the right one. The vendor BSP and the Rock 5B
mainline DTS pick VP2 as well.

Deploying is whatever your board uses for devicetree. On this one the DTB
comes from the UEFI firmware's override directory on the ESP, so it is a file
copy and a reboot, and the rollback is copying the old file back.

## ⚠️ Two things to know before you try it

**Do not hot-plug the USB-C cable.** This kernel does not carry the later
usbdp patches (notifying dwc3 of a phy reset, re-initialising on an
orientation change). Plug the cable and power the display **before** boot, and
leave it alone while the system runs.

**If DP does not come up, flip the connector 180°.** On this board only one
orientation works. Everything on the Type-C side can look perfect —
`active=yes`, `hpd=1`, pin assignment C, four lanes — and the DRM connector
still reports `disconnected`. Rotating the plug fixed it here, and
`/sys/class/typec/port0/orientation` then reads `reverse`. This is the
missing orientation re-init showing itself; it costs nothing to try and it is
the first thing to try.

## Verifying

```
ls /sys/class/drm/ | grep -i DP          # expect a new DP connector
cat /sys/class/drm/card0-DP-1/status     # connected
cat /sys/class/drm/card0-DP-1/edid | wc -c   # non-zero
cat /sys/class/typec/port0-partner/port0-partner.0/displayport/hpd   # 1
cat /sys/class/typec/port0/orientation
dmesg | grep -i 'bound.*dp'              # bound fde50000.dp
```

## What you get, honestly

Measured here with an active USB-C→HDMI adapter (48 Gbps class) into a
Samsung Odyssey G70B:

| | |
|---|---|
| Resolution | 3840x2160 @ 60 Hz |
| Alt mode | pin assignment C — four DP lanes |
| HDR | reported **incapable** by the compositor |

The EDID that reaches the host through the adapter *does* carry an HDR static
metadata block and BT.2020 colorimetry, yet the compositor still reports the
output as HDR-incapable, and the mode list tops out at 60 Hz rather than 120.
Whether that is the adapter, the link configuration or something else has not
been investigated. A native USB-C→DP cable into a DP monitor would be the
obvious next test.

## A note on colour, since it surprises people

An output with HDR **off** often looks *better* than the same panel with HDR
**on**, when what you are looking at is ordinary SDR content. With HDR on, the
compositor faithfully renders SDR at a fixed brightness (200 nits by default
in KWin); with HDR off, the display applies its own contrast and saturation
processing, which reads as punchier.

Two identical monitors side by side on this machine — one on HDMI with HDR
enabled, one on this DP output without — make the difference obvious. Neither
is broken. Turn HDR on for HDR content, off for the desktop:

```
kscreen-doctor output.<NAME>.hdr.disable
kscreen-doctor output.<NAME>.sdr-brightness.350   # if you keep HDR on
```
