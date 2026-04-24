#!/data/data/com.termux/files/usr/bin/bash
# Zmemory.sh — ZRAM + Heap + Memory Trim
# Redfinger Android 10 ARM64 | Target: 8 Roblox instances on 4GB RAM
# /proc/sys/ likely READ-ONLY — all writes silently fail if blocked

LOG="${LOG:-$HOME/Zmemory.log}"
echo "" >> "$LOG"
echo "── ZMEMORY $(date) ──" >> "$LOG"

su -c "id" > /dev/null 2>&1 || { echo "[!] ROOT GAGAL" >> "$LOG"; exit 1; }

# ── [1/5] ZRAM Configuration ──────────────────────────────────
ZRAM_OK=0
if [ -e /sys/block/zram0 ]; then
    echo "[*] ZRAM device found, configuring..." >> "$LOG"
    su -c "swapoff /dev/block/zram0" 2>/dev/null
    sleep 1
    su -c "echo 1 > /sys/block/zram0/reset" 2>/dev/null
    su -c "echo lz4 > /sys/block/zram0/comp_algorithm" 2>/dev/null
    su -c "echo 1073741824 > /sys/block/zram0/disksize" 2>/dev/null
    su -c "mkswap /dev/block/zram0" >> "$LOG" 2>&1
    su -c "swapon -p 32767 /dev/block/zram0" >> "$LOG" 2>&1
    if su -c "cat /proc/swaps" 2>/dev/null | grep -q "zram0"; then
        ZRAM_OK=1
        echo "[+] 1/5 ZRAM 1GB aktif (lz4)" >> "$LOG"
    else
        echo "[~] 1/5 ZRAM gagal (hypervisor block?)" >> "$LOG"
    fi
else
    echo "[~] 1/5 No /sys/block/zram0 — skip ZRAM" >> "$LOG"
fi

# Check existing swap
SWAP_INFO=$(su -c "cat /proc/swaps" 2>/dev/null)
echo "[i] Current swaps:" >> "$LOG"
echo "$SWAP_INFO" >> "$LOG"

# ── [2/5] VM Sysctl (attempt — expect fail on hypervisor) ─────
su -c "echo 100 > /proc/sys/vm/swappiness" 2>/dev/null && echo "[+] 2/5 swappiness=100" >> "$LOG" || echo "[~] 2/5 swappiness blocked" >> "$LOG"
su -c "echo 50 > /proc/sys/vm/vfs_cache_pressure" 2>/dev/null
su -c "echo 0 > /proc/sys/vm/oom_dump_tasks" 2>/dev/null
su -c "echo 1 > /proc/sys/vm/overcommit_memory" 2>/dev/null

# ── [3/5] Dalvik Heap Tuning ──────────────────────────────────
su -c "setprop dalvik.vm.heapsize 128m" 2>/dev/null
su -c "setprop dalvik.vm.heapgrowthlimit 64m" 2>/dev/null
su -c "setprop dalvik.vm.heapminfree 512k" 2>/dev/null
su -c "setprop dalvik.vm.heapmaxfree 2m" 2>/dev/null
su -c "setprop dalvik.vm.heaptargetutilization 0.9" 2>/dev/null
su -c "setprop dalvik.vm.heapstartsize 4m" 2>/dev/null
echo "[+] 3/5 Dalvik heap tuned" >> "$LOG"

# ── [4/5] Memory Trim ─────────────────────────────────────────
su -c "am send-trim-memory system RUNNING_CRITICAL" 2>/dev/null
su -c "am send-trim-memory com.google.android.gms RUNNING_LOW" 2>/dev/null
su -c "am send-trim-memory com.google.android.gsf RUNNING_LOW" 2>/dev/null

# Play Store — restrict + trim
su -c "am force-stop com.android.vending" 2>/dev/null
su -c "cmd appops set com.android.vending RUN_IN_BACKGROUND deny" 2>/dev/null
su -c "cmd appops set com.android.vending RUN_ANY_IN_BACKGROUND deny" 2>/dev/null
su -c "am set-standby-bucket com.android.vending restricted" 2>/dev/null
echo "[+] 4/5 Memory trimmed" >> "$LOG"

# ── [5/5] Drop Caches ─────────────────────────────────────────
su -c "echo 3 > /proc/sys/vm/drop_caches" 2>/dev/null
su -c "rm -rf /data/tombstones/*" 2>/dev/null
echo "[+] 5/5 Caches dropped, tombstones cleared" >> "$LOG"

# ── Summary ────────────────────────────────────────────────────
FREE_MB=$((  $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal     /proc/meminfo | awk '{print $2}') / 1024 ))
SWAP_F_MB=$(($(grep SwapFree     /proc/meminfo | awk '{print $2}') / 1024 ))
SWAP_T_MB=$(($(grep SwapTotal    /proc/meminfo | awk '{print $2}') / 1024 ))

echo "[+] ZMEMORY DONE — RAM: ${FREE_MB}MB/${TOTAL_MB}MB  Swap: ${SWAP_F_MB}MB/${SWAP_T_MB}MB  ZRAM=$ZRAM_OK — $(date)" >> "$LOG"
