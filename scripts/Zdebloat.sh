#!/data/data/com.termux/files/usr/bin/bash
# Zdebloat.sh — Ultra-Aggressive Debloat for Headless Roblox Farming
# Redfinger Android 10 ARM64 | Target: 8 Roblox instances on 4GB RAM
# Device fully agent-controlled — NO human interaction needed
# Safe to re-run (idempotent)

LOG="${LOG:-$HOME/Zdebloat.log}"
echo "=== ZDEBLOAT: $(date) ===" >> "$LOG"

dis() { su -c "pm disable-user --user 0 $1 >> $LOG 2>&1 && am force-stop $1 2>/dev/null"; }
uni() { su -c "pm uninstall -k --user 0 $1 >> $LOG 2>&1 && am force-stop $1 2>/dev/null"; }

su -c "id" > /dev/null 2>&1 || { echo "[!] ROOT GAGAL" >> "$LOG"; exit 1; }

# ── BLOK 1: PHONE / SIM ──────────────────────────────────────
dis "com.android.phone"
dis "com.android.server.telecom"
dis "com.android.dialer"
dis "com.android.calllogbackup"
dis "com.android.simappdialog"
dis "com.android.carrierconfig"
dis "com.android.carrierdefaultapp"
dis "com.android.cellbroadcastreceiver"
dis "com.android.smspush"
dis "com.android.ons"
dis "com.android.mms.service"
dis "com.android.hotspot2"
echo "[+] Blok 1: Phone/SIM" >> "$LOG"

# ── BLOK 2: GOOGLE APPS ──────────────────────────────────────
dis "com.google.android.gsf.login"
dis "com.google.android.inputmethod.latin"
dis "com.google.android.play.games"
dis "com.google.android.tts"
dis "com.google.android.feedback"
dis "com.google.android.apps.restore"
dis "com.google.android.configupdater"
dis "com.google.android.partnersetup"
dis "com.google.android.setupwizard"
dis "com.google.android.backuptransport"
dis "com.google.android.apps.nbu.files"
dis "com.google.android.ext.shared"
dis "com.google.android.printservice.recommendation"
echo "[+] Blok 2: Google Apps" >> "$LOG"

# ── BLOK 3: ANDROID SYSTEM BLOAT ─────────────────────────────
dis "com.android.bluetooth"
dis "com.android.bluetoothmidiservice"
dis "com.android.chrome"
dis "com.android.email"
dis "com.android.calendar"
dis "com.android.messaging"
dis "com.android.contacts"
dis "com.android.deskclock"
dis "com.android.emergency"
dis "com.android.gallery3d"
dis "com.android.music"
dis "com.android.musicfx"
dis "com.android.soundrecorder"
dis "com.android.dreams.basic"
dis "com.android.dreams.phototable"
dis "com.android.mtp"
dis "com.android.se"
dis "com.android.printspooler"
dis "com.android.printservice.recommendation"
dis "com.android.bips"
dis "com.android.bookmarkprovider"
dis "com.android.quicksearchbox"
dis "com.android.inputmethod.latin"
dis "com.android.onetimeinitializer"
dis "com.android.managedprovisioning"
dis "com.android.traceur"
dis "com.android.egg"
dis "com.android.wallpaper.livepicker"
dis "com.android.wallpaperbackup"
dis "com.android.wallpapercropper"
dis "com.android.wallpaperpicker"
dis "com.android.htmlviewer"
dis "com.android.pacprocessor"
echo "[+] Blok 3: System Bloat" >> "$LOG"

# ── BLOK 4: PROVIDERS ────────────────────────────────────────
dis "com.android.providers.calendar"
dis "com.android.providers.userdictionary"
dis "com.android.providers.blockednumber"
dis "com.android.providers.contacts"
dis "com.android.providers.downloads"
dis "com.android.providers.downloads.ui"
dis "com.android.providers.telephony"
dis "com.android.providers.partnerbookmarks"
echo "[+] Blok 4: Providers" >> "$LOG"

# ── BLOK 5: REDFINGER / VENDOR BLOAT ─────────────────────────
dis "com.baidu.cloud.service"
dis "com.wsh.appstore"
dis "com.wshl.file.observerservice"
echo "[+] Blok 5: Vendor Bloat" >> "$LOG"

# ── BLOK 6: THEME & COLOR & ICON PACKS ───────────────────────
for pkg in \
  com.android.theme.color.black com.android.theme.color.cinnamon \
  com.android.theme.color.green com.android.theme.color.ocean \
  com.android.theme.color.orchid com.android.theme.color.purple \
  com.android.theme.color.space com.android.theme.font.notoserifsource \
  com.android.theme.icon.roundedrect com.android.theme.icon.squircle \
  com.android.theme.icon.teardrop \
  com.android.theme.icon_pack.circular.android \
  com.android.theme.icon_pack.circular.launcher \
  com.android.theme.icon_pack.circular.settings \
  com.android.theme.icon_pack.circular.systemui \
  com.android.theme.icon_pack.circular.themepicker \
  com.android.theme.icon_pack.filled.android \
  com.android.theme.icon_pack.filled.launcher \
  com.android.theme.icon_pack.filled.settings \
  com.android.theme.icon_pack.filled.systemui \
  com.android.theme.icon_pack.filled.themepicker \
  com.android.theme.icon_pack.rounded.android \
  com.android.theme.icon_pack.rounded.launcher \
  com.android.theme.icon_pack.rounded.settings \
  com.android.theme.icon_pack.rounded.systemui; do
  dis "$pkg"
done
echo "[+] Blok 6: Themes/Icons" >> "$LOG"

# ── BLOK 7: NAVBAR & DISPLAY OVERLAYS ────────────────────────
dis "com.android.internal.display.cutout.emulation.corner"
dis "com.android.internal.display.cutout.emulation.double"
dis "com.android.internal.display.cutout.emulation.tall"
dis "com.android.internal.systemui.navbar.gestural"
dis "com.android.internal.systemui.navbar.gestural_extra_wide_back"
dis "com.android.internal.systemui.navbar.gestural_narrow_back"
dis "com.android.internal.systemui.navbar.gestural_wide_back"
dis "com.android.internal.systemui.navbar.twobutton"
echo "[+] Blok 7: Overlays" >> "$LOG"

# ── BLOK 8: HEADLESS UI (disable non-essential UI except SystemUI) ──
# NEVER disable systemui — breaks WindowManager overlay policy
# NEVER disable launcher3 — pm disable persists across reboot and
# prevents BOOT_COMPLETED broadcast → Termux:Boot won't fire.
# Zwatchdog.sh handles launcher via force-stop every 60s instead.
# Note: com.wsh.launcher doesn't exist on RF devices (confirmed).
dis "com.android.settings"
dis "com.android.documentsui"
echo "[+] Blok 8: Headless UI (settings+docs OFF, launchers kept for boot)" >> "$LOG"

# ── BLOK 9: CAMERA / NFC / USB ───────────────────────────────
dis "com.android.camera2"
dis "com.android.camera"
dis "com.android.nfc"
dis "com.android.nfc.helper"
dis "com.android.usb"
echo "[+] Blok 9: Camera/NFC/USB" >> "$LOG"

# ── BLOK 10: STORAGE / MISC SYSTEM ───────────────────────────
dis "com.android.storagemanager"
dis "com.android.companiondevicemanager"
dis "com.android.vpndialogs"
dis "com.android.stk"
dis "com.android.certinstaller"
dis "com.android.backupconfirm"
dis "com.android.sharedstoragebackup"
dis "com.android.dynsystem"
dis "com.android.cts.priv.ctsshim"
dis "com.android.cts.ctsshim"
echo "[+] Blok 10: Storage/Misc" >> "$LOG"

# ── BLOK 11: SCANNING & LOCATION OFF ─────────────────────────
su -c "settings put global wifi_scan_always_enabled 0" 2>/dev/null
su -c "settings put global ble_scan_always_enabled 0" 2>/dev/null
dis "com.android.location.fused"
su -c "settings put secure location_mode 0" 2>/dev/null
echo "[+] Blok 11: Scanning/Location OFF" >> "$LOG"

# ── BLOK 12: GMS BACKGROUND RESTRICTION ──────────────────────
su -c "cmd appops set com.google.android.gms RUN_IN_BACKGROUND deny" 2>/dev/null
su -c "cmd appops set com.google.android.gms RUN_ANY_IN_BACKGROUND deny" 2>/dev/null
su -c "pm disable com.google.android.gms/.analytics.service.AnalyticsService" 2>/dev/null
su -c "pm disable com.google.android.gms/.ads.AdRequestBrokerService" 2>/dev/null
su -c "pm disable com.google.android.gms/.location.reporting.service.LocationReportingService" 2>/dev/null
su -c "pm disable com.google.android.gms/.backup.BackupTransportService" 2>/dev/null
su -c "pm disable com.google.android.gms/.update.SystemUpdateService" 2>/dev/null
su -c "pm disable com.google.android.gms/.measurement.PackageMeasurementReceiver" 2>/dev/null
su -c "pm disable com.google.android.gms/.chimera.GmsIntentOperationService" 2>/dev/null
su -c "pm disable com.google.android.gms/.gcm.GcmTaskService" 2>/dev/null
echo "[+] Blok 12: GMS restricted" >> "$LOG"

# ── BLOK 13: SYSTEM TWEAKS ───────────────────────────────────
su -c "settings put global window_animation_scale 0.0"
su -c "settings put global transition_animation_scale 0.0"
su -c "settings put global animator_duration_scale 0.0"
su -c "settings put system screen_brightness_mode 0"
su -c "settings put system screen_brightness 0"
su -c "settings put global wifi_sleep_policy 2"
echo "[+] Blok 13: System tweaks" >> "$LOG"

# ── BLOK 14: SERVICE TWEAKS ──────────────────────────────────
su -c "cmd jobscheduler cancel-all" 2>/dev/null
su -c "settings put secure enabled_notification_listeners ''" 2>/dev/null
su -c "settings put secure enabled_notification_policy_access_packages ''" 2>/dev/null
su -c "pm disable com.android.providers.media/com.android.providers.media.MediaScannerReceiver" 2>/dev/null
echo "[+] Blok 14: Service tweaks" >> "$LOG"

# ── BLOK 15: CACHE CLEAR ─────────────────────────────────────
for pkg in \
  "com.android.chrome" "com.google.android.play.games" \
  "com.android.email" "com.android.calendar" \
  "com.baidu.cloud.service" "com.wsh.appstore" \
  "com.google.android.apps.nbu.files" "com.google.android.tts"; do
  su -c "pm clear $pkg >> $LOG 2>&1"
done
echo "[+] Blok 15: Cache cleared" >> "$LOG"

echo "[+] ZDEBLOAT SELESAI — $(date)" >> "$LOG"
