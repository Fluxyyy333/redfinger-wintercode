#!/data/data/com.termux/files/usr/bin/bash
# Zboot.sh — Boot chain orchestrator
# Place in ~/.termux/boot/ — runs AFTER winterhub_agent.sh (alphabetical)

LOG="$HOME/Zboot.log"
BASE_URL="https://raw.githubusercontent.com/Fluxyyy333/redfinger-wintercode/main"
CONFIG="$HOME/.rf_config"
MIGRATION_FLAG="$HOME/.rf_migration_done"

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG"; }

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

# One-time migration: re-enable packages that old debloat_rf.sh pm-disabled
if [ ! -f "$MIGRATION_FLAG" ]; then
    log "[boot] Running one-time pm-enable migration..."
    REENABLE_PKGS="com.android.launcher3 com.android.phone com.android.server.telecom com.android.dialer com.android.bluetooth com.android.settings com.android.documentsui com.android.contacts com.android.providers.downloads com.android.providers.contacts com.android.providers.telephony com.android.providers.calendar com.android.providers.media com.google.android.setupwizard com.google.android.gsf.login com.android.camera2 com.android.nfc com.android.usb com.android.storagemanager com.android.keychain com.android.se com.android.chrome com.android.email com.android.calendar com.android.messaging com.android.inputmethod.latin com.google.android.inputmethod.latin com.android.quicksearchbox com.android.gallery3d com.android.music com.android.soundrecorder com.android.printspooler com.android.bips com.android.bookmarkprovider com.android.certinstaller com.android.managedprovisioning com.android.onetimeinitializer com.android.traceur com.android.egg com.android.htmlviewer com.android.pacprocessor com.android.mtp com.android.dreams.basic com.android.dreams.phototable com.android.wallpaper.livepicker com.android.wallpaperbackup com.android.wallpapercropper com.android.wallpaperpicker com.android.musicfx com.android.deskclock com.android.emergency com.android.calllogbackup com.android.simappdialog com.android.carrierconfig com.android.carrierdefaultapp com.android.cellbroadcastreceiver com.android.smspush com.android.ons com.android.mms.service com.android.hotspot2 com.android.bluetoothmidiservice com.android.printservice.recommendation com.android.providers.userdictionary com.android.providers.blockednumber com.android.providers.downloads.ui com.android.providers.partnerbookmarks com.android.companiondevicemanager com.android.vpndialogs com.android.stk com.android.backupconfirm com.android.sharedstoragebackup com.android.dynsystem com.android.cts.priv.ctsshim com.android.cts.ctsshim com.android.nfc.helper com.android.camera com.android.location.fused com.baidu.cloud.service com.wsh.appstore com.wshl.file.observerservice com.google.android.play.games com.google.android.tts com.google.android.feedback com.google.android.apps.restore com.google.android.configupdater com.google.android.partnersetup com.google.android.backuptransport com.google.android.apps.nbu.files com.google.android.ext.shared com.google.android.printservice.recommendation com.android.plugin com.android.datatransport"
    for pkg in $REENABLE_PKGS; do
        su -c "pm enable $pkg" 2>/dev/null
    done
    touch "$MIGRATION_FLAG"
    log "[boot] migration complete"
else
    log "[boot] migration already done"
fi

# ── HWID Spoof ────────────────────────────────────────────────
# Format: DELTA_SERIAL="android_id:serial" (colon-separated)
DELTA_SERIAL="0d53eeeecba69355:00918b9b"
if [ -f "$CONFIG" ]; then
    CFG_SERIAL=$(grep '^DELTA_SERIAL=' "$CONFIG" | head -1 | cut -d'=' -f2- | tr -d '[:space:]')
    [ -n "$CFG_SERIAL" ] && DELTA_SERIAL="$CFG_SERIAL"
fi

# Split android_id and serial
if echo "$DELTA_SERIAL" | grep -q ':'; then
    AID_TARGET="${DELTA_SERIAL%%:*}"
    SER_TARGET="${DELTA_SERIAL##*:}"
else
    AID_TARGET="$DELTA_SERIAL"
    SER_TARGET="$DELTA_SERIAL"
fi

su -c "settings put secure android_id $AID_TARGET" 2>/dev/null
log "[hwid] android_id set: $AID_TARGET"

RESETPROP="/data/local/tmp/resetprop"
if [ -x "$RESETPROP" ]; then
    su -c "$RESETPROP ro.serialno $SER_TARGET" 2>/dev/null
    su -c "$RESETPROP ro.boot.serialno $SER_TARGET" 2>/dev/null
    log "[hwid] resetprop applied: serial=$SER_TARGET"
else
    SPOOFER_PKG="com.stealth.vault"
    APK_LINE=$(su -c "pm path $SPOOFER_PKG" 2>/dev/null)
    if [ -n "$APK_LINE" ]; then
        APK_DIR=$(dirname "${APK_LINE#package:}")
        LIB=$(su -c "find \"$APK_DIR\" -name 'libresetprop.so' 2>/dev/null" | head -1)
        if [ -n "$LIB" ]; then
            su -c "cp \"$LIB\" \"$RESETPROP\" && chmod 755 \"$RESETPROP\""
            su -c "$RESETPROP ro.serialno $SER_TARGET" 2>/dev/null
            su -c "$RESETPROP ro.boot.serialno $SER_TARGET" 2>/dev/null
            log "[hwid] resetprop re-extracted + applied: serial=$SER_TARGET"
        fi
    fi
fi

ACTUAL_AID=$(su -c 'settings get secure android_id' 2>/dev/null)
ACTUAL_SER=$(su -c 'getprop ro.serialno' 2>/dev/null)
if [ "$ACTUAL_AID" = "$AID_TARGET" ] && [ "$ACTUAL_SER" = "$SER_TARGET" ]; then
    log "[hwid] VERIFIED OK: aid=$ACTUAL_AID ser=$ACTUAL_SER"
else
    log "[hwid] MISMATCH! expected aid=$AID_TARGET ser=$SER_TARGET got aid=$ACTUAL_AID ser=$ACTUAL_SER"
fi

# ── Download Latest Scripts ───────────────────────────────────
RAND_DELAY=$(( RANDOM % 30 ))
log "[boot] stagger delay: ${RAND_DELAY}s"
sleep $RAND_DELAY

mkdir -p "$HOME/scripts"
for f in Zoptimize.sh Zwatchdog.sh delta_setup.sh; do
    curl -sL --max-time 15 "$BASE_URL/scripts/$f" -o "$HOME/scripts/$f.tmp" 2>/dev/null
    if [ -s "$HOME/scripts/$f.tmp" ] && head -1 "$HOME/scripts/$f.tmp" | grep -q '^#!'; then
        mv "$HOME/scripts/$f.tmp" "$HOME/scripts/$f"
        chmod +x "$HOME/scripts/$f"
    else
        rm -f "$HOME/scripts/$f.tmp"
        log "[boot] download failed: $f (using cached)"
    fi
done

# ── Cleanup legacy scripts on device ─────────────────────────
for old in Zdebloat.sh Zmemory.sh Zdeep.sh debloat_rf.sh optimize_rf.sh; do
    [ -f "$HOME/scripts/$old" ] && rm -f "$HOME/scripts/$old" && log "[boot] removed legacy $old"
done

# ── Run Optimization ─────────────────────────────────────────
bash "$HOME/scripts/Zoptimize.sh" >> "$LOG" 2>&1
log "[boot] optimize done"

# ── Start Watchdog ────────────────────────────────────────────
pkill -f Zwatchdog.sh 2>/dev/null
sleep 2
nohup bash "$HOME/scripts/Zwatchdog.sh" >> "$HOME/Zwatchdog.log" 2>&1 &
WD_PID=$!
echo "$WD_PID" > "$HOME/.watchdog.pid"
log "[boot] watchdog started PID=$WD_PID"

# ── Crontab: watchdog self-heal + boot fallback ──────────────
CRON_WD='* * * * * pgrep -f Zwatchdog.sh >/dev/null || nohup bash $HOME/scripts/Zwatchdog.sh >> $HOME/Zwatchdog.log 2>&1 &'
CRON_BOOT='@reboot sleep 30 && bash $HOME/.termux/boot/Zboot.sh'
( crontab -l 2>/dev/null | grep -v 'Zwatchdog.sh' | grep -v 'Zboot.sh'; echo "$CRON_WD"; echo "$CRON_BOOT" ) | crontab - 2>/dev/null
log "[boot] crontab installed"

FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
log "[boot] Zboot complete — RAM: ${FREE_MB}MB / ${TOTAL_MB}MB"
echo "══════════════════════════════" >> "$LOG"
