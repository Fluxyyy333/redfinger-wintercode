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

# ── [1/8] Script Key ──────────────────
echo -e "  ${W}[1/8] Script Key${R}"
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

# ── [2/8] Root ────────────────────────
echo -e "\n  ${W}[2/8] Cek Root${R}"
su -c "id" > /dev/null 2>&1 || { err "ROOT GAGAL."; exit 1; }
ok "Root aktif."

# ── Mirror helpers ────────────────────
FALLBACK_MIRRORS=(
  "https://packages-cf.termux.dev/apt/termux-main"
  "https://packages.termux.dev/apt/termux-main"
  "https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main"
  "https://mirrors.ustc.edu.cn/termux/termux-main"
  "https://grimler.se/termux/termux-main"
  "https://mirror.quantum5.ca/termux/termux-main"
)
_MIRROR_IDX=0

switch_mirror() {
  local mirror="${FALLBACK_MIRRORS[$_MIRROR_IDX]}"
  _MIRROR_IDX=$(( (_MIRROR_IDX + 1) % ${#FALLBACK_MIRRORS[@]} ))
  run "Switch mirror → $mirror"
  echo "deb $mirror stable main" \
    > /data/data/com.termux/files/usr/etc/apt/sources.list
}

is_mirror_error() {
  echo "$1" | grep -qE \
    "unexpected size|Mirror sync in progress|Failed to fetch|Some index files failed"
}

pkg_update_retry() {
  local attempt=0 max=6
  while [ $attempt -lt $max ]; do
    out=$(pkg update -y 2>&1); echo "$out" | tee -a "$LOG"
    if is_mirror_error "$out"; then
      attempt=$((attempt + 1))
      err "Mirror error ($attempt/$max), ganti mirror..."
      switch_mirror
      sleep 2
    else
      ok "pkg update OK"; return 0
    fi
  done
  err "pkg update gagal setelah $max percobaan"
  return 1
}

pkg_install_retry() {
  local pkg="$1" attempt=0 max=4
  while [ $attempt -lt $max ]; do
    out=$(pkg install -y "$pkg" 2>&1); echo "$out" | tee -a "$LOG"
    if is_mirror_error "$out"; then
      attempt=$((attempt + 1))
      err "$pkg mirror error ($attempt/$max), retry update..."
      pkg_update_retry
    else
      return 0
    fi
  done
  err "$pkg gagal setelah $max percobaan"
  return 1
}

# ── [3/8] Packages ────────────────────
echo -e "\n  ${W}[3/8] Install Paket${R}"
pkg_update_retry || { err "Tidak bisa update. Abort."; exit 1; }

run "pkg upgrade..."
DEBIAN_FRONTEND=noninteractive pkg upgrade -y \
  -o Dpkg::Options::="--force-confnew" 2>&1 | tee -a "$LOG"

run "pkg install lua53..."
pkg_install_retry lua53

run "pkg install tsu..."
pkg_install_retry tsu

# Verify lua
if command -v lua > /dev/null 2>&1; then
  ok "lua OK: $(lua -v 2>&1 | head -1)"
else
  err "lua53 GAGAL setelah semua retry."
  exit 1
fi

# ── [4/8] Termux:Boot ─────────────────
echo -e "\n  ${W}[4/8] Termux:Boot${R}"
if su -c "pm list packages 2>/dev/null" | grep -q "com.termux.boot"; then
  ok "Termux:Boot sudah terinstall."
else
  run "Download Termux:Boot APK..."
  BOOT_APK="/sdcard/Download/termux-boot.apk"
  BOOT_OK=0
  for vc in 8 7; do
    if curl -fsSL --max-time 30 -o "$BOOT_APK" \
      "https://f-droid.org/repo/com.termux.boot_${vc}.apk" 2>> "$LOG"; then
      [ -s "$BOOT_APK" ] && { BOOT_OK=1; break; }
    fi
  done

  if [ $BOOT_OK -eq 1 ]; then
    run "Install APK via pm install..."
    if su -c "pm install '$BOOT_APK'" >> "$LOG" 2>&1; then
      ok "Termux:Boot terinstall."
    else
      err "pm install gagal. Install manual: $BOOT_APK"
    fi
    rm -f "$BOOT_APK"
  else
    err "Download APK gagal. Install manual dari F-Droid."
  fi
fi

# Buka 1x agar Android register BOOT_COMPLETED receiver
run "Register boot receiver..."
su -c "monkey -p com.termux.boot -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
sleep 2
su -c "am force-stop com.termux.boot" 2>/dev/null

# Doze whitelist agar boot receiver tidak di-block
su -c "dumpsys deviceidle whitelist +com.termux.boot" 2>/dev/null
su -c "am set-standby-bucket com.termux.boot active" 2>/dev/null
ok "Boot receiver registered & doze whitelisted."

# ── [5/8] Download Scripts ────────────
echo -e "\n  ${W}[5/8] Download Scripts${R}"
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

# ── [6/8] Debloat & Optimasi ──────────
echo -e "\n  ${W}[6/8] Debloat & Optimasi${R}"
run "debloat_rf.sh..."
bash "$HOME/scripts/debloat_rf.sh" >> "$LOG" 2>&1
ok "Debloat selesai."
run "optimize_rf.sh..."
bash "$HOME/scripts/optimize_rf.sh" >> "$LOG" 2>&1
ok "Optimasi selesai."

# ── [7/8] Wintercode Agent ────────────
echo -e "\n  ${W}[7/8] Wintercode Agent${R}"
run "Download agent.lua..."
curl -L -o "$AGENT_PATH" "$AGENT_URL" 2>&1 | tee -a "$LOG"
[ -s "$AGENT_PATH" ] || { err "Download agent gagal."; exit 1; }
ok "agent.lua downloaded."

# Run 1: install modules (cjson dll)
run "Setup modules..."
lua "$AGENT_PATH" </dev/null >> "$LOG" 2>&1
sleep 2
ok "Modules installed."

# Inject key langsung ke ~/.winterhub/key.txt
run "Inject script key..."
mkdir -p "$HOME/.winterhub"
printf '%s' "$SCRIPT_KEY" > "$HOME/.winterhub/script_key"
ok "Key tersimpan di ~/.winterhub/script_key"

# Run 2: actual run (baca key dari file)
run "Start agent..."
lua "$AGENT_PATH" </dev/null 2>&1 | tee -a "$LOG"
sleep 3
[ -d "$HOME/.winterhub" ] && ok "Agent config OK." || err "Config belum ada. Cek manual."
AGENT_PID=$(pgrep -f "lua.*agent" 2>/dev/null | head -1)
[ -n "$AGENT_PID" ] && ok "Agent running (PID: $AGENT_PID)" || err "Agent tidak jalan. Run manual: lua $AGENT_PATH </dev/null"

# ── [8/8] Boot Guard ─────────────────
echo -e "\n  ${W}[8/8] Boot Guard${R}"

# Start OOM watcher for current session
bash "$HOME/scripts/oom_watcher.sh" >> "$HOME/oom_watcher.log" 2>&1 &
ok "OOM watcher aktif (PID: $!)"

# .bashrc guard — backup trigger jika Termux:Boot gagal
GUARD_MARKER="# AUTORUN_GUARD"
if grep -q "$GUARD_MARKER" "$HOME/.bashrc" 2>/dev/null; then
  ok ".bashrc guard sudah ada."
else
  cat >> "$HOME/.bashrc" << 'BASHRC'

# AUTORUN_GUARD — backup trigger jika Termux:Boot gagal
if [ -f "$HOME/.termux/boot/autorun.sh" ]; then
  if ! pgrep -f "oom_watcher.sh" > /dev/null 2>&1; then
    echo "[.bashrc] Daemon belum jalan — trigger autorun..."
    nohup bash "$HOME/.termux/boot/autorun.sh" > /dev/null 2>&1 &
    disown
  fi
fi
BASHRC
  ok ".bashrc guard terpasang."
fi

# ── Done ──────────────────────────────
FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal    /proc/meminfo | awk '{print $2}') / 1024 ))

echo -e "\n${G}  ✓ INSTALL SELESAI${R}"
echo "  ─────────────────────────────"
echo -e "  RAM   : ${W}${FREE_MB}MB${R} / ${TOTAL_MB}MB"
echo -e "  Agent : ${G}Wintercode${R}"
echo -e "  OOM   : ${G}Aktif${R}"
echo -e "  Boot  : ${G}Termux:Boot + .bashrc guard${R}"
echo "  ─────────────────────────────"
echo "  Restart Redfinger untuk"
echo "  aktifkan autorun."
echo -e "  Log: ~/install.log\n"
