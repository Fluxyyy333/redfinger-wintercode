#!/data/data/com.termux/files/usr/bin/bash
# OPTIMIZE_RF.sh — Redfinger Cloud Phone (Confirmed Working Tweaks Only)
# Redfinger Android 10 ARM64 | Roblox Farming | 6-8 Instances
#
# NOTE: /proc/sys/ is READ-ONLY on this device (hypervisor blocks all kernel writes)
# CPU is already forced to 'performance' by hypervisor — no need to set
# This script only applies tweaks confirmed to actually work via ADB debug

LOG="${LOG:-$HOME/optimize.log}"
TOTAL_STEPS=7
CURRENT_STEP=0
STEP_NAME=""
LOG_LINES=()
UI_DRAWN=0

echo "" >> "$LOG"
echo "── OPTIMASI $(date) ──" >> "$LOG"

# ── UI engine ─────────────────────────────────────────────
_draw() {
  [ $UI_DRAWN -eq 1 ] && printf "\033[5A"

  local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
  local filled=$(( CURRENT_STEP * 24 / TOTAL_STEPS ))
  local empty=$(( 24 - filled ))
  local bar=""
  [ $filled -gt 0 ] && bar=$(printf '\033[0;32m%.0s█\033[0m' $(seq 1 $filled))
  [ $empty  -gt 0 ] && bar="${bar}$(printf '\033[0;90m%.0s░\033[0m' $(seq 1 $empty))"

  printf "  [%b] %3d%%  \033[1;37m%s\033[0m\033[K\n" "$bar" "$pct" "$STEP_NAME"
  printf "\033[K\n"

  local total=${#LOG_LINES[@]}
  for i in 0 1 2; do
    local idx=$(( total - 3 + i ))
    if [ $idx -ge 0 ] && [ $idx -lt $total ]; then
      printf "  %b\033[K\n" "${LOG_LINES[$idx]}"
    else
      printf "\033[K\n"
    fi
  done
  UI_DRAWN=1
}

step() {
  CURRENT_STEP=$(( CURRENT_STEP + 1 ))
  STEP_NAME="[$CURRENT_STEP/$TOTAL_STEPS] $1"
  echo "" >> "$LOG"
  echo "=== $STEP_NAME ===" >> "$LOG"
  _draw
}

task() {
  local icon="$1" msg="$2"
  LOG_LINES+=("$icon $msg")
  echo "  $icon $msg" >> "$LOG"
  _draw
}

ok()     { task "\033[0;32m✓\033[0m" "$1"; }
err()    { task "\033[0;31m✗\033[0m" "$1"; }
running(){ task "\033[0;33m↳\033[0m" "$1"; }

# ── Header ────────────────────────────────────────────────
echo -e "\033[1;36m"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║       REDFINGER OPTIMIZER                ║"
echo "  ║       Roblox Multi-Instance | ARM64      ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "\033[0m"
printf "\n\n\n\n\n"
UI_DRAWN=0

running "Cek akses root..."
su -c "id" > /dev/null 2>&1 || { err "ROOT GAGAL"; exit 1; }
ok "Root aktif."

# ── [1/7] Resolusi ───────────────────────────────────────
step "Resolusi Display"
if ! grep -q "ORIG_SIZE" "$HOME/.rf_config" 2>/dev/null; then
  running "Backup resolusi asli..."
  echo "ORIG_SIZE=$(su -c 'wm size' | awk '{print $3}')"   >> "$HOME/.rf_config"
  echo "ORIG_DPI=$(su -c 'wm density' | awk '{print $3}')" >> "$HOME/.rf_config"
fi
running "wm size 800x480..."
su -c "wm size 800x480"   >> "$LOG" 2>&1
running "wm density 160..."
su -c "wm density 160"    >> "$LOG" 2>&1
# Verify
ACTUAL_SIZE=$(su -c "wm size"    | awk '{print $3}')
ACTUAL_DPI=$( su -c "wm density" | awk '{print $3}')
ok "Resolusi → $ACTUAL_SIZE @ ${ACTUAL_DPI}dpi  (~58% hemat framebuffer RAM)"

# ── [2/7] Animasi & Display ──────────────────────────────
step "Animasi & Display"
running "Matikan semua animasi (window/transition/animator → 0)..."
su -c "settings put global window_animation_scale 0.0"
su -c "settings put global transition_animation_scale 0.0"
su -c "settings put global animator_duration_scale 0.0"
running "Brightness → 0, heads_up & bubbles → OFF..."
su -c "settings put system screen_brightness_mode 0"
su -c "settings put system screen_brightness 0"
su -c "settings put global heads_up_notifications_enabled 0"
su -c "settings put global notification_bubbles 0"
su -c "settings put global low_power 0"
ok "Animasi dimatikan, brightness → 0"

# ── [3/7] Doze Mode ──────────────────────────────────────
step "Doze Mode"
running "dumpsys deviceidle disable..."
su -c "dumpsys deviceidle disable" >> "$LOG" 2>&1
running "Scan & whitelist com.fluxy*..."
FLUXY_PKGS=$(su -c "pm list packages 2>/dev/null | grep 'com\.fluxy' | sed 's/package://'")
COUNT=0
for pkg in $FLUXY_PKGS; do
  su -c "dumpsys deviceidle whitelist +$pkg 2>/dev/null"
  COUNT=$((COUNT + 1))
done
su -c "dumpsys deviceidle whitelist +com.termux 2>/dev/null"
running "device_idle_constants → semua timeout 24 jam..."
su -c "settings put global device_idle_constants idle_after_inactive_timeout=86400000,sensing_timeout=86400000,locating_timeout=86400000,motion_inactive_timeout=86400000,idle_pending_timeout=86400000,idle_timeout=86400000"
ok "Doze OFF  |  $COUNT com.fluxy* + Termux di-whitelist"

# ── [4/7] Background Process ─────────────────────────────
step "Background Process Limit"
running "background_process_limit → 32..."
su -c "settings put global background_process_limit 32"
running "always_finish_activities → 0..."
su -c "settings put global always_finish_activities 0"
ok "Limit → 32  |  Activity destroy → OFF"

# ── [5/7] WiFi & Network ─────────────────────────────────
step "WiFi & Network"
running "wifi_sleep_policy → 2 (never sleep)..."
su -c "settings put global wifi_sleep_policy 2"
running "network_avoid_bad_wifi → 0, captive_portal → OFF..."
su -c "settings put global network_avoid_bad_wifi 0"
su -c "settings put global captive_portal_detection_enabled 0"
running "wlan0 txqueuelen → 5000..."
ip link set wlan0 txqueuelen 5000 >> "$LOG" 2>&1
ok "WiFi: never sleep  |  txqueuelen → 5000"

# ── [6/7] OOM Protection ─────────────────────────────────
step "OOM Protection"
running "Scan PID com.fluxy* yang berjalan..."
FLUXY_PIDS=$(su -c "ps -A 2>/dev/null | grep 'com\.fluxy' | awk '{print \$2}'")
if [ -n "$FLUXY_PIDS" ]; then
  COUNT=0
  for pid in $FLUXY_PIDS; do
    running "oom_score_adj → -300 (PID $pid)..."
    su -c "echo -300 > /proc/$pid/oom_score_adj" 2>/dev/null
    COUNT=$((COUNT + 1))
  done
  ok "OOM protect → $COUNT instance(s) com.fluxy* (score -300)"
else
  ok "com.fluxy* belum berjalan — oom_watcher protect saat launch"
fi
LUA_PID=$(pgrep -n lua 2>/dev/null)
if [ -n "$LUA_PID" ]; then
  running "oom_score_adj → -400 (lua PID $LUA_PID)..."
  su -c "echo -400 > /proc/$LUA_PID/oom_score_adj"
  ok "Lua agent OOM protected."
fi

# ── [7/7] Standby, AOT, Force-Stop ───────────────────────
step "Standby Bucket + AOT + Force-Stop Bloat"
running "Scan com.fluxy* untuk standby + AOT..."
FLUXY_PKGS=$(su -c "pm list packages 2>/dev/null | grep 'com\.fluxy' | sed 's/package://'")
COUNT=0
for pkg in $FLUXY_PKGS; do
  su -c "am set-standby-bucket $pkg active 2>/dev/null"
  su -c "cmd package compile -m speed $pkg >> $LOG 2>&1"
  COUNT=$((COUNT + 1))
done
[ $COUNT -gt 0 ] && ok "$COUNT com.fluxy* → ACTIVE + AOT compiled" || ok "com.fluxy* belum install — skip"

running "Termux → ACTIVE standby bucket..."
su -c "am set-standby-bucket com.termux active 2>/dev/null"
su -c "am set-standby-bucket com.termux.boot active 2>/dev/null"

running "setprop persist.sys.ui.hw → true..."
setprop persist.sys.ui.hw true >> "$LOG" 2>&1

running "Force-stop 10 bloat apps (~450MB)..."
for pkg in \
  "com.android.vending" "com.google.android.apps.nbu.files" \
  "com.google.android.inputmethod.latin" "com.google.android.play.games" \
  "com.android.inputmethod.latin" "com.android.phone" \
  "com.wsh.appstore" "com.android.email" \
  "com.android.messaging" "com.android.calendar"; do
  su -c "am force-stop $pkg 2>/dev/null"
done
ok "Force-stop selesai (~450MB freed)"

# ── Summary ───────────────────────────────────────────────
FREE_MB=$((  $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal     /proc/meminfo | awk '{print $2}') / 1024 ))
SWAP_F_MB=$(($(grep SwapFree     /proc/meminfo | awk '{print $2}') / 1024 ))
SWAP_T_MB=$(($(grep SwapTotal    /proc/meminfo | awk '{print $2}') / 1024 ))

echo -e ""
echo -e "\033[1;32m  ╔══════════════════════════════════════════╗"
echo    "  ║         ✓  OPTIMASI SELESAI              ║"
echo -e "  ╠══════════════════════════════════════════╣"
printf  "  ║  RAM  : %4s MB tersedia / %4s MB total  ║\n" "$FREE_MB"   "$TOTAL_MB"
printf  "  ║  Swap : %4s MB tersedia / %4s MB total  ║\n" "$SWAP_F_MB" "$SWAP_T_MB"
echo -e "  ╚══════════════════════════════════════════╝\033[0m"
echo ""
