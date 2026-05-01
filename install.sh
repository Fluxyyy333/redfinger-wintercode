#!/data/data/com.termux/files/usr/bin/bash
# INSTALL.sh — Redfinger Optimizer + Wintercode Agent
# Redfinger Android 10 ARM64 | Roblox Multi-Instance

CONFIG="$HOME/.rf_config"
LOG="$HOME/install.log"
BASE_URL="https://raw.githubusercontent.com/Fluxyyy333/redfinger-wintercode/main"
AGENT_URL="https://api.wintercode.dev/loader/agent-obfuscated.lua"
AGENT_PATH="/sdcard/Download/agent.lua"
SPOOFER_URL="${BASE_URL}/spoofer.apk"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
WINTERHUB_DIR="$HOME/.winterhub"

R=$'\033[0m'; G=$'\033[0;32m'; E=$'\033[0;31m'; Y=$'\033[0;33m'; C=$'\033[1;36m'; W=$'\033[1;37m'

echo "=== INSTALL: $(date) ===" > "$LOG"

ok()  { echo -e "  ${G}✓${R} $1" | tee -a "$LOG"; }
err() { echo -e "  ${E}✗${R} $1" | tee -a "$LOG"; }
run() { echo -e "  ${Y}>${R} $1" | tee -a "$LOG"; }

echo -e "\n${C}  REDFINGER INSTALLER${R}"
echo -e "${C}  Wintercode Agent + Optimizer${R}\n"

# ── [1/8] Script Key ─────────────────────────────────────────
echo -e "  ${W}[1/8] Script Key${R}"
if [ -n "$1" ]; then
  SCRIPT_KEY="$1"
  ok "Key diterima dari argumen."
else
  echo -ne "  ${Y}Masukkan script key (16+ alfanumerik):${R} "
  read -r SCRIPT_KEY
fi

if ! echo "$SCRIPT_KEY" | grep -qE '^[A-Za-z0-9]{16,}$'; then
  err "Script key format invalid (harus minimal 16 karakter alfanumerik)."
  exit 1
fi

DELTA_SERIAL="${2:-0d53eeeecba69355:00918b9b}"

CONFIG_TMP="${CONFIG}.tmp"
{
  echo "SCRIPT_KEY=$SCRIPT_KEY"
  echo "DELTA_SERIAL=$DELTA_SERIAL"
} > "$CONFIG_TMP"
mv "$CONFIG_TMP" "$CONFIG"
chmod 600 "$CONFIG"
ok "Config tersimpan."
ok "Serial: $DELTA_SERIAL"

# ── [2/8] Root ───────────────────────────────────────────────
echo -e "\n  ${W}[2/8] Cek Root${R}"
su -c "id" > /dev/null 2>&1 || { err "ROOT GAGAL."; exit 1; }
ok "Root aktif."

# ── Mirror helpers ───────────────────────────────────────────
FALLBACK_MIRRORS=(
  "https://packages-cf.termux.dev/apt/termux-main"
  "https://packages.termux.dev/apt/termux-main"
  "https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main"
  "https://mirrors.ustc.edu.cn/termux/termux-main"
  "https://grimler.se/termux/termux-main"
  "https://mirror.quantum5.ca/termux/termux-main"
)
_MIRROR_IDX=0
APT_DIR="/data/data/com.termux/files/usr/etc/apt"
APT_LISTS="/data/data/com.termux/files/usr/var/lib/apt/lists"

switch_mirror() {
  local mirror="${FALLBACK_MIRRORS[$_MIRROR_IDX]}"
  _MIRROR_IDX=$(( (_MIRROR_IDX + 1) % ${#FALLBACK_MIRRORS[@]} ))
  run "Switch mirror → $mirror"
  rm -rf "$APT_LISTS"/* 2>/dev/null
  echo "deb $mirror stable main" > "$APT_DIR/sources.list"
  if [ -d "$APT_DIR/sources.list.d" ]; then
    for f in "$APT_DIR/sources.list.d"/*.list; do
      [ -f "$f" ] || continue
      sed -i "s|deb [^ ]*/termux-main|deb $mirror|" "$f" 2>/dev/null
    done
  fi
}

is_mirror_error() {
  echo "$1" | grep -qiE "unexpected size|Mirror sync in progress|Failed to fetch|Some index files failed|does not have a Release file|Redirection from https|is not signed|NO_PUBKEY"
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

# ── [3/8] Install Paket ──────────────────────────────────────
echo -e "\n  ${W}[3/8] Install Paket${R}"
run "Cek mirror saat ini..."
CURRENT_MIRROR=$(head -1 "$APT_DIR/sources.list" 2>/dev/null | awk '{print $2}')
if echo "$CURRENT_MIRROR" | grep -qvE "packages-cf.termux.dev|packages.termux.dev|grimler.se|quantum5.ca|tuna.tsinghua|ustc.edu"; then
  run "Mirror default tidak dikenal — switch ke mirror terpercaya..."
  switch_mirror
fi
pkg_update_retry || { err "Tidak bisa update. Abort."; exit 1; }

run "pkg upgrade..."
DEBIAN_FRONTEND=noninteractive pkg upgrade -y \
  -o Dpkg::Options::="--force-confnew" 2>&1 | tee -a "$LOG"

run "pkg install lua53..."
pkg_install_retry lua53

run "pkg install tsu..."
pkg_install_retry tsu

run "pkg install cronie..."
pkg_install_retry cronie
crond 2>/dev/null

if command -v lua > /dev/null 2>&1; then
  ok "lua OK: $(lua -v 2>&1 | head -1)"
else
  err "lua53 GAGAL setelah semua retry."
  exit 1
fi

# ── [4/8] Download Scripts ───────────────────────────────────
echo -e "\n  ${W}[4/8] Download Scripts${R}"
mkdir -p "$HOME/scripts" "$HOME/.termux/boot"

for f in Zoptimize.sh Zwatchdog.sh delta_setup.sh; do
  run "Download scripts/$f..."
  curl -fsSL --retry 3 "$BASE_URL/scripts/$f" -o "$HOME/scripts/$f.tmp" 2>> "$LOG"
  if [ -s "$HOME/scripts/$f.tmp" ] && head -1 "$HOME/scripts/$f.tmp" | grep -q '^#!'; then
    mv "$HOME/scripts/$f.tmp" "$HOME/scripts/$f"
    ok "$f"
  else
    rm -f "$HOME/scripts/$f.tmp"
    err "GAGAL: $f (download corrupt atau kosong)"
  fi
done
chmod +x "$HOME/scripts/"*.sh

run "Download Zboot.sh..."
curl -fsSL --retry 3 "$BASE_URL/Zboot.sh" -o "$HOME/.termux/boot/Zboot.sh.tmp" 2>> "$LOG"
if [ -s "$HOME/.termux/boot/Zboot.sh.tmp" ] && head -1 "$HOME/.termux/boot/Zboot.sh.tmp" | grep -q '^#!'; then
  mv "$HOME/.termux/boot/Zboot.sh.tmp" "$HOME/.termux/boot/Zboot.sh"
  chmod +x "$HOME/.termux/boot/Zboot.sh"
  ok "Zboot.sh → ~/.termux/boot/"
else
  rm -f "$HOME/.termux/boot/Zboot.sh.tmp"
  err "GAGAL: Zboot.sh"
fi

for _f in "$HOME/scripts/Zoptimize.sh" "$HOME/scripts/Zwatchdog.sh"; do
  [ -s "$_f" ] || { err "KRITIKAL: $_f tidak ada — abort."; exit 1; }
done
ok "Semua scripts siap."

# ── [5/8] Optimasi ───────────────────────────────────────────
echo -e "\n  ${W}[5/8] Optimasi${R}"
run "Zoptimize.sh..."
bash "$HOME/scripts/Zoptimize.sh" >> "$LOG" 2>&1
ok "Optimasi selesai."

run "Start Zwatchdog.sh..."
pkill -f Zwatchdog.sh 2>/dev/null
sleep 2
nohup bash "$HOME/scripts/Zwatchdog.sh" >> "$HOME/Zwatchdog.log" 2>&1 &
echo "$!" > "$HOME/.watchdog.pid"
ok "Watchdog started PID=$!"

# ── [6/8] Wintercode Agent ───────────────────────────────────
echo -e "\n  ${W}[6/8] Wintercode Agent${R}"

termux-wake-lock 2>/dev/null || true
ok "Wake-lock aktif."

find_lua() {
  for cmd in lua5.4 lua54 lua5.3 lua53 lua; do
    local p
    p=$(command -v "$cmd" 2>/dev/null) && [ -x "$p" ] && { echo "$p"; return 0; }
  done
  [ -x "$TERMUX_PREFIX/bin/lua" ] && { echo "$TERMUX_PREFIX/bin/lua"; return 0; }
  return 1
}

eval "$(luarocks path 2>/dev/null)" || true
LUA_BIN=$(find_lua) || { err "Lua tidak ditemukan."; exit 1; }
ok "Lua: $LUA_BIN ($(${LUA_BIN} -v 2>&1 | head -1))"

run "Download agent.lua..."
curl -sL --max-time 30 --connect-timeout 10 -o "$AGENT_PATH.tmp" "$AGENT_URL" 2>> "$LOG"
if [ -s "$AGENT_PATH.tmp" ] && [ "$(wc -c < "$AGENT_PATH.tmp" | tr -d ' ')" -ge 300000 ]; then
  mv "$AGENT_PATH.tmp" "$AGENT_PATH"
  ok "agent.lua downloaded ($(wc -c < "$AGENT_PATH" | tr -d ' ') bytes)"
else
  rm -f "$AGENT_PATH.tmp"
  [ ! -f "$AGENT_PATH" ] && { err "Download agent gagal, tidak ada agent.lua."; exit 1; }
  err "Download gagal, pakai agent.lua yang sudah ada."
fi

run "Inject script key..."
mkdir -p "$WINTERHUB_DIR"
printf '%s' "$SCRIPT_KEY" > "$WINTERHUB_DIR/script_key"
export SCRIPT_KEY
ok "Key tersimpan di ~/.winterhub/script_key"

run "Launch agent..."
rm -f "$WINTERHUB_DIR/main.pid" 2>/dev/null
cd "$(dirname "$AGENT_PATH")"
"$LUA_BIN" "$AGENT_PATH" > /dev/null 2>&1 &

PWAIT=0
while [ ! -s "$WINTERHUB_DIR/main.pid" ] && [ $PWAIT -lt 15 ]; do
  sleep 2; PWAIT=$((PWAIT+1))
done
PID=$(cat "$WINTERHUB_DIR/main.pid" 2>/dev/null)
if [ -n "$PID" ] && su -c "kill -0 $PID" 2>/dev/null; then
  ok "Agent running (PID: $PID)"
else
  err "Agent tidak terdeteksi — mungkin masih starting. Cek ~/install.log"
fi
[ -d "$WINTERHUB_DIR" ] && ok "Agent config OK." || err "Config belum ada."

# ── [7/8] Delta Spoofer ──────────────────────────────────────
echo -e "\n  ${W}[7/8] Delta Spoofer${R}"
run "Download + install spoofer vault..."
curl -fsSL --retry 3 "$SPOOFER_URL" -o "/sdcard/Download/spoofer.apk" 2>> "$LOG"
if [ -s "/sdcard/Download/spoofer.apk" ]; then
  su -c "pm install -r /sdcard/Download/spoofer.apk" >> "$LOG" 2>&1
  ok "spoofer.apk installed"
else
  err "Download spoofer gagal"
fi

RESETPROP="/data/local/tmp/resetprop"
SPOOFER_PKG="com.stealth.vault"

# Split android_id and serial from DELTA_SERIAL (format: "aid:serial")
if echo "$DELTA_SERIAL" | grep -q ':'; then
  AID_TARGET="${DELTA_SERIAL%%:*}"
  SER_TARGET="${DELTA_SERIAL##*:}"
else
  AID_TARGET="$DELTA_SERIAL"
  SER_TARGET="$DELTA_SERIAL"
fi

APK_LINE=$(su -c "pm path $SPOOFER_PKG" 2>/dev/null)
if [ -n "$APK_LINE" ]; then
  APK_DIR=$(dirname "${APK_LINE#package:}")
  LIB=$(su -c "find \"$APK_DIR\" -name 'libresetprop.so' 2>/dev/null" | head -1)
  if [ -n "$LIB" ]; then
    su -c "cp \"$LIB\" \"$RESETPROP\" && chmod 755 \"$RESETPROP\""
    su -c "$RESETPROP ro.serialno $SER_TARGET" 2>/dev/null
    su -c "$RESETPROP ro.boot.serialno $SER_TARGET" 2>/dev/null
    su -c "settings put secure android_id $AID_TARGET" 2>/dev/null
    ACTUAL_SER=$(su -c "getprop ro.serialno" 2>/dev/null)
    ACTUAL_AID=$(su -c "settings get secure android_id" 2>/dev/null)
    if [ "$ACTUAL_SER" = "$SER_TARGET" ] && [ "$ACTUAL_AID" = "$AID_TARGET" ]; then
      ok "HWID spoof VERIFIED: aid=$AID_TARGET ser=$SER_TARGET"
    else
      err "HWID MISMATCH! expected aid=$AID_TARGET ser=$SER_TARGET got aid=$ACTUAL_AID ser=$ACTUAL_SER"
    fi
  else
    err "libresetprop.so not found in spoofer APK"
  fi
else
  err "Spoofer APK not installed"
fi

# ── [8/8] Boot Guard + Cleanup ───────────────────────────────
echo -e "\n  ${W}[8/8] Boot Guard${R}"

run "Install winterhub_agent.sh..."
curl -fsSL --retry 3 "$BASE_URL/winterhub_agent.sh" -o "$HOME/.termux/boot/winterhub_agent.sh.tmp" 2>> "$LOG"
if [ -s "$HOME/.termux/boot/winterhub_agent.sh.tmp" ] && head -1 "$HOME/.termux/boot/winterhub_agent.sh.tmp" | grep -q '^#!'; then
  mv "$HOME/.termux/boot/winterhub_agent.sh.tmp" "$HOME/.termux/boot/winterhub_agent.sh"
  sed -i "s/^SCRIPT_KEY=\"\"/SCRIPT_KEY=\"$SCRIPT_KEY\"/" "$HOME/.termux/boot/winterhub_agent.sh"
  chmod +x "$HOME/.termux/boot/winterhub_agent.sh"
  ok "winterhub_agent.sh terpasang di ~/.termux/boot/"
else
  rm -f "$HOME/.termux/boot/winterhub_agent.sh.tmp"
  err "Gagal download boot script."
fi
ok "Zboot.sh sudah terpasang di ~/.termux/boot/ (dari step 4)"

run "Setup crontab..."
CRON_WD='* * * * * pgrep -f Zwatchdog.sh >/dev/null || nohup bash $HOME/scripts/Zwatchdog.sh >> $HOME/Zwatchdog.log 2>&1 &'
CRON_BOOT='@reboot sleep 30 && bash $HOME/.termux/boot/Zboot.sh'
( echo "$CRON_WD"; echo "$CRON_BOOT" ) | crontab - 2>/dev/null
ok "Crontab installed (watchdog self-heal + boot fallback)"

# Remove legacy scripts that used pm disable-user or are now merged
for old in Zdebloat.sh Zmemory.sh Zdeep.sh debloat_rf.sh optimize_rf.sh; do
  if [ -f "$HOME/scripts/$old" ]; then
    rm -f "$HOME/scripts/$old"
    ok "Removed legacy $old"
  fi
done

# ── Done ─────────────────────────────────────────────────────
FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal    /proc/meminfo | awk '{print $2}') / 1024 ))

echo -e "\n${G}  INSTALL SELESAI${R}"
echo "  ─────────────────────────────"
echo -e "  RAM   : ${W}${FREE_MB}MB${R} / ${TOTAL_MB}MB"
echo -e "  Agent : ${G}Wintercode${R}"
echo -e "  Boot  : ${G}winterhub_agent.sh + Zboot.sh${R}"
echo -e "  Optim : ${G}Zoptimize.sh (consolidated)${R}"
echo -e "  Daemon: ${G}Zwatchdog (300s cycle)${R}"
echo -e "  Cron  : ${G}watchdog self-heal + @reboot fallback${R}"
echo -e "  HWID  : ${G}$DELTA_SERIAL${R}"
echo "  ─────────────────────────────"
echo "  Restart Redfinger untuk"
echo "  aktifkan boot chain."
echo -e "  Log: ~/install.log\n"
