# Redfinger Super Farmer Optimization Plan

## Tujuan
Buat script optimization yang membuat Redfinger 4GB RAM bisa menjalankan Roblox farming dengan:
- **winterhub_agent tetap hidup** (polling via dashboard WinterHub)
- **Heartbeat aktif** (Delta autoexec → POST ke backend setiap 30s)
- **Roblox tetap in-game** (tidak crash/OOM-killed)
- **Headless OK** — layar hitam tidak masalah, semua dikontrol via web

## Arsitektur

```
[Redfinger VM 4GB RAM]
  ├── Termux (auto-start via Termux:Boot)
  │   ├── winterhub_agent.sh  ← JANGAN EDIT, bawaan Wintercode
  │   ├── Zboot.sh            ← boot chain: download + optimize + start hopper
  │   ├── hopper.lua           ← web-controlled hopper (cookie inject, PS hop)
  │   └── scripts/Z*.sh        ← optimization suite
  ├── Delta Executor (com.deltb)
  │   ├── autoexec/Accept.lua  ← heartbeat + in-game scripts
  │   └── Overlay window       ← WAJIB mPolicyVisibility=true
  └── Roblox (com.fluxy.*)     ← game instances
```

## Device Fleet
| Name  | Device ID            | Status      |
|-------|----------------------|-------------|
| rf-01 | `9a6c569817a67b9a`  | offline     |
| rf-06 | `291f2b659a2b18da`  | offline     |
| rf-07 | `e8b229213ae9de6e`  | offline     |
| rf-08 | `d15ef2529a3b459c`  | offline     |
| rf-09 | `85048f747d27b558`  | offline     |

## Indikator Sukses
1. `winterhub_agent.sh` PID ada (`pidof winterhub` atau cek via dashboard)
2. Heartbeat aktif di dashboard (player_name, fps, memory_mb terisi)
3. Roblox PID ada (`pidof com.deltb` atau `com.fluxy.*`)
4. RAM available >200MB setelah semua optimization
5. Survive reboot tanpa manual intervention (via Termux:Boot)

## Akses & Kontrol
- **Primary**: `hopper_send_command shell_exec` (via web backend, butuh hopper online)
- **Secondary**: `rf_exec` (SSH tunnel ke Termux, port 2222 — SAAT INI DOWN)
- **Fallback**: Redfinger console (manual, hindari)
- **Script update**: Push ke GitHub → Zboot.sh auto-download saat boot

## Constraint KRITIS (dari debugging 2026-04-25)

### 1. mPolicyVisibility = WindowManager overlay gate
- Delta executor butuh overlay window untuk autoexec
- WindowManager cache `disable_overlays` setting saat boot
- `pm uninstall com.android.systemui` → `mPolicyVisibility=false` → autoexec MATI
- `pm disable-user com.android.systemui` → BELUM DITES, mungkin juga break
- **SAFE**: force-stop SystemUI (memory freed sementara, respawn sendiri)
- **FIX**: `disable_overlays` harus 0 sebelum boot. Zoptimize.sh sudah set ini.

### 2. always_finish_activities HARUS 0
- Kalau 1: Android kill Roblox activity saat briefly background (saat hop)
- Zdeep.sh sudah fix ke 0
- **BUG DITEMUKAN**: Zwatchdog.sh reset ke 1 setiap 60s! → FIX APPLIED

### 3. max_cached_processes HARUS >= 4
- Kalau 2: terlalu agresif, OOM-kill Delta/Roblox background process
- **BUG DITEMUKAN**: Zwatchdog.sh reset ke 2 setiap 60s! → FIX APPLIED

### 4. Termux:Boot pada Redfinger
- BOOT_COMPLETED broadcast TIDAK terkirim pada testing sebelumnya (RF-04, RF-05)
- User mengklaim sudah setup dan bekerja — BELUM DIVERIFIKASI pada device baru
- Jika tidak work: perlu mekanisme auto-start alternatif (init.d, crontab)

### 5. pm uninstall vs pm disable-user vs force-stop
| Metode | Persist reboot? | Break overlay? | RAM saved |
|--------|----------------|----------------|-----------|
| `pm uninstall -k --user 0` | YA (Zdeep re-run) | YA (SystemUI) | Tinggi |
| `pm disable-user --user 0` | YA | Mungkin (SystemUI) | Sedang |
| `am force-stop` | TIDAK | TIDAK | Rendah (sementara) |
| `kill -9 PID` | TIDAK | Mungkin (SystemUI) | Rendah (sementara) |

### 6. Hypervisor blocks
- `/proc/sys/` writes → GAGAL (read-only)
- ZRAM configuration → sudah ada 8GB virtual swap bawaan
- CPU governor → forced 'performance' oleh hypervisor
- IO scheduler → blocked
- `mount -o remount,rw /system` → blocked

## Script Suite

### Zboot.sh (boot chain)
Lokasi device: `~/.termux/boot/Zboot.sh`
1. Wait boot_completed + root
2. Download scripts terbaru dari GitHub
3. Run: Zdebloat → Zoptimize → Zmemory → Zdeep
4. Start Zwatchdog (background daemon)
5. Start hopper.lua (background daemon)

### scripts/Zdebloat.sh
- 105+ packages disabled via `pm disable-user`
- GMS background restricted
- Scanning/location OFF
- **TIDAK disable**: SystemUI (breaks overlay), GMS core, GSF, WebView, shell, wsh.toolkit

### scripts/Zoptimize.sh
- Resolusi 640x360 @120dpi (persist reboot — headless OK)
- Animasi OFF
- GPU memory tuning (setprop)
- Doze disabled + whitelist game/termux packages
- WiFi never sleep
- OOM protect: Termux=-400, Lua=-300, Roblox=-200
- Force-stop bloat + JobScheduler cancel
- `disable_overlays 0` (KRITIS untuk Delta overlay)

### scripts/Zmemory.sh
- ZRAM 1GB (attempt, hypervisor mungkin block)
- VM sysctl tuning (attempt)
- Dalvik heap: growthlimit 64m, utilization 0.9
- Memory trim system + GMS
- Drop caches + tombstones

### scripts/Zdeep.sh
- AM constants: max_cached=4, always_finish=0
- `pm uninstall` persistent services (BUKAN SystemUI)
- 32 GMS components disabled
- OOM score demotion untuk bloat procs
- Memory trim aggressive
- Cache purge
- Doze whitelist
- Kernel tuning (attempt)

### scripts/Zwatchdog.sh (daemon, 60s loop)
- Force-stop bloat yang auto-restart
- Kill persistent bloat procs (BUKAN SystemUI)
- Re-enforce AM constants (max_cached=4, always_finish=0)
- Drop caches
- OOM protect Termux/Lua/Roblox
- GMS memory trim
- Kill zombies
- LOW (<200MB): aggressive trim + cache purge
- CRITICAL (<100MB): emergency trim semua non-essential

## Bug Fixes Applied (session ini)

| File | Bug | Fix |
|------|-----|-----|
| Zwatchdog.sh | force-stop + kill SystemUI setiap 60s | Removed dari kedua kill list |
| Zwatchdog.sh | `max_cached_processes=2` setiap 60s | Changed ke 4 |
| Zwatchdog.sh | `always_finish_activities=1` setiap 60s | Changed ke 0 |
| Zdeep.sh | `pm uninstall com.android.systemui` | Removed (commit 65756ef) |
| Zdeep.sh | `max_cached_processes=2` | Changed ke 4 (commit ef761fe) |
| Zdeep.sh | `always_finish_activities=1` | Changed ke 0 (commit ef761fe) |
| Zdebloat.sh | `pm disable-user com.android.systemui` | Removed dari Blok 8 |

## Next Steps
1. Push fixes ke GitHub
2. Get devices online (user restart RF / Termux:Boot auto-start)
3. Verify Zboot.sh downloads + runs updated scripts
4. Check heartbeat aktif di dashboard
5. Setup SSH tunnel (rf_exec) sebagai backup control channel
6. Monitor 1 jam — pastikan stabil
