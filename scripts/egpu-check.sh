#!/usr/bin/env bash
# egpu-check.sh — quick health check for an AMD eGPU on RK3588
# No sudo needed except where noted. Prints PASS/FAIL per item.

ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; }
info() { printf '  ....  %s\n' "$1"; }

echo "== PCIe =="
if lspci 2>/dev/null | grep -qiE 'vga|display.*(amd|ati)'; then
    ok "card enumerated: $(lspci | grep -iE 'vga|display' | head -1 | cut -c1-70)"
else
    bad "no VGA/display device in lspci"
    dmesg 2>/dev/null | grep -iE 'phy lock failed|pcie.*-110' | tail -2 | sed 's/^/        /'
    echo "        -> see docs/03-troubleshooting.md"
fi

echo "== amdgpu =="
if [ -e /sys/module/amdgpu ]; then
    ok "amdgpu loaded"
    for p in rebar runpm; do
        v=$(cat /sys/module/amdgpu/parameters/$p 2>/dev/null)
        info "amdgpu.$p = ${v:-?}"
    done
else
    bad "amdgpu not loaded"
fi
if dmesg 2>/dev/null | grep -q 'ring test .* failed'; then
    bad "ring test failure in dmesg (coherency patch missing?)"
fi

echo "== DRM devices =="
for c in /sys/class/drm/card[0-9]; do
    [ -e "$c/device/driver" ] || continue
    printf '  ....  %s -> %s\n' "$(basename "$c")" \
        "$(basename "$(readlink -f "$c/device/driver")")"
done
for r in /sys/class/drm/renderD*; do
    [ -e "$r/device/driver" ] || continue
    printf '  ....  %s -> %s\n' "$(basename "$r")" \
        "$(basename "$(readlink -f "$r/device/driver")")"
done

echo "== Vulkan =="
if command -v vulkaninfo >/dev/null; then
    vulkaninfo --summary 2>/dev/null | grep -E 'deviceName' | sed 's/^/  ....  /'
else
    info "vulkaninfo not installed (apt install vulkan-tools)"
fi

echo "== Connected outputs =="
for c in /sys/class/drm/card*-*; do
    s=$(cat "$c/status" 2>/dev/null)
    [ "$s" = connected ] && printf '  ....  %s\n' "$(basename "$c")"
done

echo "== Errors this boot =="
n=$(dmesg 2>/dev/null | grep -c 'amdgpu.*\*ERROR\*')
[ "$n" = 0 ] && ok "no amdgpu errors" || bad "$n amdgpu error lines (dmesg | grep amdgpu)"

echo
echo "Note: glxinfo is NOT a test for the eGPU - it reports the default"
echo "GPU. Use lspci and vulkaninfo, or DRI_PRIME=1 glxinfo -B."
