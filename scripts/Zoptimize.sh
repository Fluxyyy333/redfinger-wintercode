#!/data/data/com.termux/files/usr/bin/bash
# Zoptimize.sh — Display/GPU/Service Optimization for Headless Roblox
# Redfinger Android 10 ARM64 | Target: 8 instances on 4GB RAM
# /proc/sys/ READ-ONLY (hypervisor) — no kernel writes
# CPU forced 'performance' by hypervisor — no governor changes

LOG="${LOG:-$HOME/Zoptimize.log}"
echo "" >> "$LOG"
echo "── ZOPTIMIZE $(date) ──" >> "$LOG"

su -c "id" > /dev/null 2>&1 || { echo "[!] ROOT GAGAL" >> "$LOG"; exit 1; }

# ── [1/7] Resolusi ─────────────────────────────────────────────
if ! grep -q "ORIG_SIZE" "$HOME/.rf_config" 2>/dev/null; then
    echo "ORIG_SIZE=$(su -c 'wm size' | awk '{print $3}')"   >> "$HOME/.rf_config"
    echo "ORIG_DPI=$(su -c 'wm density' | awk '{print $3}')" >> "$HOME/.rf_config"
fi
su -c "wm size 640x360"
su -c "wm density 120"
echo "[+] 1/7 Resolusi → 640x360 @120dpi" >> "$LOG"

# ── [2/7] Animasi ──────────────────────────────────────────────
su -c "settings put global window_animation_scale 0.0"
su -c "settings put global transition_animation_scale 0.0"
su -c "settings put global animator_duration_scale 0.0"
su -c "settings put global heads_up_notifications_enabled 0"
su -c "settings put global notification_bubbles 0"
echo "[+] 2/7 Animasi OFF" >> "$LOG"

# ── [3/7] GPU Memory Tuning ────────────────────────────────────
su -c "setprop ro.hwui.texture_cache_size 16" 2>/dev/null
su -c "setprop ro.hwui.layer_cache_size 8" 2>/dev/null
su -c "setprop ro.hwui.path_cache_size 4" 2>/dev/null
su -c "setprop ro.hwui.r_buffer_cache_size 2" 2>/dev/null
su -c "setprop ro.hwui.gradient_cache_size 0.5" 2>/dev/null
su -c "setprop debug.hwui.render_dirty_regions false" 2>/dev/null
su -c "setprop debug.hwui.overdraw false" 2>/dev/null
su -c "settings put global force_4x_msaa 0" 2>/dev/null
su -c "settings put global enable_gpu_debug_layers 0" 2>/dev/null
su -c "settings put global disable_overlays 0" 2>/dev/null
su -c "appops set com.deltb SYSTEM_ALERT_WINDOW allow" 2>/dev/null
su -c "appops set com.deltc SYSTEM_ALERT_WINDOW allow" 2>/dev/null
su -c "appops set com.deltd SYSTEM_ALERT_WINDOW allow" 2>/dev/null
echo "[+] 3/7 GPU tuning (overlays kept for Delta)" >> "$LOG"

# ── [4/7] Doze Mode ────────────────────────────────────────────
su -c "dumpsys deviceidle disable" >> "$LOG" 2>&1
FLUXY_PKGS=$(su -c "pm list packages 2>/dev/null | grep 'com\.fluxy\|com\.delt' | sed 's/package://'")
COUNT=0
for pkg in $FLUXY_PKGS; do
    su -c "dumpsys deviceidle whitelist +$pkg 2>/dev/null"
    su -c "am set-standby-bucket $pkg active 2>/dev/null"
    COUNT=$((COUNT + 1))
done
su -c "dumpsys deviceidle whitelist +com.termux 2>/dev/null"
su -c "dumpsys deviceidle whitelist +com.termux.boot 2>/dev/null"
su -c "am set-standby-bucket com.termux active 2>/dev/null"
su -c "am set-standby-bucket com.termux.boot active 2>/dev/null"
su -c "settings put global device_idle_constants idle_after_inactive_timeout=86400000,sensing_timeout=86400000,locating_timeout=86400000,motion_inactive_timeout=86400000,idle_pending_timeout=86400000,idle_timeout=86400000"
echo "[+] 4/7 Doze OFF | $COUNT game pkgs whitelisted" >> "$LOG"

# ── [5/7] WiFi & Network ───────────────────────────────────────
su -c "settings put global wifi_sleep_policy 2"
echo "[+] 5/7 WiFi never sleep" >> "$LOG"

# ── [6/7] OOM Protection ───────────────────────────────────────
TERMUX_PIDS=$(su -c "ps -A 2>/dev/null | grep 'com\.termux' | awk '{print \$2}'")
TMUX_COUNT=0
for pid in $TERMUX_PIDS; do
    [ -z "$pid" ] && continue
    su -c "echo -400 > /proc/$pid/oom_score_adj" 2>/dev/null && TMUX_COUNT=$((TMUX_COUNT + 1))
done
LUA_PID=$(pgrep -n lua 2>/dev/null)
[ -n "$LUA_PID" ] && su -c "echo -300 > /proc/$LUA_PID/oom_score_adj" 2>/dev/null
GAME_PIDS=$(su -c "ps -A 2>/dev/null | grep -E 'com\.fluxy|com\.delt|com\.roblox' | awk '{print \$2}'")
GAME_COUNT=0
for pid in $GAME_PIDS; do
    [ -z "$pid" ] && continue
    su -c "echo -200 > /proc/$pid/oom_score_adj" 2>/dev/null && GAME_COUNT=$((GAME_COUNT + 1))
done
echo "[+] 6/7 OOM protect: Termux=$TMUX_COUNT Lua=1 Game=$GAME_COUNT" >> "$LOG"

# ── [7/7] Force-Stop Bloat + JobScheduler ──────────────────────
for pkg in \
  "com.android.vending" "com.google.android.apps.nbu.files" \
  "com.google.android.inputmethod.latin" "com.google.android.play.games" \
  "com.android.inputmethod.latin" "com.android.phone" \
  "com.wsh.appstore" "com.android.email" \
  "com.android.messaging" "com.android.calendar" \
  "com.android.chrome" "com.baidu.cloud.service" \
  "com.wshl.file.observerservice" "com.android.systemui" \
  "com.android.launcher3" "com.wsh.launcher"; do
  su -c "am force-stop $pkg 2>/dev/null"
done
su -c "cmd jobscheduler cancel-all" 2>/dev/null
echo "[+] 7/7 Force-stop bloat + JobScheduler cleared" >> "$LOG"

FREE_MB=$((  $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal     /proc/meminfo | awk '{print $2}') / 1024 ))
echo "[+] ZOPTIMIZE DONE — RAM: ${FREE_MB}MB / ${TOTAL_MB}MB — $(date)" >> "$LOG"
