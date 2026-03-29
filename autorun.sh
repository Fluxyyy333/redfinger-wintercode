#!/data/data/com.termux/files/usr/bin/bash
# AUTORUN.sh — Boot trigger for Redfinger Optimizer + Wintercode Agent
# Runs via Termux:Boot on every device restart

LOG="$HOME/boot.log"
CONFIG="$HOME/.rf_config"
AGENT_URL="https://api.wintercode.dev/loader/agent-obfuscated.lua"
AGENT_PATH="/sdcard/Download/agent.lua"

# ── Acquire wake lock PERTAMA ────────────────────────────────
# Wajib dipanggil sebelum apapun agar ini berjalan sebagai proper task
# (muncul sebagai "0 session, 1 task" di notifikasi Termux, bukan "1 session, 0 task")
termux-wake-lock

log() { echo "$(date '+%H:%M:%S') $1" | tee -a "$LOG"; }

{
echo ""
echo "══════════════════════════════"
echo "  AUTORUN — $(date)"
echo "══════════════════════════════"
} >> "$LOG"

# Load config — jangan exit jika tidak ada, lanjut saja
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

# ── [1/3] Optimizer (one-time at boot) ──────────────────────
log "[*] [1/3] Optimizer..."
bash "$HOME/scripts/optimize_rf.sh" >> "$LOG" 2>&1
log "[+] Optimizer selesai."

# ── [2/3] OOM Watcher — daemon dengan auto-restart ──────────
log "[*] [2/3] OOM Watcher daemon..."
(
  while true; do
    bash "$HOME/scripts/oom_watcher.sh" >> "$HOME/oom_watcher.log" 2>&1
    log "[!] OOM watcher mati — restart dalam 5s"
    sleep 5
  done
) &
log "[+] OOM watcher daemon (PID: $!)"

# ── [3/3] Wintercode Agent — watchdog auto-restart ──────────
log "[*] [3/3] Wintercode Agent watchdog..."
if ! command -v lua > /dev/null 2>&1; then
  log "[!] lua tidak terinstall — skip agent."
else
  (
    FAIL_COUNT=0
    while true; do
      if curl -fsSL --max-time 30 "$AGENT_URL" -o "$AGENT_PATH" 2>> "$LOG"; then
        if [ -s "$AGENT_PATH" ]; then
          log "[+] Agent download OK — launching (attempt $((FAIL_COUNT + 1)))"
          lua "$AGENT_PATH" </dev/null >> "$LOG" 2>&1
          log "[!] Agent exit (code $?) — akan restart"
        else
          log "[!] Agent file kosong"
        fi
      else
        log "[!] Download agent gagal"
      fi

      FAIL_COUNT=$((FAIL_COUNT + 1))
      # Backoff eksponensial, max 120s
      WAIT=$(( FAIL_COUNT < 4 ? 15 : (FAIL_COUNT < 8 ? 60 : 120) ))
      log "[*] Restart agent dalam ${WAIT}s (fail #${FAIL_COUNT})"
      sleep $WAIT
    done
  ) &
  log "[+] Agent watchdog (PID: $!)"
fi

log "[+] Boot sequence selesai — semua daemon aktif."
echo "══════════════════════════════" >> "$LOG"

# ── Keep-alive loop ──────────────────────────────────────────
# JANGAN dihapus. Tanpa ini Termux:Boot task langsung exit,
# wake lock lepas, dan semua daemon jadi orphan yang rentan OOM.
while true; do
  sleep 300

  # Cek apakah oom_watcher masih berjalan
  if ! pgrep -f "oom_watcher.sh" > /dev/null 2>&1; then
    log "[!] OOM watcher tidak ditemukan — restart darurat"
    bash "$HOME/scripts/oom_watcher.sh" >> "$HOME/oom_watcher.log" 2>&1 &
  fi

  # Log heartbeat tiap jam
  MINUTE=$(date +%M)
  if [ "$MINUTE" -lt 5 ]; then
    FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
    log "[~] Heartbeat — RAM free: ${FREE_MB}MB"
  fi
done
