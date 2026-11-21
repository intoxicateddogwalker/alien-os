# Alien OS

A custom red alien-themed Android OS. Telegram acts as the phone, a real
Android emulator acts as the hardware — and we modify that emulator all the
way down, including at the emulated-hardware level.

## How it works

- **Alien OS** is the Android system itself — red alien theme, AAA-style 3D
  UI, touch-button Settings for root / ADB / hardware, a Linux terminal,
  Kali tools as no-code apps, and Muse at root level.
- **The emulator is Redroid 14 in Docker** — real Android 14 running in a
  container, no KVM needed. ADB on 127.0.0.1:5555, screen over scrcpy.
- **The OS talks to the emulator, the emulator talks to the host computer.**
  See `alien-os-hardware-map.md` for the complete list of every piece of
  Android phone hardware and what the emulator does with it.

## Work on it in GitHub Codespaces (no credit card needed)

1. On this repo, click **Code → Codespaces → Create codespace on main**.
2. It opens a Linux machine with Docker already set up (see
   `.devcontainer/devcontainer.json`).
3. Run `./install-redroid.sh` to start Redroid, then `./verify-redroid.sh`
   to check it, then `./alien-firstboot.sh` for the first Alien OS boot.

Free Codespaces gives 60 hours a month — enough to work on the OS in
sessions. It is not on 24/7; the long-term home is Oracle Always Free
(needs a card for identity verification), documented in
`redroid-install-runbook.md`.

## Files

- `redroid-install-runbook.md` — the full install + deploy runbook.
- `install-redroid.sh` — installs Docker and starts Redroid 14.
- `Dockerfile.alien-os` — Alien OS container image (skeleton: real APKs and
  assets land here as they are built).
- `verify-redroid.sh` — checks the emulator is up and ADB answers.
- `alien-firstboot.sh` — first-boot Alien OS setup.
- `alien-os-hardware-map.md` — complete hardware map: phone → emulator → host.
- `.devcontainer/devcontainer.json` — Codespaces setup (Docker-in-Docker).

## Honest limits

- Redroid has no real radios or sensors: no cellular modem, no GPS, no
  Bluetooth, no NFC, no cameras, no fingerprint reader — all faked in
  software or absent (see the hardware map).
- Graphics are software-rendered; there is no host GPU in a container.
- A full AOSP recompile does not fit in a Codespace or on Oracle Always
  Free (it needs ~400 GB disk / 64 GB RAM). Redroid is how the OS runs
  without rebuilding AOSP.
- Nothing here is fake by design: every feature listed as working must
  actually work. The web prototype that came before this repo was a
  simulation; this repo is the real thing.
