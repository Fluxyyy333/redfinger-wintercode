#!/data/data/com.termux/files/usr/bin/bash
# OPTIMIZE_RF.sh — Redfinger Cloud Phone (Verified Tweaks Only)
# Redfinger Android 10 ARM64 | Roblox Farming | 6-8 Instances
#
# NOTE: /proc/sys/ READ-ONLY (hypervisor block) — tidak ada kernel writes
# CPU sudah di-force 'performance' oleh hypervisor — tidak perlu di-set
# Placebo tweaks (brightness, low_power, captive_portal) sudah dihapus

LOG="${LOG:-$HOME/optimize.log}"
TOTAL_STEPS=5
CURRENT_STEP=0
STEP_NAME=""
LOG_LINES=()
UI_DRAWN=0

echo "" >> "$LOG"
echo "── OPTIMASI $(date) ──" >> "$LOG"

# ── UI engine ─────────────────────────────────────────────────
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

task() { local icon="$1" msg="$2"; LOG_LINES+=("$icon $msg"); echo "  $icon $msg" >> "$LOG"; _draw; }
ok()     { task "\033[0;32m✓\033[0m" "$1"; }
err()    { task "\033[0;31m✗\033[0m" "$1"; }
running(){ task "\033[0;33m↳\033[0m" "$1"; }

# ── Header ─────────────────────────────────────────────────────
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

# ── [1/5] Resolusi ─────────────────────────────────────────────
step "Resolusi Display"
if ! grep -q "ORIG_SIZE" "$HOME/.rf_config" 2>/dev/null; then
  running "Backup resolusi asli..."
  echo "ORIG_SIZE=$(su -c 'wm size' | awk '{print $3}')"   >> "$HOME/.rf_config"
  echo "ORIG_DPI=$(su -c 'wm density' | awk '{print $3}')" >> "$HOME/.rf_config"
fi
running "wm size 800x480..."
su -c "wm size 800x480"
running "wm density 160..."
su -c "wm density 160"
ACTUAL_SIZE=$(su -c "wm size"    | awk '{print $3}')
ACTUAL_DPI=$( su -c "wm density" | awk '{print $3}')
ok "Resolusi → $ACTUAL_SIZE @ ${ACTUAL_DPI}dpi"

# ── [2/5] Animasi ──────────────────────────────────────────────
step "Animasi"
running "Matikan semua animasi..."
su -c "settings put global window_animation_scale 0.0"
su -c "settings put global transition_animation_scale 0.0"
su -c "settings put global animator_duration_scale 0.0"
running "Heads-up & bubbles OFF..."
su -c "settings put global heads_up_notifications_enabled 0"
su -c "settings put global notification_bubbles 0"
ok "Animasi OFF, notifikasi popup OFF"

# ── [3/5] Doze Mode ────────────────────────────────────────────
step "Doze Mode"
running "dumpsys deviceidle disable..."
su -c "dumpsys deviceidle disable" >> "$LOG" 2>&1
running "Scan & whitelist com.fluxy* + Termux..."
FLUXY_PKGS=$(su -c "pm list packages 2>/dev/null | grep 'com\.fluxy' | sed 's/package://'")
COUNT=0
for pkg in $FLUXY_PKGS; do
  su -c "dumpsys deviceidle whitelist +$pkg 2>/dev/null"
  su -c "am set-standby-bucket $pkg active 2>/dev/null"
  COUNT=$((COUNT + 1))
done
su -c "dumpsys deviceidle whitelist +com.termux 2>/dev/null"
su -c "am set-standby-bucket com.termux active 2>/dev/null"
su -c "am set-standby-bucket com.termux.boot active 2>/dev/null"
running "device_idle_constants → timeout 24 jam..."
su -c "settings put global device_idle_constants idle_after_inactive_timeout=86400000,sensing_timeout=86400000,locating_timeout=86400000,motion_inactive_timeout=86400000,idle_pending_timeout=86400000,idle_timeout=86400000"
ok "Doze OFF  |  $COUNT com.fluxy* + Termux whitelisted & ACTIVE bucket"

# ── [4/5] WiFi & Network ───────────────────────────────────────
step "WiFi & Network"
running "wifi_sleep_policy → never sleep..."
su -c "settings put global wifi_sleep_policy 2"
ok "WiFi: never sleep"

# ── [5/5] OOM Protection + Force-Stop Bloat ───────────────────
step "OOM Protection + Cleanup"

# Protect Termux
running "OOM protect Termux..."
TERMUX_PIDS=$(su -c "ps -A 2>/dev/null | grep 'com\.termux' | awk '{print \$2}'")
TMUX_COUNT=0
for pid in $TERMUX_PIDS; do
  [ -z "$pid" ] && continue
  su -c "echo -400 > /proc/$pid/oom_score_adj" 2>/dev/null && TMUX_COUNT=$((TMUX_COUNT + 1))
done
ok "Termux protected ($TMUX_COUNT proses, score -400)"

# Protect Lua agent
LUA_PID=$(pgrep -n lua 2>/dev/null)
if [ -n "$LUA_PID" ]; then
  su -c "echo -300 > /proc/$LUA_PID/oom_score_adj" 2>/dev/null
  ok "Lua agent protected (PID $LUA_PID, score -300)"
fi

# Protect com.fluxy*
FLUXY_PIDS=$(su -c "ps -A 2>/dev/null | grep 'com\.fluxy' | awk '{print \$2}'")
FLUXY_COUNT=0
for pid in $FLUXY_PIDS; do
  [ -z "$pid" ] && continue
  su -c "echo -200 > /proc/$pid/oom_score_adj" 2>/dev/null && FLUXY_COUNT=$((FLUXY_COUNT + 1))
done
[ $FLUXY_COUNT -gt 0 ] && ok "$FLUXY_COUNT com.fluxy* protected (score -200)" \
  || ok "com.fluxy* belum berjalan — oom_watcher protect saat launch"

# Force-stop bloatware
running "Force-stop bloatware..."
for pkg in \
  "com.android.vending" "com.google.android.apps.nbu.files" \
  "com.google.android.inputmethod.latin" "com.google.android.play.games" \
  "com.android.inputmethod.latin" "com.android.phone" \
  "com.wsh.appstore" "com.android.email" \
  "com.android.messaging" "com.android.calendar"; do
  su -c "am force-stop $pkg 2>/dev/null"
done
ok "Force-stop bloatware selesai"

# ── Summary ────────────────────────────────────────────────────
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
