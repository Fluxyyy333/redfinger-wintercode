#!/data/data/com.termux/files/usr/bin/bash
# INSTALL.sh — Redfinger Optimizer + Wintercode Agent
# Redfinger Android 10 ARM64 | Roblox Multi-Instance

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

  # Clear cached apt lists — tanpa ini apt masih pakai metadata rusak
  rm -rf "$APT_LISTS"/* 2>/dev/null

  # Tulis mirror baru ke sources.list
  echo "deb $mirror stable main" > "$APT_DIR/sources.list"

  # Update sources.list.d/ jika ada (repo tambahan)
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

# ── [3/8] Packages ────────────────────
echo -e "\n  ${W}[3/8] Install Paket${R}"
# Force switch mirror jika default mirror broken (redirect/expired)
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

# Verify lua
if command -v lua > /dev/null 2>&1; then
  ok "lua OK: $(lua -v 2>&1 | head -1)"
else
  err "lua53 GAGAL setelah semua retry."
  exit 1
fi

# ── [4/7] Download Scripts ────────────
echo -e "\n  ${W}[4/7] Download Scripts${R}"
mkdir -p "$HOME/scripts" "$HOME/.termux/boot"
for f in scripts/optimize_rf.sh scripts/debloat_rf.sh scripts/oom_watcher.sh; do
  run "Download $f..."
  curl -fsSL --retry 3 "$BASE_URL/$f" -o "$HOME/$f" 2>> "$LOG"
  [ -s "$HOME/$f" ] && ok "$f" || err "GAGAL: $f"
done
chmod +x "$HOME/scripts/"*.sh
# Hapus autorun.sh lama dari boot dir (diganti winterhub_agent.sh)
rm -f "$HOME/.termux/boot/autorun.sh" 2>/dev/null
# Validasi file kritikal sebelum lanjut
for _f in "$HOME/scripts/optimize_rf.sh" "$HOME/scripts/oom_watcher.sh"; do
  [ -s "$_f" ] || { err "KRITIKAL: $_f tidak ada — abort."; exit 1; }
done
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

# Wake-lock — cegah Android suspend Termux
termux-wake-lock 2>/dev/null || true
ok "Wake-lock aktif."

# Lua detection (multi-version, sesuai developer agent)
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

# Download agent dengan validasi ukuran (min 1024 bytes)
run "Download agent.lua..."
curl -sL -o "$AGENT_PATH.tmp" "$AGENT_URL" 2>> "$LOG"
if [ -s "$AGENT_PATH.tmp" ] && [ "$(wc -c < "$AGENT_PATH.tmp" | tr -d ' ')" -ge 1024 ]; then
  mv "$AGENT_PATH.tmp" "$AGENT_PATH"
  ok "agent.lua downloaded ($(wc -c < "$AGENT_PATH" | tr -d ' ') bytes)"
else
  rm -f "$AGENT_PATH.tmp"
  [ ! -f "$AGENT_PATH" ] && { err "Download agent gagal, tidak ada agent.lua."; exit 1; }
  err "Download gagal, pakai agent.lua yang sudah ada."
fi

# Inject key
run "Inject script key..."
mkdir -p "$WINTERHUB_DIR"
printf '%s' "$SCRIPT_KEY" > "$WINTERHUB_DIR/script_key"
export SCRIPT_KEY
ok "Key tersimpan di ~/.winterhub/script_key"

# Launch agent (background + nohup + proper flags)
launch_agent() {
  eval "$(luarocks path 2>/dev/null)" || true
  local TOKEN
  TOKEN=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 32)
  echo -n "$TOKEN" > "$WINTERHUB_DIR/main.token"
  cd "$(dirname "$AGENT_PATH")"
  nohup "$LUA_BIN" "$AGENT_PATH" --main-loop --boot --token "$TOKEN" >> "$LOG" 2>&1 &
  echo $!
}

run "Launch agent..."
AGENT_PID=$(launch_agent)
sleep 5

# Agent exits 0 setelah first-boot module install — re-launch otomatis
if ! kill -0 "$AGENT_PID" 2>/dev/null; then
  run "Re-launch setelah bootstrap modules..."
  AGENT_PID=$(launch_agent)
  sleep 3
fi

# Cgroup escape — krusial di Redfinger agar agent tidak di-kill Android
for f in /sys/fs/cgroup/uid_0/pid_*/cgroup.procs; do
  if echo "$AGENT_PID" > "$f" 2>/dev/null; then break; fi
done

if kill -0 "$AGENT_PID" 2>/dev/null; then
  ok "Agent running (PID: $AGENT_PID)"
else
  err "Agent tidak jalan. Cek ~/install.log"
fi
[ -d "$WINTERHUB_DIR" ] && ok "Agent config OK." || err "Config belum ada."

# ── [7/7] Boot Guard ─────────────────
echo -e "\n  ${W}[7/7] Boot Guard${R}"

# Install winterhub_agent.sh sebagai boot script (dari developer)
run "Install boot script..."
curl -fsSL --retry 3 "$BASE_URL/winterhub_agent.sh" -o "$HOME/.termux/boot/winterhub_agent.sh" 2>> "$LOG"
if [ -s "$HOME/.termux/boot/winterhub_agent.sh" ]; then
  # Inject SCRIPT_KEY ke boot script
  sed -i "s/^SCRIPT_KEY=\"\"/SCRIPT_KEY=\"$SCRIPT_KEY\"/" "$HOME/.termux/boot/winterhub_agent.sh"
  chmod +x "$HOME/.termux/boot/winterhub_agent.sh"
  ok "winterhub_agent.sh terpasang di ~/.termux/boot/"
else
  err "Gagal download boot script."
fi

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
if [ -f "$HOME/.termux/boot/winterhub_agent.sh" ]; then
  if ! pgrep -f "lua.*agent" > /dev/null 2>&1; then
    echo "[.bashrc] Agent belum jalan — trigger boot script..."
    nohup bash "$HOME/.termux/boot/winterhub_agent.sh" > /dev/null 2>&1 &
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
echo "  aktifkan boot agent."
echo -e "  Log: ~/install.log\n"
