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
die() { echo -e "\n  ${E}FATAL: $1${R}\n" | tee -a "$LOG"; exit 1; }

pkg_installed() { dpkg -l "$1" 2>/dev/null | grep -q "^ii"; }

install_pkg() {
  local pkg="$1"
  pkg_installed "$pkg" && { ok "$pkg sudah ada."; return 0; }

  # Attempt 1: langsung pkg install
  run "pkg install $pkg..."
  timeout 120 pkg install -y "$pkg" >> "$LOG" 2>&1
  pkg_installed "$pkg" && { ok "$pkg OK."; return 0; }

  # Attempt 2: ganti repo lalu retry
  run "$pkg gagal, ganti repo & retry..."
  echo 'deb https://packages-cf.termux.dev/apt/termux-main stable main' > "$PREFIX/etc/apt/sources.list"
  timeout 60 pkg update -y >> "$LOG" 2>&1
  timeout 120 pkg install -y "$pkg" >> "$LOG" 2>&1
  pkg_installed "$pkg" && { ok "$pkg OK (retry)."; return 0; }

  err "$pkg gagal install."
  err "Jalankan 'termux-change-repo' lalu 'pkg install $pkg' manual."
  return 1
}

dl() {
  local dest="$1" url="$2" label="$3"
  for i in 1 2 3; do
    run "Download $label ($i/3)..."
    curl -fsSL --retry 2 --max-time 30 "$url" -o "$dest" 2>> "$LOG"
    [ -s "$dest" ] && { ok "OK: $label"; return 0; }
    sleep 2
  done
  die "Gagal download $label!"
}

# ══════════════════════════════════════
echo -e "\n${C}  REDFINGER INSTALLER${R}"
echo -e "${C}  Wintercode Agent + Optimizer${R}\n"

# ── [1/7] Script Key ──────────────────
echo -e "  ${W}[1/7] Script Key${R}"
if [ -n "$1" ]; then
  SCRIPT_KEY="$1"
  ok "Key diterima dari argumen."
else
  echo -e "  ${Y}Masukkan script key (32 hex):${R} "
  read -r SCRIPT_KEY
fi
echo "SCRIPT_KEY=$SCRIPT_KEY" > "$CONFIG"
chmod 600 "$CONFIG"
ok "Key tersimpan."

# ── [2/7] Root ────────────────────────
echo -e "\n  ${W}[2/7] Cek Root${R}"
run "su -c id..."
su -c "id" > /dev/null 2>&1 || die "ROOT GAGAL. Pastikan root aktif."
ok "Root aktif."

# ── [3/7] Packages ────────────────────
echo -e "\n  ${W}[3/7] Install Paket${R}"
run "pkg update..."
timeout 90 pkg update -y >> "$LOG" 2>&1 && ok "pkg update OK." || err "pkg update gagal (lanjut...)"
run "pkg upgrade..."
timeout 300 pkg upgrade -y >> "$LOG" 2>&1 && ok "pkg upgrade OK." || err "pkg upgrade partial (lanjut...)"
for pkg in lua53 tsu termux-boot; do
  install_pkg "$pkg"
done

# ── [4/7] Download Scripts ────────────
echo -e "\n  ${W}[4/7] Download Scripts${R}"
mkdir -p "$HOME/scripts" "$HOME/.termux/boot"
dl "$HOME/.termux/boot/autorun.sh"   "$BASE_URL/autorun.sh"           "autorun.sh"
dl "$HOME/scripts/optimize_rf.sh"    "$BASE_URL/scripts/optimize_rf.sh"  "optimize_rf.sh"
dl "$HOME/scripts/debloat_rf.sh"     "$BASE_URL/scripts/debloat_rf.sh"   "debloat_rf.sh"
dl "$HOME/scripts/oom_watcher.sh"    "$BASE_URL/scripts/oom_watcher.sh"  "oom_watcher.sh"
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
dl "$AGENT_PATH" "$AGENT_URL" "agent.lua"
run "First-run agent (input key)..."
echo "$SCRIPT_KEY" | lua "$AGENT_PATH" >> "$LOG" 2>&1
sleep 3
if [ -d "$HOME/.winterhub" ]; then
  ok "Agent tersetup. Config: ~/.winterhub/"
else
  err "Agent mungkin belum tersimpan config. Cek manual."
fi
# Agent sudah jalan di background dari first-run
AGENT_PID=$(pgrep -f "lua.*agent" 2>/dev/null | head -1)
[ -n "$AGENT_PID" ] && ok "Agent berjalan (PID: $AGENT_PID)" || err "Agent tidak terdeteksi. Cek: lua $AGENT_PATH </dev/null"

# ── [7/7] OOM Watcher ─────────────────
echo -e "\n  ${W}[7/7] OOM Watcher${R}"
run "Start oom_watcher..."
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
