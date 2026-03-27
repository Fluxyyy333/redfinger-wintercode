#!/data/data/com.termux/files/usr/bin/bash
# INSTALL.sh — Redfinger Optimizer + Wintercode Agent
# Redfinger Android 10 ARM64 | Roblox Multi-Instance

CONFIG="$HOME/.rf_config"
LOG="$HOME/install.log"
BASE_URL="https://raw.githubusercontent.com/Fluxyyy333/redfinger-wintercode/main"
AGENT_URL="https://api.wintercode.dev/loader/agent-obfuscated.lua"
AGENT_PATH="/sdcard/Download/agent.lua"

R=$'\033[0m'; G=$'\033[0;32m'; E=$'\033[0;31m'; Y=$'\033[0;33m'; C=$'\033[1;36m'; W=$'\033[1;37m'

echo "=== INSTALL: $(date) ===" > "$LOG"

ok()  { echo -e "  ${G}✓${R} $1" | tee -a "$LOG"; }
err() { echo -e "  ${E}✗${R} $1" | tee -a "$LOG"; }
run() { echo -e "  ${Y}>${R} $1" | tee -a "$LOG"; }

echo -e "\n${C}  REDFINGER INSTALLER${R}"
echo -e "${C}  Wintercode Agent + Optimizer${R}\n"

# ── [1/7] Script Key ──────────────────
echo -e "  ${W}[1/7] Script Key${R}"
if [ -n "$1" ]; then
  SCRIPT_KEY="$1"
  ok "Key diterima dari argumen."
else
  echo -ne "  ${Y}Masukkan script key (32 hex):${R} "
  read -r SCRIPT_KEY
fi
echo "SCRIPT_KEY=$SCRIPT_KEY" > "$CONFIG"
chmod 600 "$CONFIG"
ok "Key tersimpan."

# ── [2/7] Root ────────────────────────
echo -e "\n  ${W}[2/7] Cek Root${R}"
su -c "id" > /dev/null 2>&1 || { err "ROOT GAGAL."; exit 1; }
ok "Root aktif."

# ── [3/7] Packages ────────────────────
echo -e "\n  ${W}[3/7] Install Paket${R}"
run "pkg update & upgrade..."
pkg update -y 2>&1 | tee -a "$LOG"
DEBIAN_FRONTEND=noninteractive pkg upgrade -y -o Dpkg::Options::="--force-confnew" 2>&1 | tee -a "$LOG"
run "pkg install lua53 tsu termux-boot..."
pkg install -y lua53 tsu termux-boot 2>&1 | tee -a "$LOG"

# Verify
if command -v lua > /dev/null 2>&1; then
  ok "lua53 OK: $(lua -v 2>&1 | head -1)"
else
  err "lua53 GAGAL. Coba manual:"
  err "  termux-change-repo"
  err "  pkg install lua53"
  exit 1
fi

# ── [4/7] Download Scripts ────────────
echo -e "\n  ${W}[4/7] Download Scripts${R}"
mkdir -p "$HOME/scripts" "$HOME/.termux/boot"
for f in autorun.sh scripts/optimize_rf.sh scripts/debloat_rf.sh scripts/oom_watcher.sh; do
  run "Download $f..."
  curl -fsSL --retry 3 "$BASE_URL/$f" -o "$HOME/$f" 2>> "$LOG"
  [ -s "$HOME/$f" ] && ok "$f" || err "GAGAL: $f"
done
# autorun.sh goes to boot dir
mv "$HOME/autorun.sh" "$HOME/.termux/boot/autorun.sh" 2>/dev/null
chmod +x "$HOME/.termux/boot/autorun.sh" "$HOME/scripts/"*.sh
ok "Semua script siap."

# ── [5/7] Debloat & Optimasi ──────────
echo -e "\n  ${W}[5/7] Debloat & Optimasi${R}"
run "debloat_rf.sh..."
bash "$HOME/scripts/debloat_rf.sh" >> "$LOG" 2>&1
ok "Debloat selesai."
run "optimize_rf.sh..."
bash "$HOME/scripts/optimize_rf.sh" >> "$LOG" 2>&1
ok "Optimasi selesai."

# ── [6/7] Wintercode Agent ────────────
echo -e "\n  ${W}[6/7] Wintercode Agent${R}"
run "Download agent.lua..."
curl -L -o "$AGENT_PATH" "$AGENT_URL" 2>&1 | tee -a "$LOG"
[ -s "$AGENT_PATH" ] || { err "Download agent gagal."; exit 1; }
ok "agent.lua downloaded."
run "First-run agent..."
echo "$SCRIPT_KEY" | lua "$AGENT_PATH" 2>&1 | tee -a "$LOG"
sleep 3
[ -d "$HOME/.winterhub" ] && ok "Agent config OK." || err "Config belum ada. Cek manual."
AGENT_PID=$(pgrep -f "lua.*agent" 2>/dev/null | head -1)
[ -n "$AGENT_PID" ] && ok "Agent running (PID: $AGENT_PID)" || err "Agent tidak jalan. Run manual: lua $AGENT_PATH </dev/null"

# ── [7/7] OOM Watcher ─────────────────
echo -e "\n  ${W}[7/7] OOM Watcher${R}"
bash "$HOME/scripts/oom_watcher.sh" >> "$HOME/oom_watcher.log" 2>&1 &
ok "OOM watcher aktif (PID: $!)"

# ── Done ──────────────────────────────
FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal    /proc/meminfo | awk '{print $2}') / 1024 ))

echo -e "\n${G}  ✓ INSTALL SELESAI${R}"
echo "  ─────────────────────────────"
echo -e "  RAM   : ${W}${FREE_MB}MB${R} / ${TOTAL_MB}MB"
echo -e "  Agent : ${G}Wintercode${R}"
echo -e "  OOM   : ${G}Aktif${R}"
echo -e "  Boot  : ${G}Siap${R} (Termux:Boot)"
echo "  ─────────────────────────────"
echo "  Restart Redfinger untuk"
echo "  aktifkan autorun."
echo -e "  Log: ~/install.log\n"
