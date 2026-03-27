#!/data/data/com.termux/files/usr/bin/bash
# OOM_WATCHER.sh — Continuously protect Roblox instances from OOM killer
# Run this in background: bash ~/scripts/oom_watcher.sh &
# Watches for new Roblox PIDs every 15s and applies OOM protection

LOG="${LOG:-$HOME/oom_watcher.log}"
echo "=== OOM WATCHER START: $(date) ===" >> "$LOG"

PROTECTED=()

while true; do
  # Get all com.fluxy* PIDs (cloned Roblox instances)
  CURRENT_PIDS=$(su -c "ps -A 2>/dev/null | grep 'com\.fluxy' | awk '{print \$2}'" )

  for pid in $CURRENT_PIDS; do
    # Only apply if not already protected
    if [[ ! " ${PROTECTED[@]} " =~ " $pid " ]]; then
      su -c "echo -300 > /proc/$pid/oom_score_adj" 2>/dev/null
      PKG=$(su -c "cat /proc/$pid/cmdline 2>/dev/null | tr -d '\0'")
      PROTECTED+=($pid)
      echo "[+] OOM protect: PID $pid ($PKG) $(date +%H:%M:%S)" >> "$LOG"
      echo -e "\033[0;32m[OOM]\033[0m Protected: $PKG (PID $pid)"
    fi
  done

  # Clean dead PIDs from tracking list
  ALIVE=()
  for pid in "${PROTECTED[@]}"; do
    kill -0 "$pid" 2>/dev/null && ALIVE+=($pid)
  done
  PROTECTED=("${ALIVE[@]}")

  COUNT=${#PROTECTED[@]}
  [ $COUNT -gt 0 ] && echo "[*] Active protected instances: $COUNT" >> "$LOG"

  sleep 15
done
