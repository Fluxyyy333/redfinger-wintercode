#!/data/data/com.termux/files/usr/bin/bash
# AUTORUN.sh — Boot trigger for Redfinger Optimizer
# Runs via Termux:Boot on every device restart

LOG="$HOME/boot.log"
CONFIG="$HOME/.rf_config"

# ── CRITICAL: Survive broken pipes & signals ────────────────
trap '' PIPE        # Ignore SIGPIPE — prevents "Broken pipe" crash
set +e              # Don't exit on error in keep-alive loop

# ── Prevent double-run (Termux:Boot + .bashrc race) ─────────
LOCKFILE="$HOME/.autorun.pid"
if [ -f "$LOCKFILE" ]; then
  OLD_PID=$(cat "$LOCKFILE" 2>/dev/null)
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "$(date '+%H:%M:%S') [!] autorun sudah jalan (PID $OLD_PID), skip" >> "$LOG"
    exit 0
  fi
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT INT TERM

# ── Acquire wake lock PERTAMA ────────────────────────────────
termux-wake-lock

# ── Self-protect from OOM immediately ────────────────────────
su -c "echo -900 > /proc/$$/oom_score_adj" 2>/dev/null

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG" 2>/dev/null; }

{
echo ""
echo "══════════════════════════════"
echo "  AUTORUN — $(date)"
echo "══════════════════════════════"
} >> "$LOG"

# Load config
if [ -f "$CONFIG" ]; then
  source "$CONFIG"
else
  log "[!] Config tidak ditemukan — lanjut dengan default"
fi

# ── Wait for internet (max 90s) ──────────────────────────────
log "[*] Menunggu internet..."
CONNECTED=0
for i in $(seq 1 18); do
  if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
    log "[+] Internet OK (attempt $i)"
    CONNECTED=1
    break
  fi
  sleep 5
done
[ $CONNECTED -eq 0 ] && log "[!] Internet tidak tersedia — lanjut tanpa network"

# ── [1/2] Optimizer (one-time at boot) ──────────────────────
log "[*] [1/2] Optimizer..."
bash "$HOME/scripts/optimize_rf.sh" >> "$LOG" 2>&1
log "[+] Optimizer selesai."

# ── [2/2] OOM Watcher — independent daemon ──────────────────
log "[*] [2/2] OOM Watcher daemon..."
start_oom_watcher() {
  # nohup + setsid = survives parent death
  nohup setsid bash -c '
    while true; do
      bash "$HOME/scripts/oom_watcher.sh" >> "$HOME/oom_watcher.log" 2>&1
      sleep 5
    done
  ' > /dev/null 2>&1 &
  log "[+] OOM watcher daemon (PID: $!)"
}
start_oom_watcher
log "[+] Boot sequence selesai — semua daemon aktif."
echo "══════════════════════════════" >> "$LOG"

# ── Keep-alive loop (fault-tolerant) ─────────────────────────
# JANGAN dihapus. Tanpa ini Termux:Boot task langsung exit,
# wake lock lepas, dan semua daemon rentan OOM.
while true; do
  sleep 300 || true  # Don't crash if sleep is interrupted

  # Re-acquire wake lock (in case it was released)
  termux-wake-lock 2>/dev/null

  # Re-protect self from OOM
  su -c "echo -900 > /proc/$$/oom_score_adj" 2>/dev/null

  # ── Periodic bloatware kill ──
  # Beberapa service restart sendiri via broadcast receiver
  # Pada 4GB / 5 instance, setiap MB penting
  for pkg in \
    "com.android.vending" "com.google.android.apps.nbu.files" \
    "com.google.android.inputmethod.latin" "com.google.android.play.games" \
    "com.android.inputmethod.latin" "com.android.phone" \
    "com.wsh.appstore" "com.android.email" \
    "com.android.messaging" "com.android.calendar" \
    "com.baidu.cloud.service" "com.wshl.file.observerservice"; do
    su -c "am force-stop $pkg" 2>/dev/null
  done

  # Cek apakah oom_watcher masih berjalan
  if ! pgrep -f "oom_watcher.sh" > /dev/null 2>&1; then
    log "[!] OOM watcher tidak ditemukan — restart darurat"
    start_oom_watcher
  fi
  # Log heartbeat tiap jam (fault-tolerant)
  MINUTE=$(date +%M 2>/dev/null) || continue
  if [ "${MINUTE:-99}" -lt 5 ] 2>/dev/null; then
    FREE_MB=$(( $(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}') / 1024 )) 2>/dev/null || FREE_MB="?"
    log "[~] Heartbeat — RAM free: ${FREE_MB}MB"
  fi
done
