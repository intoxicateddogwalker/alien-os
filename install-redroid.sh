#!/usr/bin/env bash
# Alien OS — Redroid 14 install script for Oracle A1, Ubuntu 24.04 arm64.
# Copied verbatim from runbook §3.5 (~/workspace/goals/alien-os/files/redroid-install-runbook.md).
# Run ON THE ORACLE INSTANCE over SSH. Do NOT run on the Muse VM.
# Prerequisites: Oracle account + Always Free A1 Flex instance (Ubuntu 24.04 aarch64),
# SSH access as ubuntu with the key in ~/.ssh/id_ed25519.pub.
set -euo pipefail

# --- 1. System + Docker CE (arm64) ---
sudo apt update
sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg android-tools-adb

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu || true

# --- 2. binder_linux + binderfs, persistent ---
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"
sudo mkdir -p /dev/binderfs
sudo mount -t binder binder /dev/binderfs || true
echo "binder_linux" | sudo tee /etc/modules-load.d/binder.conf
echo 'options binder_linux devices="binder,hwbinder,vndbinder"' \
  | sudo tee /etc/modprobe.d/binder.conf
grep -q "^binder /dev/binderfs" /etc/fstab \
  || echo "binder /dev/binderfs binder defaults 0 0" | sudo tee -a /etc/fstab

# --- 3. Redroid 14 ---
mkdir -p /home/ubuntu/alien-data
sudo docker pull redroid/redroid:14.0.0-240527

# Memory/CPU: 4g + 2 CPUs on the 2 OCPU / 12 GB shape (the only Always Free A1 shape for new accounts).
sudo docker run -d \
  --name alien-os \
  --privileged \
  --restart unless-stopped \
  --memory=4g \
  --cpus=2 \
  -p 127.0.0.1:5555:5555 \
  -v /home/ubuntu/alien-data:/data \
  redroid/redroid:14.0.0-240527 \
  androidboot.redroid_gpu_mode=guest \
  androidboot.redroid_width=1080 \
  androidboot.redroid_height=2400 \
  androidboot.redroid_dpi=420 \
  ro.secure=0 \
  ro.debuggable=1

echo "Redroid container started. Wait 60-90s for first boot, then verify with:"
echo "  adb connect 127.0.0.1:5555"
echo "  adb root; adb shell id"
