#!/data/data/com.termux/files/usr/bin/bash
# DEBLOAT_RF.sh — Redfinger Cloud Phone (Confirmed Package List via ADB)
# Redfinger Android 10 ARM64 | Roblox Farming
# Package list verified against real device — zero "package not found" errors
# Run once after install, do NOT run while Roblox instances are active

LOG="${LOG:-$HOME/debloat.log}"
echo "=== DEBLOAT: $(date) ===" > "$LOG"

# disable + immediately force-stop so RAM is freed right away
dis() { su -c "pm disable-user --user 0 $1 >> $LOG 2>&1 && am force-stop $1 2>/dev/null"; }
uni() { su -c "pm uninstall -k --user 0 $1 >> $LOG 2>&1 && am force-stop $1 2>/dev/null"; }

su -c "id" > /dev/null 2>&1 || { echo "[!] ROOT GAGAL"; exit 1; }

# ── BLOK 1: PHONE / SIM (no SIM on cloud phone) ──────────────
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
echo "[+] Blok 1: Phone/SIM done"

# ── BLOK 2: GOOGLE APPS ──────────────────────────────────────
dis "com.google.android.gsf.login"      # Google account sync UI (not needed for Roblox)
dis "com.google.android.inputmethod.latin"  # Gboard
dis "com.google.android.play.games"     # Play Games (not needed)
# KEEP: com.google.android.gms (Roblox auth)
# KEEP: com.google.android.gsf (Google services framework)
# KEEP: com.google.android.webview (Roblox renderer)
echo "[+] Blok 2: Google Apps done"

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
echo "[+] Blok 3: System Bloat done"

# ── BLOK 4: PROVIDERS (safe to disable) ──────────────────────
dis "com.android.providers.calendar"
dis "com.android.providers.userdictionary"
dis "com.android.providers.blockednumber"
echo "[+] Blok 4: Providers done"

# ── BLOK 5: REDFINGER / VENDOR BLOAT ─────────────────────────
dis "com.baidu.cloud.service"       # Baidu analytics/tracking
dis "com.wsh.appstore"              # Redfinger's own app store
dis "com.wshl.file.observerservice" # Redfinger file observer
# KEEP: com.wsh.toolkit (Redfinger system tool — removing may break device)
echo "[+] Blok 5: Vendor Bloat done"

# ── BLOK 6: THEME & COLOR PACKS ──────────────────────────────
dis "com.android.theme.color.black"
dis "com.android.theme.color.cinnamon"
dis "com.android.theme.color.green"
dis "com.android.theme.color.ocean"
dis "com.android.theme.color.orchid"
dis "com.android.theme.color.purple"
dis "com.android.theme.color.space"
dis "com.android.theme.font.notoserifsource"
echo "[+] Blok 6: Theme/Color done"

# ── BLOK 7: ICON PACKS ───────────────────────────────────────
dis "com.android.theme.icon.roundedrect"
dis "com.android.theme.icon.squircle"
dis "com.android.theme.icon.teardrop"
dis "com.android.theme.icon_pack.circular.android"
dis "com.android.theme.icon_pack.circular.launcher"
dis "com.android.theme.icon_pack.circular.settings"
dis "com.android.theme.icon_pack.circular.systemui"
dis "com.android.theme.icon_pack.circular.themepicker"
dis "com.android.theme.icon_pack.filled.android"
dis "com.android.theme.icon_pack.filled.launcher"
dis "com.android.theme.icon_pack.filled.settings"
dis "com.android.theme.icon_pack.filled.systemui"
dis "com.android.theme.icon_pack.filled.themepicker"
dis "com.android.theme.icon_pack.rounded.android"
dis "com.android.theme.icon_pack.rounded.launcher"
dis "com.android.theme.icon_pack.rounded.settings"
dis "com.android.theme.icon_pack.rounded.systemui"
echo "[+] Blok 7: Icon Packs done"

# ── BLOK 8: NAVBAR & DISPLAY OVERLAYS ────────────────────────
dis "com.android.internal.display.cutout.emulation.corner"
dis "com.android.internal.display.cutout.emulation.double"
dis "com.android.internal.display.cutout.emulation.tall"
dis "com.android.internal.systemui.navbar.gestural"
dis "com.android.internal.systemui.navbar.gestural_extra_wide_back"
dis "com.android.internal.systemui.navbar.gestural_narrow_back"
dis "com.android.internal.systemui.navbar.gestural_wide_back"
dis "com.android.internal.systemui.navbar.twobutton"
echo "[+] Blok 8: Overlays done"

# ── BLOK 9: CACHE CLEAR ──────────────────────────────────────
for pkg in \
  "com.android.chrome" "com.google.android.play.games" \
  "com.android.email" "com.android.calendar" \
  "com.baidu.cloud.service" "com.wsh.appstore"; do
  su -c "pm clear $pkg >> $LOG 2>&1"
done
echo "[+] Blok 9: Cache cleared"

# ── BLOK 10: SYSTEM TWEAKS ───────────────────────────────────
su -c "settings put global window_animation_scale 0.0"
su -c "settings put global transition_animation_scale 0.0"
su -c "settings put global animator_duration_scale 0.0"
su -c "settings put system screen_brightness_mode 0"
su -c "settings put system screen_brightness 0"
su -c "settings put global wifi_sleep_policy 2"
echo "[+] Blok 10: System tweaks done"

echo "" | tee -a "$LOG"
echo "[+] DEBLOAT SELESAI — $(date)" | tee -a "$LOG"
echo "[+] Log: $LOG"
