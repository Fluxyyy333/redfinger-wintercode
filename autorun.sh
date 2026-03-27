#!/data/data/com.termux/files/usr/bin/bash
# AUTORUN.sh — Boot trigger for Redfinger Optimizer + Wintercode Agent
# Runs via Termux:Boot on every device restart

LOG="$HOME/boot.log"
CONFIG="$HOME/.rf_config"
AGENT_URL="https://api.wintercode.dev/loader/agent-obfuscated.lua"
AGENT_PATH="/sdcard/Download/agent.lua"

echo "" >> "$LOG"
echo "══════════════════════════════" >> "$LOG"
echo "  AUTORUN — $(date)" >> "$LOG"
echo "══════════════════════════════" >> "$LOG"

# Load config
[ -f "$CONFIG" ] && source "$CONFIG" || { echo "[!] Config tidak ditemukan" >> "$LOG"; exit 1; }

# Wait for internet (max 60s)
echo "[*] Menunggu internet..." >> "$LOG"
for i in $(seq 1 12); do
  ping -c 1 8.8.8.8 > /dev/null 2>&1 && { echo "[+] Internet OK" >> "$LOG"; break; }
  echo "[*] Attempt $i/12..." >> "$LOG"
  sleep 5
done

sleep 8

# [1/3] Optimizer
echo "[*] [1/3] Optimizer..." >> "$LOG"
bash "$HOME/scripts/optimize_rf.sh" >> "$LOG" 2>&1
echo "[+] Optimizer selesai." >> "$LOG"

# [2/3] OOM Watcher
echo "[*] [2/3] OOM Watcher..." >> "$LOG"
bash "$HOME/scripts/oom_watcher.sh" >> "$HOME/oom_watcher.log" 2>&1 &
echo "[+] OOM watcher (PID: $!)" >> "$LOG"

# [3/3] Wintercode Agent
echo "[*] [3/3] Wintercode Agent..." >> "$LOG"
if ! command -v lua > /dev/null 2>&1; then
  echo "[!] lua tidak terinstall — skip agent." >> "$LOG"
else
  # Download fresh agent
  curl -fsSL "$AGENT_URL" -o "$AGENT_PATH" 2>> "$LOG"
  if [ -s "$AGENT_PATH" ]; then
    # Run with </dev/null — uses saved config from ~/.winterhub/
    lua "$AGENT_PATH" </dev/null >> "$LOG" 2>&1 &
    echo "[+] Agent started (PID: $!)" >> "$LOG"
  else
    echo "[!] Download agent gagal." >> "$LOG"
  fi
fi

echo "[+] Boot sequence selesai." >> "$LOG"
echo "══════════════════════════════" >> "$LOG"
