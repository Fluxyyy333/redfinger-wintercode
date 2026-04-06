#!/data/data/com.termux/files/usr/bin/bash
#
# WinterHub Agent — Drop-in Boot Script
# Place in ~/.termux/boot/ and reboot.
#
# ── EDIT THIS ──
SCRIPT_KEY=""

AGENT_URL="https://api.wintercode.dev/loader/agent-obfuscated.lua"
INSTALL_DIR="/sdcard/Download"
AGENT_FILE="$INSTALL_DIR/agent.lua"
WINTERHUB_DIR="$HOME/.winterhub"
LOG="$WINTERHUB_DIR/agent.log"
BOOT_LOG="$WINTERHUB_DIR/agent_boot.log"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
BOOT_DIR="$HOME/.termux/boot"
EXPECTED_NAME="winterhub_agent.sh"

mkdir -p "$WINTERHUB_DIR" 2>/dev/null
mkdir -p "$BOOT_DIR" 2>/dev/null

# ── Self-rename to correct filename ──
SELF="$(realpath "$0" 2>/dev/null || echo "$0")"
SELF_NAME="$(basename "$SELF")"
if [ "$SELF_NAME" != "$EXPECTED_NAME" ] && [ -f "$SELF" ]; then
    cp "$SELF" "$BOOT_DIR/$EXPECTED_NAME"
    chmod +x "$BOOT_DIR/$EXPECTED_NAME"
    rm -f "$SELF"
    exec "$BOOT_DIR/$EXPECTED_NAME" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

{
echo ""
echo "══════════════════════════════"
echo "  BOOT — $(date)"
echo "══════════════════════════════"
} >> "$BOOT_LOG"
log() { echo "$(date '+%H:%M:%S') $1" >> "$BOOT_LOG" 2>/dev/null; }
log "[*] First-install boot script started"

find_lua() {
    for cmd in lua5.4 lua54 lua5.3 lua53 lua; do
        local p
        p=$(command -v "$cmd" 2>/dev/null) && [ -x "$p" ] && { echo "$p"; return 0; }
    done
    [ -x "$TERMUX_PREFIX/bin/lua" ] && { echo "$TERMUX_PREFIX/bin/lua"; return 0; }
    return 1
}

# ── Wait for boot + storage + network ──
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do sleep 3; done
log "[+] Boot complete"

TRIES=0
while [ ! -d "$INSTALL_DIR" ] && [ $TRIES -lt 30 ]; do sleep 2; TRIES=$((TRIES+1)); done
[ ! -d "$INSTALL_DIR" ] && { log "[!!!] $INSTALL_DIR not accessible"; exit 1; }

while ! su -c "id" >/dev/null 2>&1; do sleep 2; done
log "[+] Root ready"

TRIES=0
while ! ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && [ $TRIES -lt 30 ]; do
    sleep 2
    TRIES=$((TRIES+1))
done
log "[+] Network ready"

termux-wake-lock 2>/dev/null || true

# ── Ensure Lua exists (can't run agent.lua without it) ──
if ! find_lua > /dev/null 2>&1; then
    log "[*] Installing Lua..."
    dpkg --configure -a --force-confdef --force-confold >> "$LOG" 2>&1 || true
    pkg install -y lua54 >> "$LOG" 2>&1 || \
    pkg install -y lua53 >> "$LOG" 2>&1 || { log "[!!!] Could not install Lua"; exit 1; }
    log "[+] Lua installed"
fi

eval "$(luarocks path 2>/dev/null)" || true
LUA_BIN=$(find_lua) || { log "[!!!] Lua not found"; exit 1; }
log "[+] Lua: $LUA_BIN"

# ── Download / Update agent ──
curl -sL --max-time 30 --connect-timeout 10 -o "$AGENT_FILE.tmp" "$AGENT_URL" 2>/dev/null
if [ -s "$AGENT_FILE.tmp" ] && [ "$(wc -c < "$AGENT_FILE.tmp" | tr -d ' ')" -ge 300000 ]; then
    mv "$AGENT_FILE.tmp" "$AGENT_FILE"
    log "[+] Agent downloaded ($(wc -c < "$AGENT_FILE" | tr -d ' ') bytes)"
else
    rm -f "$AGENT_FILE.tmp"
    [ ! -f "$AGENT_FILE" ] && { log "[!!!] Download failed, no agent.lua"; exit 1; }
    log "[~] Download failed, using existing agent.lua"
fi

# ── Save script key ──
[ -n "$SCRIPT_KEY" ] && echo -n "$SCRIPT_KEY" > "$WINTERHUB_DIR/script_key"
export SCRIPT_KEY

# ── Launch agent (handles su, setsid, cgroup, OOM, watchdog, everything) ──
rm -f "$WINTERHUB_DIR/main.pid" 2>/dev/null
cd "$INSTALL_DIR"
"$LUA_BIN" "$AGENT_FILE" > /dev/null 2>&1 &

# Wait for agent to write PID file (max 30s)
PWAIT=0
while [ ! -s "$WINTERHUB_DIR/main.pid" ] && [ $PWAIT -lt 15 ]; do
    sleep 2; PWAIT=$((PWAIT+1))
done
PID=$(cat "$WINTERHUB_DIR/main.pid" 2>/dev/null)
if [ -n "$PID" ] && su -c "kill -0 $PID" 2>/dev/null; then
    log "[+] Agent running (PID $PID)"
else
    log "[!] Agent not detected after 30s — may still be starting"
fi
log "[+] Boot done"
echo "══════════════════════════════" >> "$BOOT_LOG"
