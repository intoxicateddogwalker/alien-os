#!/usr/bin/env bash
# Alien OS — first-boot setup on a VERIFIED Redroid 14 container (runbook §6).
# Run ON THE ORACLE INSTANCE over SSH, only AFTER verify-redroid.sh passes.
# Do NOT run on the Muse VM.
# What it does: creates the Alien OS data directories under /data (backed by
# /home/ubuntu/alien-data on the host), drops starter config files, and prints
# exactly what is still missing (real APKs) before any overlay can be built.
# What it does NOT do: install any app, fake any feature, or claim Alien OS
# is running. Until real Alien OS APKs exist, this is scaffolding only.
set -euo pipefail

adb connect 127.0.0.1:5555 >/dev/null
adb root >/dev/null 2>&1

# --- Alien OS data tree (lives in /data, survives container recreates) ---
adb shell mkdir -p \
  /data/alien/comms-lab/rules \
  /data/alien/wifi-auditor/wordlists \
  /data/alien/wifi-auditor/configs \
  /data/alien/mesh-text \
  /data/alien/sentinel/logs \
  /data/alien/sentinel/quarantine \
  /data/alien/voice \
  /data/alien/pixel-editor

# --- Starter configs (own-network auditor only; no targeting files) ---
cat > /tmp/alien-wifi-auditor.conf <<'EOF'
# Alien OS Wi-Fi Auditor — OWN network only.
# No target lists for buildings, businesses, or other people's networks.
# Fill in your own network below when the auditor APK exists.
ssid=
bssid=
mode=audit-own-network-only
EOF
adb push /tmp/alien-wifi-auditor.conf /data/alien/wifi-auditor/configs/own-network.conf

cat > /tmp/alien-mesh.conf <<'EOF'
# Alien OS Mesh Text — opt-in direct radio only.
# Only phones that joined the mesh. No towers, no port-knocking strangers.
channel=7
tx_power_mw=500
tx=off
rx=off
EOF
adb push /tmp/alien-mesh.conf /data/alien/mesh-text/mesh.conf

cat > /tmp/alien-sentinel.conf <<'EOF'
# Alien OS Sentinel Shield
scan_interval_hours=2
action=remove
# action=remove | quarantine — remove is the default the user asked for.
EOF
adb push /tmp/alien-sentinel.conf /data/alien/sentinel/sentinel.conf

adb shell ls -R /data/alien

echo ""
echo "Scaffolding done. Still missing before the overlay can be built:"
echo "  - Alien OS launcher APK (and its package/activity names)"
echo "  - Alien OS deck/tool APKs (Bridge, Phone, Control, Comms, Arsenal,"
echo "    Linux, Pixel, Core Live, Sentinel Shield, Comms Lab, Mesh Text)"
echo "  - Alien wallpapers / boot assets"
echo "Until those exist, Dockerfile.alien-os stays a skeleton — do not build it."
