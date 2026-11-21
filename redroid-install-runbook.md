# Alien OS — Real Android Emulator Runbook
## Redroid 14 on Oracle Cloud Always Free (A1 Flex, ARM)

**Status, 2026-11-08: NOT RUNNING YET. NOTHING IN THIS FILE HAS BEEN EXECUTED.**
This is a preparation document only. No Oracle account, instance, Docker container, or Android emulator has been created from it, and nothing in it was run on the Muse VM.

**Blocked on:** Oracle Cloud signup — the new Oracle password step. Email verification for `devilmightbe@icloud.com` succeeded, the Account Information form is filled in (Christopher Arthur, Individual, US West (Phoenix), tenancy `devilmightbe`), but Oracle flagged the saved password as weak and disabled Continue. A new password meeting Oracle's rules must be set first, then the signup (address / phone / card identity check) must be completed. Only then can an instance be created. Do not enable paid services or switch to a paid shape to get around capacity.

**Why Redroid, why this host:**
- Oracle A1 Flex is ARM (`aarch64`) and has **no KVM / no `/dev/kvm` / no nested virtualization**. That rules out Google AVD, Cuttlefish, Bliss / Android-x86 in a VM, QEMU+KVM, and Genymotion (also proprietary / closed-source).
- Redroid 14 (`redroid/redroid:14.0.0-240527`, Apache-2.0) runs in Docker, sharing the host kernel. It needs `binder_linux`, not KVM. It is headless, root by design, and ARM-native.
- Waydroid was the second option: also no KVM and ARM, but it needs a Wayland desktop. Oracle is headless / no GPU, so Redroid wins.
- A full AOSP recompile cannot happen on this instance (needs ~400 GB disk and ~64 GB RAM). The Alien OS customisation below is an overlay on top of the Redroid image, built off-box if a full system image is ever needed.

**Target host (plan for the smaller shape, hope for the larger):**
- Oracle docs changed June 2026; enforcement from 18 Aug 2026: new Always Free A1 is **2 OCPU / 12 GB** (older 4 OCPU / 24 GB accounts are reported still $0 in many cases). Plan for 2/12 — request 2 OCPU / 12 GB directly. Do NOT try 4/24 first: the old 4 OCPU / 24 GB Always Free allowance was halved in June 2026 (enforced 18 Aug 2026) and no longer exists for new accounts.
- No GPU on A1. Use software rendering: `androidboot.redroid_gpu_mode=guest`.

---

## 1. Oracle instance creation

Do this in the Oracle Cloud console only after signup is complete. Do not create a paid instance.

1. Home region: **US West (Phoenix)** — as chosen at signup.
2. Create a compartment if needed, then **Compute > Instances > Create instance**.
3. Name: `alien-os` (or `alien-os-redroid`).
4. Placement / Availability Domain: try **AD-1** first. If you get "Out of host capacity", see §7 — try AD-2 / AD-3, then retry later. Do not switch to a paid shape.
5. Image: **Canonical Ubuntu 24.04**, `aarch64` / ARM. Use the Minimal image only if you are comfortable with it; the regular Ubuntu 24.04 image is the safer default.
6. Shape: **VM.Standard.A1.Flex**
   - Request: **2 OCPU, 12 GB memory** (the only Always Free A1 shape for new accounts).
7. Boot volume: **100 GB** (minimum 50 GB; Always Free allows up to 200 GB total boot-volume storage across instances). Redroid's `/data` lives on a Docker volume on this disk, so do not pick the smallest boot volume.
8. Networking:
   - Create / select a VCN with a public subnet, assign a public IPv4 address.
   - SSH key: **upload / paste your own public SSH key** (`~/.ssh/id_ed25519.pub` or equivalent). Do not use a password-only login, and do not paste a private key anywhere.
9. Security list / Network Security Group — **do not open ADB to the world:**
   - Ingress **22/tcp (SSH): only your admin IP as a /32** (e.g. `203.0.113.10/32`). Never `0.0.0.0/0` for SSH.
   - Ingress **5555/tcp (ADB): do not open it at all if you use the SSH tunnel below** — this is the recommended setup. If you ever need direct remote ADB, open it only to your admin IP /32, never `0.0.0.0/0`. ADB with root and no authentication is a full device compromise if it is public.
   - Egress: allow all (default) so the instance can pull Docker images and Ubuntu packages.
10. Create the instance, note its **public IP** and Availability Domain, and SSH in:
    ```bash
    ssh -i ~/.ssh/id_ed25519 ubuntu@<ORACLE_PUBLIC_IP>
    ```
11. Confirm architecture and resources:
    ```bash
    uname -m          # expect: aarch64
    nproc; free -h; df -h /
    ls /dev/kvm || echo "no /dev/kvm — expected on A1, Redroid does not need it"
    ```

---

## 2. Ubuntu 24.04 setup — Docker CE (arm64) + binder

Run all of this **on the Oracle instance over SSH**, not on the Muse VM.

### 2.1 System update

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg android-tools-adb
```

`android-tools-adb` gives you the `adb` client on the host. `scrcpy` is a client-side tool — install it on your own laptop, not on the headless Oracle host (see §5).

### 2.2 Install Docker CE for arm64

```bash
# Keyring
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Docker repo (Ubuntu 24.04 = "noble", arm64)
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu noble stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu
# Log out and back in for the docker group to take effect, or use `sudo docker` below.
docker version
docker run --rm hello-world
```

If `docker run hello-world` fails, see §7 (Docker not starting) — do not proceed to Redroid until Docker itself works.

### 2.3 binder_linux + binderfs (required by Redroid)

Redroid needs the Android binder driver exposed by the host kernel. Oracle's Ubuntu 24.04 ARM kernel ships `binder_linux` as a module; it is not loaded by default.

```bash
# Load now, with all three binder devices Redroid expects
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"

# Mount binderfs
sudo mkdir -p /dev/binderfs
sudo mount -t binder binder /dev/binderfs

# Verify
ls -l /dev/binderfs/
ls -l /dev/binder* /dev/hwbinder* /dev/vndbinder* 2>/dev/null || true
```

**Make it persistent across reboot** — otherwise Redroid will fail to start after the first reboot:

```bash
# Load the module at boot
echo "binder_linux" | sudo tee /etc/modules-load.d/binder.conf

# Pass the devices option at boot
echo 'options binder_linux devices="binder,hwbinder,vndbinder"' \
  | sudo tee /etc/modprobe.d/binder.conf

# Mount binderfs at boot (add this line to /etc/fstab)
echo "binder /dev/binderfs binder defaults 0 0" | sudo tee -a /etc/fstab

# Verify the files, then reboot and re-check
cat /etc/modules-load.d/binder.conf
cat /etc/modprobe.d/binder.conf
sudo reboot
# after reconnecting:
ls -l /dev/binderfs/ && docker version
```

If `ls /dev/binderfs/` is empty after reboot, see §7 (binder missing).

---

## 3. Redroid 14 — pull and run

### 3.1 Pull the image

```bash
docker pull redroid/redroid:14.0.0-240527
docker images redroid/redroid
```

Pin the tag `14.0.0-240527` (dated, multi-arch incl. linux/arm64 — verified live on Docker Hub 2026-11-08). Do not use `latest` for a reproducible Alien OS build. **Correction 2026-11-08:** the runbook originally pinned `14.0.0-arm64`, but that tag does not exist on Docker Hub — the pull would have failed. The closest real 14.0.0 tags are `14.0.0-latest` (moving) and `14.0.0-240527` (dated pin, used here).

### 3.2 Data volume

```bash
mkdir -p /home/ubuntu/alien-data
```

`/home/ubuntu/alien-data` is mounted as `/data` inside Redroid — apps, settings, and Alien OS files live there. Back this directory up before any instance resize, rebuild, or reclaim; it is the only state that survives a container recreate.

### 3.3 Run — 2 OCPU / 12 GB shape (request this shape)

```bash
docker run -d \
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
```

Notes:
- `--privileged` is required for Redroid.
- `-p 127.0.0.1:5555:5555` binds ADB to localhost only. Access it over an SSH tunnel (see §5). Do not change this to `-p 5555:5555` — that would expose root ADB on the public interface.
- `--memory=4g` leaves ~8 GB for the host / Docker on a 12 GB instance. Do not give the container more than 4 GB — the host, Docker, and Android system services need the rest. Expect slower UI and slower app installs than on a bigger shape.
- `androidboot.redroid_gpu_mode=guest` = software rendering (no GPU on A1).
- `ro.secure=0 ro.debuggable=1` = root adb by design. This is the intended Redroid behaviour, not a hack.

### 3.4 The old 4 OCPU / 24 GB shape (retired — do not use)

Oracle halved the Always Free A1 allowance in June 2026 (enforced 18 Aug 2026). The 4 OCPU / 24 GB shape no longer exists for new accounts — do not request it. The command in §3.3 (2 OCPU / 12 GB, container capped at 4 GB / 2 CPUs) is the shape to use.

### 3.5 Full install script (run on the Oracle instance only)

Save as `~/install-redroid.sh` on the Oracle instance, review it, then run `bash ~/install-redroid.sh`. It is **not** to be run on the Muse VM.

```bash
#!/usr/bin/env bash
# Alien OS — Redroid 14 install script for Oracle A1, Ubuntu 24.04 arm64.
# Run ON THE ORACLE INSTANCE over SSH. Do NOT run on the Muse VM.
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
```

---

## 4. Verification — prove it is real, not simulated

Wait 60–90 seconds after `docker run` for first boot, then:

```bash
# From the Oracle host itself
docker ps
docker logs alien-os --tail 50

adb connect 127.0.0.1:5555
adb devices
# expect: 127.0.0.1:5555  device

adb root
adb shell id
# expect: uid=0(root) gid=0(root) — this is the real check

adb shell getprop ro.build.version.release
# expect: 14
adb shell getprop ro.secure
# expect: 0
adb shell getprop ro.debuggable
# expect: 1
adb shell getprop ro.product.model
adb shell getprop ro.product.manufacturer

adb shell wm size
# expect: Physical size: 1080x2400
adb shell wm density
# expect: Physical density: 420

adb shell pm list packages | head -20
adb shell dumpsys battery | head -20
```

**Pass criteria — all must hold before calling this "real":**
- `docker ps` shows `alien-os` up, no restart loop.
- `adb devices` shows `127.0.0.1:5555 device`.
- `adb shell id` returns `uid=0(root)`.
- `getprop ro.build.version.release` returns `14`.
- Screen / UI is visible via scrcpy (below) and responds to touch/click.

If any of those fail, do not claim the OS is working — go to §7.

---

## 5. Seeing and controlling the screen

Redroid is headless — there is no built-in web viewer in the stock `redroid/redroid` image. Do not claim one exists.

**Option A — scrcpy (recommended, from your own laptop):**
1. On your laptop, install scrcpy and adb.
2. Open an SSH tunnel to the Oracle host:
   ```bash
   ssh -L 5555:127.0.0.1:5555 -i ~/.ssh/id_ed25519 ubuntu@<ORACLE_PUBLIC_IP>
   ```
3. In a second terminal on your laptop:
   ```bash
   adb connect 127.0.0.1:5555
   scrcpy
   ```
   scrcpy mirrors the Redroid screen and forwards mouse/touch and keyboard. This is how you drive the Alien OS UI for real.

**Option B — web viewer (add-on, not stock):**
Run a separate viewer container / service that talks to the same ADB port (e.g. a ws-scrcpy-style viewer). This is an extra component to evaluate at build time, not part of `redroid/redroid:14.0.0-240527`. If you add one, bind it to localhost and reach it over the same SSH tunnel, and never expose it publicly.

**Option C — adb only (no screen):**
For installs, shell work, and automation, adb alone is enough:
```bash
adb install app.apk
adb shell input tap 500 1000
adb shell screencap -p /sdcard/screen.png && adb pull /sdcard/screen.png .
```

---

## 6. Alien OS overlay plan — turning Redroid into Alien OS

Goal: the same Alien OS that exists today as a web prototype (Bridge / Phone / Control / Comms / Arsenal / Linux / Pixel / Core Live decks, D20 nav, Mesh Text, Sentinel Shield, Comms Lab, Kali Wi-Fi Auditor, Muse voice) running as real apps on a real Android 14 system, with root kept permanently.

### 6.1 Principles
- Do not edit the running system partition by hand and call it a build. Keep every change in a versioned Dockerfile / overlay directory so the image can be rebuilt.
- Keep the prototype labelled as a prototype until this Redroid build passes §4. The web prototype is simulated; this build is the first real one.
- Root is already the default in Redroid (`ro.secure=0`). The overlay must not remove that, and must not depend on a root method that breaks on Redroid.

### 6.2 Dockerfile overlay

Build a custom image `FROM` Redroid, on a machine with Docker (the Oracle instance itself can build it, or build it off-box and push it):

```dockerfile
# Dockerfile.alien-os
FROM redroid/redroid:14.0.0-240527

# Alien OS apps, launcher, and assets are copied in at build time.
# Replace the placeholder paths with the real Alien OS APKs / files.
# COPY alien-launcher.apk /system/priv-app/AlienLauncher/AlienLauncher.apk
# COPY alien-apps/ /system/app/
# COPY alien-wallpapers/ /system/media/alien/
# COPY alien-boot/ /system/etc/alien/

# Props are set at `docker run` time (see §3), not baked in here,
# so the same image can be run with different screen sizes.
```

Build and run:
```bash
docker build -f Dockerfile.alien-os -t alien-os:14.0.0 .
# then run it exactly as in §3, replacing redroid/redroid:14.0.0-240527
# with alien-os:14.0.0
```

### 6.3 Launcher, apps, and props

- **Launcher:** install the Alien OS launcher APK, then set it as the default home app:
  ```bash
  adb install alien-launcher.apk
  adb shell cmd package set-home-activity <alien.launcher.package>/<alien.launcher.Activity>
  adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
  ```
  Verify the Alien launcher actually appears on boot — do not assume the `set-home-activity` call worked.
- **Alien OS apps:** install each deck / tool as an APK via `adb install`, or place system apps in the image at build time. Keep a list of package names and versions in the repo so a rebuild is reproducible.
- **Props / boot customisation:** pass Android properties on the `docker run` command line (screen size, DPI, GPU mode, `ro.secure`, `ro.debuggable`). For Alien-specific branding / defaults, prefer a first-boot script run via adb (`adb shell` + a setup script pushed to `/data/local/tmp/`) over editing `/system` at runtime.
- **Files in `/data`:** Alien OS data, wordlists / configs for the own-network Wi-Fi Auditor, Comms Lab rules, and Mesh Text settings live under `/home/ubuntu/alien-data` on the host (mounted as `/data`). That is the state to back up.
- **Telegram as the handset:** Telegram is a separate app / client. Install it on Redroid and sign in there; the web prototype's Telegram handset is replaced by the real Telegram Android app on this build.

### 6.4 Keeping root permanently

- **Default (sufficient for v1):** Redroid's `ro.secure=0 ro.debuggable=1` gives adb root (`uid=0`) on every boot. No extra root tool is needed to start. Keep those two properties on every `docker run`.
- **KernelSU-Next (permanent / deeper root path):** the validated upgrade path is KernelSU-Next in the **host** kernel. That is a host-kernel change on the Oracle instance, not a change inside Redroid, and it is a later step — only pursue it once the basic Redroid build in §3–§4 is verified. Do not treat it as a prerequisite for v1.
- **Magisk: do NOT use the bootless / boot-image method on Redroid 13/14 — it is broken there.** Do not spend time on Magisk as the root path for this build. If a Magisk-style module system is ever needed, re-evaluate it against Redroid 14 specifically, with a test container first.
- **Reboot test:** after the overlay is installed, run `docker restart alien-os`, wait 90 seconds, and re-run §4. Root, launcher, and apps must all survive a restart. If they do not, the overlay is not persistent — fix the Dockerfile / `/data` setup, do not re-apply changes by hand each boot.

---

## 7. Common failures

| Failure | Likely cause | Fix |
|---|---|---|
| **"Out of host capacity" in Phoenix** when creating the A1 instance | A1 Free Tier capacity is scarce in `us-phoenix-1` | Try the **2 OCPU / 12 GB** shape first, then another Availability Domain (AD-2 / AD-3), then retry at a different time of day. Do not switch to a paid shape or a paid region to get capacity. |
| **Instance created, then stopped / reclaimed after ~7 days idle** | Oracle reclaims Always Free A1 instances whose CPU utilisation p95 is **< 20% over 7 days** | Keep a light, legitimate workload running, or accept reclamation and rebuild from the Dockerfile + `/home/ubuntu/alien-data` backup. Do not run a fake load loop just to game the metric — if it is reclaimed, rebuild is the documented path. |
| **`binder` / `/dev/binderfs` missing, Redroid container exits or has no binder** | `binder_linux` not loaded, or not loaded with the right devices, or binderfs not mounted | Re-run §2.3, check `ls -l /dev/binderfs/`, check `/etc/modules-load.d/binder.conf` and `/etc/modprobe.d/binder.conf`, reboot and re-check. |
| **Docker not starting / `docker: command not found`** | Docker CE not installed for arm64, or the repo line used the wrong arch / release | Re-run §2.2 exactly, confirm `arch=arm64` and `noble`, run `sudo systemctl status docker`, check `journalctl -u docker`. |
| **`adb connect` refused / `device offline`** | Container still booting, ADB port bound to the wrong interface, or container restarting | Wait 90s, run `docker ps` and `docker logs alien-os --tail 100`, confirm `-p 127.0.0.1:5555:5555`, confirm no other process is using port 5555 on the host. |
| **`adb shell id` is not `uid=0`** | `ro.secure=0 ro.debuggable=1` were not passed, or a different image was run | Stop the container, re-run §3 with those two properties, re-verify with `getprop ro.secure` / `ro.debuggable`. |
| **Black screen / no UI in scrcpy** | GPU mode wrong, or screen size props wrong | Confirm `androidboot.redroid_gpu_mode=guest`, `width=1080 height=2400 dpi=420`, restart the container, re-check `adb shell wm size` / `wm density`. |
| **Out of disk** | Boot volume too small, or `/data` filled with logs / downloads | Use a 100 GB boot volume, run `df -h /` and `docker system df`, prune unused images with `docker image prune -a` (only after noting which images you need). |
| **SSH locked out** | Wrong key, or security list blocks your IP | Check the security list allows SSH from your current IP /32, confirm you are using the right private key, and use the Oracle console serial console as a last resort. |

---

## 8. What is still blocked

1. **Oracle signup — new password.** Set a new password meeting Oracle's rules (8–40 chars, 1 lowercase, 1 uppercase, 1 number, 1 special character; no first name, last name, email address, or spaces). Then the browser can fill both password fields and click Continue.
2. **Oracle signup — remaining steps.** Address, phone, and card identity check. Never enable paid services or agree to a charge without explicit approval.
3. **Instance creation.** §1, subject to capacity (§7). Request 2 OCPU / 12 GB directly.
4. **Install.** §2–§3 on the Oracle instance over SSH.
5. **Verify.** §4–§5. Only after §4 passes is Alien OS "real" on an emulator.
6. **Overlay.** §6 — Alien OS launcher / apps / props on top of the verified Redroid build.

**Do not claim the real OS is running, the emulator is up, or any Alien OS feature is real (calls, radio texts, hardware scans) until §4 has passed on the Oracle instance.** Until then, the existing Alien OS web prototype remains a simulation, labelled as such.

---

*Prepared 2026-11-08. Sources: prior Redroid 14 / Oracle A1 research in this project (no KVM on A1, Redroid 14 arm64, binder_linux, KernelSU-Next / Magisk notes, Oracle Free Tier 2/12 GB change June 2026). Commands were written from that research, not executed on this VM.*
