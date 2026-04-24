#!/data/data/com.termux/files/usr/bin/bash
# Zboot.sh — Auto-optimization on boot
# Place in ~/.termux/boot/ — executes AFTER winterhub_agent.sh (alphabetical)
# Does NOT edit winterhub_agent.sh — runs independently

LOG="$HOME/Zboot.log"
BASE_URL="https://raw.githubusercontent.com/Fluxyyy333/redfinger-wintercode/main"

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG"; }

{
echo ""
echo "══════════════════════════════"
echo "  ZBOOT — $(date)"
echo "══════════════════════════════"
} >> "$LOG"

log "[boot] Zboot started"

# Wait for boot + root
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do sleep 3; done
while ! su -c "id" >/dev/null 2>&1; do sleep 2; done
sleep 10

# Download latest optimization scripts
mkdir -p "$HOME/scripts"
for f in Zdebloat.sh Zoptimize.sh Zmemory.sh Zdeep.sh Zwatchdog.sh; do
    curl -sL --max-time 15 "$BASE_URL/scripts/$f" -o "$HOME/scripts/$f.tmp" 2>/dev/null
    if [ -s "$HOME/scripts/$f.tmp" ]; then
        mv "$HOME/scripts/$f.tmp" "$HOME/scripts/$f"
        chmod +x "$HOME/scripts/$f"
        log "[boot] downloaded $f"
    else
        rm -f "$HOME/scripts/$f.tmp"
        log "[boot] download failed: $f (using cached)"
    fi
done

# Run optimization suite
bash "$HOME/scripts/Zdebloat.sh"  >> "$LOG" 2>&1
log "[boot] debloat done"
bash "$HOME/scripts/Zoptimize.sh" >> "$LOG" 2>&1
log "[boot] optimize done"
bash "$HOME/scripts/Zmemory.sh"   >> "$LOG" 2>&1
log "[boot] memory done"
bash "$HOME/scripts/Zdeep.sh"    >> "$LOG" 2>&1
log "[boot] deep optimize done"

# Start watchdog (kill old instance first)
pkill -f Zwatchdog.sh 2>/dev/null
sleep 1
nohup bash "$HOME/scripts/Zwatchdog.sh" >> "$HOME/Zwatchdog.log" 2>&1 &
log "[boot] watchdog started PID=$!"

FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
log "[boot] Zboot complete — RAM: ${FREE_MB}MB / ${TOTAL_MB}MB"
echo "══════════════════════════════" >> "$LOG"
