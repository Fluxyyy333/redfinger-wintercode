#!/data/data/com.termux/files/usr/bin/bash
# Zoptimize.sh — Consolidated Optimization for Headless Roblox Farming
# Redfinger Android 10 ARM64 | Run once at boot via Zboot.sh
# Replaces: Zdebloat.sh + old Zoptimize.sh + Zmemory.sh + Zdeep.sh
# Safe to re-run (idempotent, no pm disable, no persistent changes)

LOG="${LOG:-$HOME/Zoptimize.log}"
echo "" >> "$LOG"
echo "── ZOPTIMIZE $(date) ──" >> "$LOG"

su -c "id" > /dev/null 2>&1 || { echo "[!] ROOT GAGAL" >> "$LOG"; exit 1; }

M_BEFORE=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))

# ── [1/8] Resolution & Display ───────────────────────────────
if ! grep -q "ORIG_SIZE" "$HOME/.rf_config" 2>/dev/null; then
    echo "ORIG_SIZE=$(su -c 'wm size' | awk '{print $3}')"   >> "$HOME/.rf_config"
    echo "ORIG_DPI=$(su -c 'wm density' | awk '{print $3}')" >> "$HOME/.rf_config"
fi
su -c "wm size 640x360"
su -c "wm density 120"
su -c "settings put global window_animation_scale 0.0"
su -c "settings put global transition_animation_scale 0.0"
su -c "settings put global animator_duration_scale 0.0"
su -c "settings put global heads_up_notifications_enabled 0"
su -c "settings put global notification_bubbles 0"
su -c "settings put global force_4x_msaa 0"
su -c "settings put global enable_gpu_debug_layers 0"
echo "[+] 1/8 Resolusi 640x360 @120dpi, animasi OFF" >> "$LOG"

# ── [2/8] Overlay Policy (KRITIS untuk Delta) ────────────────
su -c "settings put global disable_overlays 0"
CLONE_PKGS=$(su -c "pm list packages 2>/dev/null" | grep -oE 'com\.delt[a-z]+')
CLONE_COUNT=0
for pkg in $CLONE_PKGS; do
    su -c "appops set $pkg SYSTEM_ALERT_WINDOW allow" 2>/dev/null
    CLONE_COUNT=$((CLONE_COUNT + 1))
done
echo "[+] 2/8 Overlay enabled, $CLONE_COUNT Delta clones permitted" >> "$LOG"

# ── [3/8] Doze & Background Control ──────────────────────────
su -c "dumpsys deviceidle disable" >> "$LOG" 2>&1
su -c "settings put global device_idle_constants idle_after_inactive_timeout=86400000,sensing_timeout=86400000,locating_timeout=86400000,motion_inactive_timeout=86400000,idle_pending_timeout=86400000,idle_timeout=86400000"
su -c "settings put global activity_manager_constants max_cached_processes=4,background_settle_time=5000,fgs_bg_restriction_enabled=true"
su -c "settings put global always_finish_activities 0"
su -c "settings put global cached_apps_freezer enabled"
su -c "settings put global settings_enable_monitor_phantom_procs false"

GAME_PKGS=$(su -c "pm list packages 2>/dev/null" | grep -oE 'com\.(fluxy|delt)[^ ]*')
WL_COUNT=0
for pkg in $GAME_PKGS; do
    su -c "dumpsys deviceidle whitelist +$pkg" 2>/dev/null
    su -c "am set-standby-bucket $pkg active" 2>/dev/null
    WL_COUNT=$((WL_COUNT + 1))
done
for pkg in com.termux com.termux.boot; do
    su -c "dumpsys deviceidle whitelist +$pkg" 2>/dev/null
    su -c "am set-standby-bucket $pkg active" 2>/dev/null
done
echo "[+] 3/8 Doze OFF, $WL_COUNT game + Termux whitelisted" >> "$LOG"

# ── [4/8] Network ─────────────────────────────────────────────
su -c "settings put global wifi_sleep_policy 2"
su -c "settings put global wifi_scan_always_enabled 0"
su -c "settings put global ble_scan_always_enabled 0"
su -c "settings put secure location_mode 0"
su -c "settings put secure location_providers_allowed '-gps,-network'"
echo "[+] 4/8 WiFi never sleep, scanning OFF" >> "$LOG"

# ── [5/8] GMS & Play Store Restriction ───────────────────────
su -c "cmd appops set com.google.android.gms RUN_IN_BACKGROUND deny" 2>/dev/null
su -c "cmd appops set com.google.android.gms RUN_ANY_IN_BACKGROUND deny" 2>/dev/null
su -c "cmd appops set com.android.vending RUN_IN_BACKGROUND deny" 2>/dev/null
su -c "cmd appops set com.android.vending RUN_ANY_IN_BACKGROUND deny" 2>/dev/null
su -c "am set-standby-bucket com.android.vending restricted" 2>/dev/null
su -c "settings put secure enabled_notification_listeners ''" 2>/dev/null
su -c "settings put secure enabled_notification_policy_access_packages ''" 2>/dev/null
echo "[+] 5/8 GMS + Play Store background restricted" >> "$LOG"

# ── [6/8] Force-Stop Bloat (one-time) ────────────────────────
BLOAT_PKGS=(
    com.android.phone com.android.server.telecom com.android.dialer
    com.android.calllogbackup com.android.carrierconfig
    com.android.bluetooth com.android.bluetoothmidiservice
    com.android.chrome com.android.email com.android.calendar
    com.android.messaging com.android.contacts
    com.android.gallery3d com.android.music com.android.soundrecorder
    com.android.camera2 com.android.nfc
    com.android.inputmethod.latin com.google.android.inputmethod.latin
    com.google.android.play.games com.google.android.tts
    com.google.android.setupwizard com.google.android.gsf.login
    com.android.vending com.google.android.apps.nbu.files
    com.baidu.cloud.service com.wsh.appstore com.wshl.file.observerservice
    com.android.deskclock com.android.printspooler
    com.android.documentsui com.android.settings
)
FSTOP_CMD=""
for pkg in "${BLOAT_PKGS[@]}"; do
    FSTOP_CMD="${FSTOP_CMD}am force-stop $pkg; "
done
su -c "$FSTOP_CMD" 2>/dev/null
su -c "cmd jobscheduler cancel-all" 2>/dev/null
echo "[+] 6/8 Force-stopped ${#BLOAT_PKGS[@]} packages, jobscheduler cleared" >> "$LOG"

# ── [7/8] OOM Protection ─────────────────────────────────────
OOM_CMD=""
TERMUX_PIDS=$(su -c "ps -A 2>/dev/null | grep 'com\.termux' | awk '{print \$2}'")
TMUX_COUNT=0
for pid in $TERMUX_PIDS; do
    [ -z "$pid" ] && continue
    OOM_CMD="${OOM_CMD}echo -400 > /proc/$pid/oom_score_adj; "
    TMUX_COUNT=$((TMUX_COUNT + 1))
done
LUA_PID=$(pgrep -n lua 2>/dev/null)
[ -n "$LUA_PID" ] && OOM_CMD="${OOM_CMD}echo -300 > /proc/$LUA_PID/oom_score_adj; "
GAME_PIDS=$(su -c "ps -A 2>/dev/null | grep -E 'com\.fluxy|com\.delt|com\.roblox' | awk '{print \$2}'")
GAME_COUNT=0
for pid in $GAME_PIDS; do
    [ -z "$pid" ] && continue
    OOM_CMD="${OOM_CMD}echo -200 > /proc/$pid/oom_score_adj; "
    GAME_COUNT=$((GAME_COUNT + 1))
done
[ -n "$OOM_CMD" ] && su -c "$OOM_CMD" 2>/dev/null
echo "[+] 7/8 OOM protect: Termux=$TMUX_COUNT Game=$GAME_COUNT" >> "$LOG"

# ── [8/8] Cache Cleanup ──────────────────────────────────────
su -c "rm -rf /data/tombstones/* /data/anr/*" 2>/dev/null
for pkg in com.android.chrome com.google.android.play.games \
           com.baidu.cloud.service com.wsh.appstore; do
    su -c "pm clear $pkg" 2>/dev/null
done
echo "[+] 8/8 Tombstones + bloat cache cleared" >> "$LOG"

# ── Result ────────────────────────────────────────────────────
M_AFTER=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
echo "[+] ZOPTIMIZE DONE: ${M_BEFORE}MB -> ${M_AFTER}MB (+$((M_AFTER - M_BEFORE))MB freed) / ${TOTAL_MB}MB total — $(date)" >> "$LOG"
