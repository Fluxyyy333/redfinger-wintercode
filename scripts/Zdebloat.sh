#!/data/data/com.termux/files/usr/bin/bash
# Zdebloat.sh — Ultra-Aggressive Debloat for Headless Roblox Farming
# Redfinger Android 10 ARM64 | Target: 8 Roblox instances on 4GB RAM
# Device fully agent-controlled — NO human interaction needed
# Safe to re-run (idempotent)
#
# BOOT-SAFE: Uses am force-stop (non-persistent) instead of pm disable-user.
# pm disable-user persists across reboot and can block BOOT_COMPLETED
# delivery, which prevents Termux:Boot from firing.
# Zwatchdog.sh re-kills these packages every 60s to keep them dead.

LOG="${LOG:-$HOME/Zdebloat.log}"
echo "=== ZDEBLOAT: $(date) ===" >> "$LOG"

fstop() { su -c "am force-stop $1" 2>/dev/null; }

su -c "id" > /dev/null 2>&1 || { echo "[!] ROOT GAGAL" >> "$LOG"; exit 1; }

# ── BLOK 1: PHONE / SIM ──────────────────────────────────────
fstop "com.android.phone"
fstop "com.android.server.telecom"
fstop "com.android.dialer"
fstop "com.android.calllogbackup"
fstop "com.android.simappdialog"
fstop "com.android.carrierconfig"
fstop "com.android.carrierdefaultapp"
fstop "com.android.cellbroadcastreceiver"
fstop "com.android.smspush"
fstop "com.android.ons"
fstop "com.android.mms.service"
fstop "com.android.hotspot2"
echo "[+] Blok 1: Phone/SIM" >> "$LOG"

# ── BLOK 2: GOOGLE APPS ──────────────────────────────────────
fstop "com.google.android.gsf.login"
fstop "com.google.android.inputmethod.latin"
fstop "com.google.android.play.games"
fstop "com.google.android.tts"
fstop "com.google.android.feedback"
fstop "com.google.android.apps.restore"
fstop "com.google.android.configupdater"
fstop "com.google.android.partnersetup"
fstop "com.google.android.setupwizard"
fstop "com.google.android.backuptransport"
fstop "com.google.android.apps.nbu.files"
fstop "com.google.android.ext.shared"
fstop "com.google.android.printservice.recommendation"
echo "[+] Blok 2: Google Apps" >> "$LOG"

# ── BLOK 3: ANDROID SYSTEM BLOAT ─────────────────────────────
fstop "com.android.bluetooth"
fstop "com.android.bluetoothmidiservice"
fstop "com.android.chrome"
fstop "com.android.email"
fstop "com.android.calendar"
fstop "com.android.messaging"
fstop "com.android.contacts"
fstop "com.android.deskclock"
fstop "com.android.emergency"
fstop "com.android.gallery3d"
fstop "com.android.music"
fstop "com.android.musicfx"
fstop "com.android.soundrecorder"
fstop "com.android.dreams.basic"
fstop "com.android.dreams.phototable"
fstop "com.android.mtp"
fstop "com.android.se"
fstop "com.android.printspooler"
fstop "com.android.printservice.recommendation"
fstop "com.android.bips"
fstop "com.android.bookmarkprovider"
fstop "com.android.quicksearchbox"
fstop "com.android.inputmethod.latin"
fstop "com.android.onetimeinitializer"
fstop "com.android.managedprovisioning"
fstop "com.android.traceur"
fstop "com.android.egg"
fstop "com.android.wallpaper.livepicker"
fstop "com.android.wallpaperbackup"
fstop "com.android.wallpapercropper"
fstop "com.android.wallpaperpicker"
fstop "com.android.htmlviewer"
fstop "com.android.pacprocessor"
echo "[+] Blok 3: System Bloat" >> "$LOG"

# ── BLOK 4: PROVIDERS ────────────────────────────────────────
fstop "com.android.providers.calendar"
fstop "com.android.providers.userdictionary"
fstop "com.android.providers.blockednumber"
fstop "com.android.providers.contacts"
fstop "com.android.providers.downloads"
fstop "com.android.providers.downloads.ui"
fstop "com.android.providers.telephony"
fstop "com.android.providers.partnerbookmarks"
echo "[+] Blok 4: Providers" >> "$LOG"

# ── BLOK 5: REDFINGER / VENDOR BLOAT ─────────────────────────
fstop "com.baidu.cloud.service"
fstop "com.wsh.appstore"
fstop "com.wshl.file.observerservice"
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
  fstop "$pkg"
done
echo "[+] Blok 6: Themes/Icons" >> "$LOG"

# ── BLOK 7: NAVBAR & DISPLAY OVERLAYS ────────────────────────
fstop "com.android.internal.display.cutout.emulation.corner"
fstop "com.android.internal.display.cutout.emulation.double"
fstop "com.android.internal.display.cutout.emulation.tall"
fstop "com.android.internal.systemui.navbar.gestural"
fstop "com.android.internal.systemui.navbar.gestural_extra_wide_back"
fstop "com.android.internal.systemui.navbar.gestural_narrow_back"
fstop "com.android.internal.systemui.navbar.gestural_wide_back"
fstop "com.android.internal.systemui.navbar.twobutton"
echo "[+] Blok 7: Overlays" >> "$LOG"

# ── BLOK 8: HEADLESS UI ──────────────────────────────────────
# NEVER pm-disable systemui — breaks overlay mPolicyVisibility
# NEVER pm-disable launcher3 — blocks BOOT_COMPLETED
# Zwatchdog.sh handles both via force-stop every 60s instead.
fstop "com.android.settings"
fstop "com.android.documentsui"
echo "[+] Blok 8: Headless UI (force-stop only, boot-safe)" >> "$LOG"

# ── BLOK 9: CAMERA / NFC / USB ───────────────────────────────
fstop "com.android.camera2"
fstop "com.android.camera"
fstop "com.android.nfc"
fstop "com.android.nfc.helper"
fstop "com.android.usb"
echo "[+] Blok 9: Camera/NFC/USB" >> "$LOG"

# ── BLOK 10: STORAGE / MISC SYSTEM ───────────────────────────
fstop "com.android.storagemanager"
fstop "com.android.companiondevicemanager"
fstop "com.android.vpndialogs"
fstop "com.android.stk"
fstop "com.android.certinstaller"
fstop "com.android.backupconfirm"
fstop "com.android.sharedstoragebackup"
fstop "com.android.dynsystem"
fstop "com.android.cts.priv.ctsshim"
fstop "com.android.cts.ctsshim"
echo "[+] Blok 10: Storage/Misc" >> "$LOG"

# ── BLOK 11: SCANNING & LOCATION OFF ─────────────────────────
su -c "settings put global wifi_scan_always_enabled 0" 2>/dev/null
su -c "settings put global ble_scan_always_enabled 0" 2>/dev/null
fstop "com.android.location.fused"
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
