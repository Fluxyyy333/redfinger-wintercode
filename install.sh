#!/data/data/com.termux/files/usr/bin/bash
# INSTALL.sh — Redfinger Optimizer + Wintercode Agent
# Redfinger Android 10 ARM64 | Roblox Multi-Instance
# Uses boot-safe Z-scripts (force-stop only, NO pm disable-user)

CONFIG="$HOME/.rf_config"
LOG="$HOME/install.log"
BASE_URL="https://raw.githubusercontent.com/Fluxyyy333/redfinger-wintercode/main"
AGENT_URL="https://api.wintercode.dev/loader/agent-obfuscated.lua"
AGENT_PATH="/sdcard/Download/agent.lua"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
WINTERHUB_DIR="$HOME/.winterhub"

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

# ── [3/8] Install Paket ───────────────
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

if command -v lua > /dev/null 2>&1; then
  ok "lua OK: $(lua -v 2>&1 | head -1)"
else
  err "lua53 GAGAL setelah semua retry."
  exit 1
fi

# ── [4/8] Download Z-Scripts ──────────
echo -e "\n  ${W}[4/8] Download Z-Scripts${R}"
mkdir -p "$HOME/scripts" "$HOME/.termux/boot"

# Download boot-safe optimization scripts
for f in Zdebloat.sh Zoptimize.sh Zmemory.sh Zdeep.sh Zwatchdog.sh; do
  run "Download scripts/$f..."
  curl -fsSL --retry 3 "$BASE_URL/scripts/$f" -o "$HOME/scripts/$f" 2>> "$LOG"
  [ -s "$HOME/scripts/$f" ] && ok "$f" || err "GAGAL: $f"
done
chmod +x "$HOME/scripts/"*.sh

# Download Zboot.sh (boot chain orchestrator)
run "Download Zboot.sh..."
curl -fsSL --retry 3 "$BASE_URL/Zboot.sh" -o "$HOME/.termux/boot/Zboot.sh" 2>> "$LOG"
if [ -s "$HOME/.termux/boot/Zboot.sh" ]; then
  chmod +x "$HOME/.termux/boot/Zboot.sh"
  ok "Zboot.sh → ~/.termux/boot/"
else
  err "GAGAL: Zboot.sh"
fi

# Validate critical files
for _f in "$HOME/scripts/Zdebloat.sh" "$HOME/scripts/Zoptimize.sh" "$HOME/scripts/Zmemory.sh" "$HOME/scripts/Zdeep.sh" "$HOME/scripts/Zwatchdog.sh"; do
  [ -s "$_f" ] || { err "KRITIKAL: $_f tidak ada — abort."; exit 1; }
done
ok "Semua Z-scripts siap."

# ── [5/8] Debloat & Optimasi ──────────
echo -e "\n  ${W}[5/8] Debloat & Optimasi${R}"
run "Zdebloat.sh (force-stop only, boot-safe)..."
bash "$HOME/scripts/Zdebloat.sh" >> "$LOG" 2>&1
ok "Debloat selesai."
run "Zoptimize.sh..."
bash "$HOME/scripts/Zoptimize.sh" >> "$LOG" 2>&1
ok "Optimasi selesai."
run "Zmemory.sh..."
bash "$HOME/scripts/Zmemory.sh" >> "$LOG" 2>&1
ok "Memory tuning selesai."
run "Zdeep.sh..."
bash "$HOME/scripts/Zdeep.sh" >> "$LOG" 2>&1
ok "Deep optimize selesai."

# Start watchdog daemon
run "Start Zwatchdog.sh..."
pkill -f Zwatchdog.sh 2>/dev/null
sleep 1
nohup bash "$HOME/scripts/Zwatchdog.sh" >> "$HOME/Zwatchdog.log" 2>&1 &
ok "Watchdog started PID=$!"

# ── [6/8] Wintercode Agent ────────────
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

# ── [7/8] Boot Guard ─────────────────
echo -e "\n  ${W}[7/8] Boot Guard${R}"

run "Install winterhub_agent.sh..."
curl -fsSL --retry 3 "$BASE_URL/winterhub_agent.sh" -o "$HOME/.termux/boot/winterhub_agent.sh" 2>> "$LOG"
if [ -s "$HOME/.termux/boot/winterhub_agent.sh" ]; then
  sed -i "s/^SCRIPT_KEY=\"\"/SCRIPT_KEY=\"$SCRIPT_KEY\"/" "$HOME/.termux/boot/winterhub_agent.sh"
  chmod +x "$HOME/.termux/boot/winterhub_agent.sh"
  ok "winterhub_agent.sh terpasang di ~/.termux/boot/"
else
  err "Gagal download boot script."
fi
ok "Zboot.sh sudah terpasang di ~/.termux/boot/ (dari step 4)"

# ── [8/8] Cleanup old scripts ────────
echo -e "\n  ${W}[8/8] Cleanup${R}"
# Remove old dangerous scripts that use pm disable-user
for old in debloat_rf.sh optimize_rf.sh; do
  if [ -f "$HOME/scripts/$old" ]; then
    rm -f "$HOME/scripts/$old"
    ok "Removed old $old (used pm disable-user, unsafe)"
  fi
done

# ── Done ──────────────────────────────
FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal    /proc/meminfo | awk '{print $2}') / 1024 ))

echo -e "\n${G}  INSTALL SELESAI${R}"
echo "  ─────────────────────────────"
echo -e "  RAM   : ${W}${FREE_MB}MB${R} / ${TOTAL_MB}MB"
echo -e "  Agent : ${G}Wintercode${R}"
echo -e "  Boot  : ${G}winterhub_agent.sh + Zboot.sh${R}"
echo -e "  Optim : ${G}Zdebloat + Zoptimize + Zmemory + Zdeep${R}"
echo -e "  Daemon: ${G}Zwatchdog (60s cycle)${R}"
echo "  ─────────────────────────────"
echo "  Restart Redfinger untuk"
echo "  aktifkan boot chain."
echo -e "  Log: ~/install.log\n"
