#!/data/data/com.termux/files/usr/bin/bash
# Zboot.sh — Auto-optimization on boot
# Place in ~/.termux/boot/ — executes AFTER winterhub_agent.sh (alphabetical)
# Does NOT edit winterhub_agent.sh — runs independently

LOG="$HOME/Zboot.log"
BASE_URL="https://raw.githubusercontent.com/Fluxyyy333/redfinger-wintercode/main"

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG"; }

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

# Re-enable packages that old Zdebloat.sh may have pm-disabled.
# This is a one-time migration — new Zdebloat.sh uses force-stop only.
REENABLE_PKGS="com.android.launcher3 com.android.phone com.android.server.telecom com.android.dialer com.android.bluetooth com.android.settings com.android.documentsui com.android.contacts com.android.providers.downloads com.android.providers.contacts com.android.providers.telephony com.android.providers.calendar com.android.providers.media com.google.android.setupwizard com.google.android.gsf.login com.android.camera2 com.android.nfc com.android.usb com.android.storagemanager com.android.keychain com.android.se com.android.chrome com.android.email com.android.calendar com.android.messaging com.android.inputmethod.latin com.google.android.inputmethod.latin com.android.quicksearchbox com.android.gallery3d com.android.music com.android.soundrecorder com.android.printspooler com.android.bips com.android.bookmarkprovider com.android.certinstaller com.android.managedprovisioning com.android.onetimeinitializer com.android.traceur com.android.egg com.android.htmlviewer com.android.pacprocessor com.android.mtp com.android.dreams.basic com.android.dreams.phototable com.android.wallpaper.livepicker com.android.wallpaperbackup com.android.wallpapercropper com.android.wallpaperpicker com.android.musicfx com.android.deskclock com.android.emergency com.android.calllogbackup com.android.simappdialog com.android.carrierconfig com.android.carrierdefaultapp com.android.cellbroadcastreceiver com.android.smspush com.android.ons com.android.mms.service com.android.hotspot2 com.android.bluetoothmidiservice com.android.printservice.recommendation com.android.providers.userdictionary com.android.providers.blockednumber com.android.providers.downloads.ui com.android.providers.partnerbookmarks com.android.companiondevicemanager com.android.vpndialogs com.android.stk com.android.backupconfirm com.android.sharedstoragebackup com.android.dynsystem com.android.cts.priv.ctsshim com.android.cts.ctsshim com.android.nfc.helper com.android.camera com.android.location.fused com.baidu.cloud.service com.wsh.appstore com.wshl.file.observerservice com.google.android.play.games com.google.android.tts com.google.android.feedback com.google.android.apps.restore com.google.android.configupdater com.google.android.partnersetup com.google.android.backuptransport com.google.android.apps.nbu.files com.google.android.ext.shared com.google.android.printservice.recommendation com.android.plugin com.android.datatransport"
for pkg in $REENABLE_PKGS; do
    su -c "pm enable $pkg" 2>/dev/null
done
log "[boot] re-enabled all previously disabled packages (migration)"

# Download latest optimization scripts
mkdir -p "$HOME/scripts"
for f in Zdebloat.sh Zoptimize.sh Zmemory.sh Zdeep.sh Zwatchdog.sh; do
    curl -sL --max-time 15 "$BASE_URL/scripts/$f" -o "$HOME/scripts/$f.tmp" 2>/dev/null
    if [ -s "$HOME/scripts/$f.tmp" ]; then
        mv "$HOME/scripts/$f.tmp" "$HOME/scripts/$f"
        chmod +x "$HOME/scripts/$f"
        log "[boot] downloaded $f"
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
sleep 1
nohup bash "$HOME/scripts/Zwatchdog.sh" >> "$HOME/Zwatchdog.log" 2>&1 &
log "[boot] watchdog started PID=$!"

FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
TOTAL_MB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))

# Start hopper (auto-start on boot)
pkill -f "lua.*hopper.lua" 2>/dev/null
sleep 1
if [ -f "$HOME/hopper.lua" ]; then
    nohup lua "$HOME/hopper.lua" >> "$HOME/hopper_daemon.log" 2>&1 &
    log "[boot] hopper started PID=$!"
else
    log "[boot] hopper.lua not found"
fi

log "[boot] Zboot complete — RAM: ${FREE_MB}MB / ${TOTAL_MB}MB"
echo "══════════════════════════════" >> "$LOG"
