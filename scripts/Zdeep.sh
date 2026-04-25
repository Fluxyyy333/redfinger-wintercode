#!/data/data/com.termux/files/usr/bin/bash
# Zdeep.sh — Deep System Optimization (Nuclear Level)
# Redfinger Android 10 ARM64 | Target: 8 Roblox instances on 4GB RAM
# Run AFTER Zdebloat.sh + Zoptimize.sh + Zmemory.sh
# Safe to re-run (idempotent)

LOG="${LOG:-$HOME/Zdeep.log}"
echo "=== ZDEEP: $(date) ===" >> "$LOG"

su -c "id" > /dev/null 2>&1 || { echo "[!] ROOT GAGAL" >> "$LOG"; exit 1; }

M_BEFORE=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))

# ── PHASE 1: Activity Manager Constants ──────────────────────
su -c "settings put global activity_manager_constants max_cached_processes=4,background_settle_time=5000,fgs_bg_restriction_enabled=true" 2>/dev/null
su -c "settings put global always_finish_activities 0" 2>/dev/null
su -c "settings put global cached_apps_freezer enabled" 2>/dev/null
su -c "settings put global settings_enable_monitor_phantom_procs false" 2>/dev/null
su -c "settings put secure location_providers_allowed -gps,-network" 2>/dev/null
echo "[+] Phase 1: AM constants set" >> "$LOG"

# ── PHASE 2: Uninstall persistent system services (user 0) ──
# pm uninstall is stronger than pm disable — prevents system_server from respawning
# NOTE: com.android.systemui MUST NOT be uninstalled — it breaks
# WindowManager overlay policy (mPolicyVisibility=false) which
# prevents Delta executor autoexec from running.
for pkg in \
    com.android.phone \
    com.android.providers.media \
    com.android.plugin \
    com.android.se \
    com.android.keychain \
    com.android.datatransport; do
    su -c "pm uninstall -k --user 0 $pkg" >> "$LOG" 2>&1
done
sleep 3
echo "[+] Phase 2: Persistent services uninstalled" >> "$LOG"

# ── PHASE 3: GMS Component Disabling (non-essential services) ─
GMS_DISABLE=(
    "com.google.android.gms.ads.identifier.service.AdvertisingIdService"
    "com.google.android.gms.ads.GadsService"
    "com.google.android.gms.analytics.service.AnalyticsService"
    "com.google.android.gms.analytics.AnalyticsTaskService"
    "com.google.android.gms.backup.BackupTransportService"
    "com.google.android.gms.fitness.service.FitnessBrokerService"
    "com.google.android.gms.nearby.connection.service.NearbyConnectionsAndroidService"
    "com.google.android.gms.nearby.presence.service.LifeCycleService"
    "com.google.android.gms.nearby.sharing.ReceiveSurfaceService"
    "com.google.android.gms.cast.media.CastMediaRouteProviderService"
    "com.google.android.gms.wallet.service.WalletGcmTaskService"
    "com.google.android.gms.tapandpay.hce.service.TpHceService"
    "com.google.android.gms.car.CarService"
    "com.google.android.gms.wearable.service.WearableService"
    "com.google.android.gms.measurement.AppMeasurementService"
    "com.google.android.gms.clearcut.service.ClearcutLoggerService"
    "com.google.android.gms.phenotype.service.sync.PhenotypeConfigurator"
    "com.google.android.gms.mdm.services.DeviceManagerApiService"
    "com.google.android.gms.locationsharing.service.LocationSharingService"
    "com.google.android.gms.personalsafety.service.SndDetectionService"
    "com.google.android.gms.icing.service.IndexService"
    "com.google.android.gms.feedback.FeedbackService"
    "com.google.android.gms.auth.setup.devicesignals.LockScreenService"
    "com.google.android.gms.location.reporting.service.LocationReportingService"
    "com.google.android.gms.update.SystemUpdateService"
    "com.google.android.gms.chimera.GmsIntentOperationService"
    "com.google.android.gms.gcm.GcmTaskService"
    "com.google.android.gms.auth.proximity.screenlock.LockScreenService"
    "com.google.android.gms.kids.KidsService"
    "com.google.android.gms.people.contactssync.ContactSyncService"
    "com.google.android.gms.drive.services.DriveGcmTaskService"
    "com.google.android.gms.thunderbird.service.ThunderbirdService"
)
for comp in "${GMS_DISABLE[@]}"; do
    su -c "pm disable com.google.android.gms/$comp" 2>/dev/null
done
echo "[+] Phase 3: ${#GMS_DISABLE[@]} GMS components disabled" >> "$LOG"

# ── PHASE 4: OOM Score + Priority Demotion ───────────────────
BLOAT_PROCS="com.android.phone android.process.media com.android.plugin com.android.datatransport com.android.se com.android.keychain com.google.process.gservices com.google.process.gapps"
for P in $BLOAT_PROCS; do
    PID=$(su -c "pidof $P" 2>/dev/null)
    if [ -n "$PID" ]; then
        su -c "echo 1000 > /proc/$PID/oom_score_adj" 2>/dev/null
        renice 19 -p $PID 2>/dev/null
    fi
done
echo "[+] Phase 4: OOM scores set" >> "$LOG"

# ── PHASE 5: Memory Trim (aggressive) ────────────────────────
TRIM_TARGETS="com.google.android.gms com.google.android.gms.persistent com.google.process.gservices com.google.process.gapps android.process.media com.android.phone com.android.keychain"
for T in $TRIM_TARGETS; do
    su -c "am send-trim-memory $T COMPLETE" 2>/dev/null
done
echo "[+] Phase 5: Memory trimmed" >> "$LOG"

# ── PHASE 6: Cache Purge ─────────────────────────────────────
su -c "rm -rf /data/data/com.google.android.gms/cache/* /data/data/com.google.android.gms/code_cache/*" 2>/dev/null
su -c "rm -rf /data/data/com.android.systemui/cache/* /data/data/com.android.phone/cache/*" 2>/dev/null
su -c "rm -rf /data/tombstones/* /data/anr/*" 2>/dev/null
su -c "pm trim-caches 999G" 2>/dev/null
su -c "echo 3 > /proc/sys/vm/drop_caches" 2>/dev/null
echo "[+] Phase 6: Caches purged" >> "$LOG"

# ── PHASE 7: Doze + Whitelist ─────────────────────────────────
su -c "dumpsys deviceidle whitelist +com.termux" 2>/dev/null
su -c "dumpsys deviceidle whitelist +com.deltb" 2>/dev/null
su -c "dumpsys deviceidle whitelist +com.fluxy.one" 2>/dev/null
su -c "dumpsys deviceidle whitelist +com.fluxy.two" 2>/dev/null
su -c "dumpsys deviceidle whitelist +com.fluxy.three" 2>/dev/null
su -c "dumpsys deviceidle whitelist +com.fluxy.four" 2>/dev/null
su -c "dumpsys deviceidle whitelist +com.fluxy.five" 2>/dev/null
su -c "dumpsys deviceidle whitelist +com.fluxy.six" 2>/dev/null
su -c "dumpsys deviceidle whitelist +com.fluxy.seven" 2>/dev/null
su -c "dumpsys deviceidle whitelist +com.fluxy.eight" 2>/dev/null
echo "[+] Phase 7: Doze whitelist set" >> "$LOG"

# ── PHASE 8: Kernel-level (best-effort, hypervisor may block) ─
su -c "dmesg -n 1" 2>/dev/null
su -c "echo 1 > /proc/sys/vm/compact_memory" 2>/dev/null
su -c "echo 1 > /proc/sys/vm/overcommit_memory" 2>/dev/null
echo "[+] Phase 8: Kernel tuning attempted" >> "$LOG"

# ── RESULT ────────────────────────────────────────────────────
sleep 2
M_AFTER=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
SVCS=$(su -c "dumpsys activity services 2>/dev/null" | grep -c ServiceRecord)
PROCS=$(su -c "ps -A 2>/dev/null" | wc -l)
echo "[+] ZDEEP DONE: ${M_BEFORE}MB -> ${M_AFTER}MB (+$((M_AFTER - M_BEFORE))MB) svcs=$SVCS procs=$PROCS" >> "$LOG"
