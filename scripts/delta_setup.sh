#!/data/data/com.termux/files/usr/bin/bash
# DELTA_SETUP.sh — Install spoofer vault APK + extract resetprop
# Called by install.sh during initial setup
# Also callable standalone for re-setup

SPOOFER_PKG="com.stealth.vault"
RESETPROP="/data/local/tmp/resetprop"

R=$'\033[0m'; G=$'\033[0;32m'; E=$'\033[0;31m'; Y=$'\033[0;33m'
ok()  { echo -e "  ${G}✓${R} $1"; }
err() { echo -e "  ${E}✗${R} $1"; }
run() { echo -e "  ${Y}>${R} $1"; }

SPOOFER_URL="$1"

# ── Install spoofer APK ──
if su -c "pm path $SPOOFER_PKG" > /dev/null 2>&1; then
    ok "Spoofer APK sudah terinstall."
else
    if [ -z "$SPOOFER_URL" ]; then
        err "URL spoofer.apk tidak diberikan."
        exit 1
    fi

    TMP_APK="/sdcard/Download/spoofer.apk"

    run "Download spoofer.apk..."
    curl -fsSL --retry 3 -o "$TMP_APK" "$SPOOFER_URL"

    if [ ! -s "$TMP_APK" ]; then
        err "Download spoofer gagal."
        exit 1
    fi

    run "Install APK..."
    if su -c "pm install -r '$TMP_APK'" > /dev/null 2>&1; then
        ok "APK installed: $SPOOFER_PKG"
    else
        err "pm install gagal."
        rm -f "$TMP_APK"
        exit 1
    fi
    rm -f "$TMP_APK"
fi

# ── Extract resetprop dari APK ──
run "Extract resetprop..."
APK_LINE=$(su -c "pm path $SPOOFER_PKG" 2>/dev/null)
APK_PATH="${APK_LINE#package:}"
APK_DIR=$(dirname "$APK_PATH")

LIB_PATH=""
for candidate in \
    "$APK_DIR/lib/arm64/libresetprop.so" \
    "$APK_DIR/lib/arm64-v8a/libresetprop.so"; do
    if su -c "[ -f '$candidate' ]" 2>/dev/null; then
        LIB_PATH="$candidate"
        break
    fi
done

if [ -z "$LIB_PATH" ]; then
    LIB_PATH=$(su -c "find /data/app -name 'libresetprop.so' -path '*vault*' 2>/dev/null" | head -1)
fi

if [ -z "$LIB_PATH" ]; then
    err "libresetprop.so tidak ditemukan di APK."
    exit 1
fi

su -c "cp '$LIB_PATH' '$RESETPROP' && chmod 755 '$RESETPROP'"

# ── Verify ──
SERIAL_NOW=$(su -c "$RESETPROP ro.serialno" 2>/dev/null)
if [ -n "$SERIAL_NOW" ]; then
    ok "resetprop OK (current serialno=$SERIAL_NOW)"
else
    err "resetprop tidak berfungsi."
    exit 1
fi
