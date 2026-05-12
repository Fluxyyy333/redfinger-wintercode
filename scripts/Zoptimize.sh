#!/data/data/com.termux/files/usr/bin/bash
# Zoptimize.sh — Minimal Low-Risk Optimization for Headless Roblox Farming
# Redfinger Android 10 ARM64 | Run once at boot via Zboot.sh
# Safe to re-run (idempotent, no pm disable, no force-stop lists)

LOG="${LOG:-$HOME/Zoptimize.log}"
echo "" >> "$LOG"
echo "── ZOPTIMIZE $(date) ──" >> "$LOG"

su -c "id" > /dev/null 2>&1 || { echo "[!] ROOT GAGAL" >> "$LOG"; exit 1; }

SKIP_DPI=0
grep -q '^SKIP_DPI=1' "$HOME/.rf_config" 2>/dev/null && SKIP_DPI=1

M_BEFORE=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))

# ── [1/2] Resolution & Display ───────────────────────────────
if [ "$SKIP_DPI" = "1" ]; then
    su -c "settings put global window_animation_scale 0.0"
    su -c "settings put global transition_animation_scale 0.0"
    su -c "settings put global animator_duration_scale 0.0"
    echo "[+] 1/2 DPI skip (--no-dpi), animasi OFF only" >> "$LOG"
else
    if ! grep -q "ORIG_SIZE" "$HOME/.rf_config" 2>/dev/null; then
        echo "ORIG_SIZE=$(su -c 'wm size' | awk '{print $3}')"   >> "$HOME/.rf_config"
        echo "ORIG_DPI=$(su -c 'wm density' | awk '{print $3}')" >> "$HOME/.rf_config"
    fi
    su -c "wm size 640x360"
    su -c "wm density 120"
    su -c "settings put global window_animation_scale 0.0"
    su -c "settings put global transition_animation_scale 0.0"
    su -c "settings put global animator_duration_scale 0.0"
    echo "[+] 1/2 Resolusi 640x360 @120dpi, animasi OFF" >> "$LOG"
fi

# ── [2/2] Overlay Policy (KRITIS untuk Delta) ────────────────
su -c "settings put global disable_overlays 0"
CLONE_PKGS=$(su -c "pm list packages 2>/dev/null" | grep -oE 'com\.delt[a-z]+')
CLONE_COUNT=0
for pkg in $CLONE_PKGS; do
    su -c "appops set $pkg SYSTEM_ALERT_WINDOW allow" 2>/dev/null
    CLONE_COUNT=$((CLONE_COUNT + 1))
done
echo "[+] 2/2 Overlay enabled, $CLONE_COUNT Delta clones permitted" >> "$LOG"

# ── Result ────────────────────────────────────────────────────
M_AFTER=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
echo "[+] ZOPTIMIZE DONE: ${M_BEFORE}MB -> ${M_AFTER}MB (+$((M_AFTER - M_BEFORE))MB freed) / ${TOTAL_MB}MB total — $(date)" >> "$LOG"
