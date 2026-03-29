#!/data/data/com.termux/files/usr/bin/bash
# OOM_WATCHER.sh — Protect critical processes from OOM killer
# Dijalankan sebagai daemon oleh autorun.sh — jangan run manual
#
# OOM score gradient (lower = more protected):
#   -800  watcher self    (ringan, harus hidup paling lama)
#   -400  com.termux      (infrastruktur)
#   -300  lua agent       (konektivitas)
#   -200  com.fluxy*      (workload, heavy RAM — harus bisa di-sacrifice terakhir)
#
# Jangan set semua ke -900/-1000. Kalau tidak ada target yang bisa
# di-kill, OOM killer bisa random kill atau trigger device reboot.

LOG="${LOG:-$HOME/oom_watcher.log}"
echo "=== OOM WATCHER START: $(date) ===" >> "$LOG"

# Self-protect: watcher harus hidup paling lama
su -c "echo -800 > /proc/$$/oom_score_adj" 2>/dev/null

PROTECTED=()

protect_pid() {
  local pid="$1"
  local score="$2"
  local label="$3"
  if su -c "echo $score > /proc/$pid/oom_score_adj" 2>/dev/null; then
    echo "[+] Protected: $label (PID $pid, score $score) $(date +%H:%M:%S)" >> "$LOG"
    return 0
  fi
  return 1
}

while true; do

  # ── Protect Termux ──
  TERMUX_PIDS=$(su -c "ps -A 2>/dev/null | grep 'com\.termux' | awk '{print \$2}'")
  for pid in $TERMUX_PIDS; do
    [ -z "$pid" ] && continue
    protect_pid "$pid" -400 "com.termux"
  done

  # ── Protect Lua agent ──
  LUA_PID=$(pgrep -n lua 2>/dev/null)
  [ -n "$LUA_PID" ] && protect_pid "$LUA_PID" -300 "lua-agent"

  # ── Protect com.fluxy* instances ──
  CURRENT_PIDS=$(su -c "ps -A 2>/dev/null | grep 'com\.fluxy' | awk '{print \$2}'")
  for pid in $CURRENT_PIDS; do
    [ -z "$pid" ] && continue
    if [[ ! " ${PROTECTED[@]} " =~ " $pid " ]]; then
      PKG=$(su -c "cat /proc/$pid/cmdline 2>/dev/null | tr -d '\0'")
      if protect_pid "$pid" -200 "$PKG"; then
        PROTECTED+=($pid)
      fi
    fi
  done

  # ── Bersihkan PID mati dari tracking ──
  ALIVE=()
  for pid in "${PROTECTED[@]}"; do
    kill -0 "$pid" 2>/dev/null && ALIVE+=($pid)
  done
  PROTECTED=("${ALIVE[@]}")

  COUNT=${#PROTECTED[@]}
  [ $COUNT -gt 0 ] && echo "[~] Active fluxy instances: $COUNT $(date +%H:%M:%S)" >> "$LOG"

  sleep 15
done
