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

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

find_lua() {
    for cmd in lua5.4 lua54 lua5.3 lua53 lua; do
        local p
        p=$(command -v "$cmd" 2>/dev/null) && [ -x "$p" ] && { echo "$p"; return 0; }
    done
    [ -x "$TERMUX_PREFIX/bin/lua" ] && { echo "$TERMUX_PREFIX/bin/lua"; return 0; }
    return 1
}

# ── Wait for boot + storage + network ──
sleep 15
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do sleep 3; done

TRIES=0
while [ ! -d "$INSTALL_DIR" ] && [ $TRIES -lt 30 ]; do sleep 2; TRIES=$((TRIES+1)); done
[ ! -d "$INSTALL_DIR" ] && { log "ERROR: $INSTALL_DIR not accessible"; exit 1; }

# Wait for network (ping Google DNS, max ~60s)
TRIES=0
while ! ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && [ $TRIES -lt 30 ]; do
    sleep 2
    TRIES=$((TRIES+1))
done

termux-wake-lock 2>/dev/null || true

# ── Ensure Lua exists (agent.lua handles the rest via bootstrap) ──
if ! find_lua > /dev/null 2>&1; then
    log "Installing Lua..."
    dpkg --configure -a --force-confdef --force-confold >> "$LOG" 2>&1 || true
    pkg install -y lua54 >> "$LOG" 2>&1 || \
    pkg install -y lua53 >> "$LOG" 2>&1 || { log "ERROR: Could not install Lua"; exit 1; }
fi

eval "$(luarocks path 2>/dev/null)" || true
LUA_BIN=$(find_lua) || { log "ERROR: Lua not found"; exit 1; }

# ── Download / Update agent ──
curl -sL -o "$AGENT_FILE.tmp" "$AGENT_URL" 2>/dev/null
if [ -s "$AGENT_FILE.tmp" ] && [ "$(wc -c < "$AGENT_FILE.tmp" | tr -d ' ')" -ge 1024 ]; then
    mv "$AGENT_FILE.tmp" "$AGENT_FILE"
    log "Agent updated ($(wc -c < "$AGENT_FILE" | tr -d ' ') bytes)"
else
    rm -f "$AGENT_FILE.tmp"
    [ ! -f "$AGENT_FILE" ] && { log "ERROR: Download failed, no agent.lua"; exit 1; }
    log "Update failed, using existing agent.lua"
fi

# ── Save script key ──
[ -n "$SCRIPT_KEY" ] && echo -n "$SCRIPT_KEY" > "$WINTERHUB_DIR/script_key"
export SCRIPT_KEY

# ── Launch agent ──
launch_agent() {
    eval "$(luarocks path 2>/dev/null)" || true
    local TOKEN
    TOKEN=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 32)
    echo -n "$TOKEN" > "$WINTERHUB_DIR/main.token"
    cd "$INSTALL_DIR"
    nohup "$LUA_BIN" "$AGENT_FILE" --main-loop --boot --token "$TOKEN" >> "$LOG" 2>&1 &
    echo $!
}

AGENT_PID=$(launch_agent)
sleep 5

# agent.lua exits 0 after first-boot module install — retry once
if ! kill -0 "$AGENT_PID" 2>/dev/null; then
    log "Re-launching after bootstrap..."
    AGENT_PID=$(launch_agent)
fi

# Escape from Termux cgroup
for f in /sys/fs/cgroup/uid_0/pid_*/cgroup.procs; do
    if echo $AGENT_PID > "$f" 2>/dev/null; then break; fi
done

log "Agent launched (pid $AGENT_PID)"
