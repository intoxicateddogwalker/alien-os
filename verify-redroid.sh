#!/usr/bin/env bash
# Alien OS — Redroid 14 verification script (runbook §4).
# Run ON THE ORACLE INSTANCE over SSH, after install-redroid.sh has started
# the container and 60-90s have passed for first boot. Do NOT run on the Muse VM.
# Exits 0 only when EVERY check passes; prints PASS/FAIL per check.
# Usage: bash ~/verify-redroid.sh
set -uo pipefail

FAIL=0
check() { # check "label" "actual" "expected"
  if [ "$2" = "$3" ]; then echo "PASS: $1 ($2)"; else echo "FAIL: $1 — got '$2', expected '$3'"; FAIL=1; fi
}

echo "== container =="
docker ps --filter name=alien-os --format '{{.Names}} {{.Status}}' | grep -q alien-os \
  && echo "PASS: container alien-os is up" || { echo "FAIL: container alien-os not running (see: docker ps -a; docker logs alien-os --tail 100)"; FAIL=1; }

echo "== adb connect =="
adb connect 127.0.0.1:5555
adb devices | grep -q "127.0.0.1:5555.*device" \
  && echo "PASS: adb devices shows 127.0.0.1:5555 device" \
  || { echo "FAIL: adb device not listed (wait 90s, check docker logs, confirm -p 127.0.0.1:5555:5555)"; FAIL=1; }

echo "== root =="
adb root >/dev/null 2>&1
ID_OUT="$(adb shell id 2>/dev/null | tr -d '\r')"
check "adb shell id" "$ID_OUT" "uid=0(root) gid=0(root)"

echo "== Android version / props =="
REL="$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
check "ro.build.version.release" "$REL" "14"
SECURE="$(adb shell getprop ro.secure 2>/dev/null | tr -d '\r')"
check "ro.secure" "$SECURE" "0"
DEBUG="$(adb shell getprop ro.debuggable 2>/dev/null | tr -d '\r')"
check "ro.debuggable" "$DEBUG" "1"

echo "== screen =="
SIZE="$(adb shell wm size 2>/dev/null | tr -d '\r')"
check "wm size" "$SIZE" "Physical size: 1080x2400"
DENSITY="$(adb shell wm density 2>/dev/null | tr -d '\r')"
check "wm density" "$DENSITY" "Physical density: 420"

echo "== model =="
echo "model:        $(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
echo "manufacturer: $(adb shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r')"
echo "packages:     $(adb shell pm list packages 2>/dev/null | wc -l) installed"

if [ "$FAIL" = "0" ]; then
  echo "ALL CHECKS PASSED — Redroid 14 is real: root adb, Android 14, 1080x2400 @ 420dpi."
else
  echo "SOME CHECKS FAILED — do not call this Alien OS real yet. See runbook §7."
  exit 1
fi
