#!/data/data/com.termux/files/usr/bin/bash
# Zboot.sh — Auto-optimization on boot
# Place in ~/.termux/boot/ — executes AFTER winterhub_agent.sh (alphabetical)
# Does NOT edit winterhub_agent.sh — runs independently

LOG="$HOME/Zboot.log"
BASE_URL="https://raw.githubusercontent.com/Fluxyyy333/redfinger-wintercode/main"
CONFIG="$HOME/.rf_config"
MIGRATION_FLAG="$HOME/.rf_migration_done"

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG"; }

# Log rotation: keep last 500 lines
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 2000 ]; then
    tail -500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

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

# One-time migration: re-enable packages that old debloat_rf.sh pm-disabled.
# Gated by flag file so it only runs once, not every boot.
if [ ! -f "$MIGRATION_FLAG" ]; then
    log "[boot] Running one-time pm-enable migration..."
    REENABLE_PKGS="com.android.launcher3 com.android.phone com.android.server.telecom com.android.dialer com.android.bluetooth com.android.settings com.android.documentsui com.android.contacts com.android.providers.downloads com.android.providers.contacts com.android.providers.telephony com.android.providers.calendar com.android.providers.media com.google.android.setupwizard com.google.android.gsf.login com.android.camera2 com.android.nfc com.android.usb com.android.storagemanager com.android.keychain com.android.se com.android.chrome com.android.email com.android.calendar com.android.messaging com.android.inputmethod.latin com.google.android.inputmethod.latin com.android.quicksearchbox com.android.gallery3d com.android.music com.android.soundrecorder com.android.printspooler com.android.bips com.android.bookmarkprovider com.android.certinstaller com.android.managedprovisioning com.android.onetimeinitializer com.android.traceur com.android.egg com.android.htmlviewer com.android.pacprocessor com.android.mtp com.android.dreams.basic com.android.dreams.phototable com.android.wallpaper.livepicker com.android.wallpaperbackup com.android.wallpapercropper com.android.wallpaperpicker com.android.musicfx com.android.deskclock com.android.emergency com.android.calllogbackup com.android.simappdialog com.android.carrierconfig com.android.carrierdefaultapp com.android.cellbroadcastreceiver com.android.smspush com.android.ons com.android.mms.service com.android.hotspot2 com.android.bluetoothmidiservice com.android.printservice.recommendation com.android.providers.userdictionary com.android.providers.blockednumber com.android.providers.downloads.ui com.android.providers.partnerbookmarks com.android.companiondevicemanager com.android.vpndialogs com.android.stk com.android.backupconfirm com.android.sharedstoragebackup com.android.dynsystem com.android.cts.priv.ctsshim com.android.cts.ctsshim com.android.nfc.helper com.android.camera com.android.location.fused com.baidu.cloud.service com.wsh.appstore com.wshl.file.observerservice com.google.android.play.games com.google.android.tts com.google.android.feedback com.google.android.apps.restore com.google.android.configupdater com.google.android.partnersetup com.google.android.backuptransport com.google.android.apps.nbu.files com.google.android.ext.shared com.google.android.printservice.recommendation com.android.plugin com.android.datatransport"
    for pkg in $REENABLE_PKGS; do
        su -c "pm enable $pkg" 2>/dev/null
    done
    touch "$MIGRATION_FLAG"
    log "[boot] migration complete — flag set, won't run again"
else
    log "[boot] migration already done, skipping"
fi

# Delta HWID spoof (android_id + serial) — runs before any app launch
# Safe config parsing — NO eval, grep + cut only
DELTA_SERIAL=""
if [ -f "$CONFIG" ]; then
    DELTA_SERIAL=$(grep '^DELTA_SERIAL=' "$CONFIG" | head -1 | cut -d'=' -f2 | tr -d '[:space:]')
fi

if [ -z "$DELTA_SERIAL" ]; then
    log "[hwid] FATAL: no DELTA_SERIAL in $CONFIG — REFUSING to boot with wrong HWID"
    log "[hwid] Run install.sh with correct serial first. Skipping Roblox launch."
else
    su -c "settings put secure android_id $DELTA_SERIAL" 2>/dev/null
    log "[hwid] android_id set: $DELTA_SERIAL"

    RESETPROP="/data/local/tmp/resetprop"
    if [ -x "$RESETPROP" ]; then
        su -c "$RESETPROP ro.serialno $DELTA_SERIAL" 2>/dev/null
        su -c "$RESETPROP ro.boot.serialno $DELTA_SERIAL" 2>/dev/null
        log "[hwid] resetprop applied: $DELTA_SERIAL"
    else
        SPOOFER_PKG="com.stealth.vault"
        APK_LINE=$(su -c "pm path $SPOOFER_PKG" 2>/dev/null)
        if [ -n "$APK_LINE" ]; then
            APK_DIR=$(dirname "${APK_LINE#package:}")
            LIB=$(su -c "find \"$APK_DIR\" -name 'libresetprop.so' 2>/dev/null" | head -1)
            if [ -n "$LIB" ]; then
                su -c "cp \"$LIB\" \"$RESETPROP\" && chmod 755 \"$RESETPROP\""
                su -c "$RESETPROP ro.serialno $DELTA_SERIAL" 2>/dev/null
                su -c "$RESETPROP ro.boot.serialno $DELTA_SERIAL" 2>/dev/null
                log "[hwid] resetprop re-extracted + applied"
            else
                log "[hwid] WARN: libresetprop.so not found in spoofer APK"
            fi
        else
            log "[hwid] WARN: spoofer APK not installed — skip resetprop"
        fi
    fi

    # Verify HWID values match intended target
    ACTUAL_AID=$(su -c 'settings get secure android_id' 2>/dev/null)
    ACTUAL_SER=$(su -c 'getprop ro.serialno' 2>/dev/null)
    if [ "$ACTUAL_AID" = "$DELTA_SERIAL" ] && [ "$ACTUAL_SER" = "$DELTA_SERIAL" ]; then
        log "[hwid] VERIFIED OK: android_id=$ACTUAL_AID serial=$ACTUAL_SER"
    else
        log "[hwid] MISMATCH! expected=$DELTA_SERIAL got aid=$ACTUAL_AID ser=$ACTUAL_SER"
    fi
fi

# Staggered download: random 0-30s delay to avoid GitHub rate limit on 300+ devices
RAND_DELAY=$(( RANDOM % 30 ))
log "[boot] stagger delay: ${RAND_DELAY}s"
sleep $RAND_DELAY

# Download latest optimization scripts
mkdir -p "$HOME/scripts"
for f in Zdebloat.sh Zoptimize.sh Zmemory.sh Zdeep.sh Zwatchdog.sh; do
    curl -sL --max-time 15 "$BASE_URL/scripts/$f" -o "$HOME/scripts/$f.tmp" 2>/dev/null
    if [ -s "$HOME/scripts/$f.tmp" ]; then
        # Validate: must start with shebang (not HTML error page)
        if head -1 "$HOME/scripts/$f.tmp" | grep -q '^#!'; then
            mv "$HOME/scripts/$f.tmp" "$HOME/scripts/$f"
            chmod +x "$HOME/scripts/$f"
        else
            rm -f "$HOME/scripts/$f.tmp"
            log "[boot] download corrupt: $f (not a shell script, using cached)"
        fi
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
sleep 2
nohup bash "$HOME/scripts/Zwatchdog.sh" >> "$HOME/Zwatchdog.log" 2>&1 &
WD_PID=$!
echo "$WD_PID" > "$HOME/.watchdog.pid"
log "[boot] watchdog started PID=$WD_PID"

# Setup crontab: watchdog self-heal + boot fallback
CRON_WD='* * * * * pgrep -f Zwatchdog.sh >/dev/null || nohup bash $HOME/scripts/Zwatchdog.sh >> $HOME/Zwatchdog.log 2>&1 &'
CRON_BOOT='@reboot sleep 30 && bash $HOME/.termux/boot/Zboot.sh'
( crontab -l 2>/dev/null | grep -v 'Zwatchdog.sh' | grep -v 'Zboot.sh'; echo "$CRON_WD"; echo "$CRON_BOOT" ) | crontab - 2>/dev/null
log "[boot] crontab installed (watchdog self-heal + boot fallback)"

FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))

# Start hopper (auto-start on boot)
pkill -f "lua.*hopper.lua" 2>/dev/null
sleep 2
if [ -f "$HOME/hopper.lua" ]; then
    nohup lua "$HOME/hopper.lua" >> "$HOME/hopper_daemon.log" 2>&1 &
    log "[boot] hopper started PID=$!"
else
    log "[boot] hopper.lua not found"
fi

log "[boot] Zboot complete — RAM: ${FREE_MB}MB / ${TOTAL_MB}MB"
echo "══════════════════════════════" >> "$LOG"
