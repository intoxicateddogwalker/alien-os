# Alien OS — Complete Hardware Map

**What this is:** every piece of hardware on an Android mobile device, and what
happens to it in our setup — Alien OS talks to the emulator, the emulator talks
to the host computer. Our emulator is **Redroid 14 in a Docker container**
(no KVM, no real phone hardware). Where Redroid and the classic Android
Emulator (QEMU + KVM) differ, it is marked.

**How to read it:** for each item — what it is on a real phone → what the
emulator does with it → what it touches on the host computer. Three states:
**REAL** (host hardware is really used), **EMULATED** (software pretends it
is there), **ABSENT** (Android sees nothing, or a dead stub).

**The short version:** on the host computer, Redroid touches exactly four
things — CPU cores, RAM, disk, and the network interface. Everything else
(cellular, GPS, cameras, sensors, Bluetooth, NFC, fingerprint) is faked in
software inside the container. A real phone has ~40 hardware pieces; in
Redroid, 4 are real and the rest are emulated or absent.

---

## 1. Compute

| Hardware (real phone) | Emulator (Redroid) | Host computer |
|---|---|---|
| CPU — ARM64 SoC (Snapdragon / Exynos / MediaTek / Tensor), 8 cores | EMULATED — Android runs on the host CPU directly (same ARM64), no translation; container capped at 2 CPUs | REAL — host CPU cores (Codespaces: 2–4 vCPUs) |
| GPU — Adreno / Mali / Immortalis | EMULATED — software rendering (Mesa/llvmpipe); no host GPU is used | ABSENT — no GPU passthrough in a container |
| RAM — 8–16 GB LPDDR5 | EMULATED — a slice of host RAM; container capped at 4 GB | REAL — host RAM |
| Storage — UFS 3.1/4.0 internal flash, 128–512 GB | EMULATED — a disk image file on the host | REAL — host disk (Codespaces: 32 GB) |
| microSD card slot | EMULATED — a folder/image presented as external storage | REAL — host disk |
| Hardware crypto / TEE / StrongBox / Titan M | ABSENT — software keystore only; no secure element | ABSENT |

## 2. Display and input

| Hardware (real phone) | Emulator (Redroid) | Host computer |
|---|---|---|
| Display panel — OLED/AMOLED, 1080×2400, 120 Hz | EMULATED — virtual display at the size/density we set (device identity is fully configurable in Redroid) | ABSENT — no screen attached; you see it over scrcpy / VNC / web viewer |
| Touchscreen — capacitive multi-touch, 10 points | EMULATED — touch events come from the viewer (mouse clicks become touches) | REAL — host mouse/keyboard, via the viewer |
| Power button, volume buttons | EMULATED — key events sent over ADB | REAL — host keyboard, via ADB commands |
| Home / back / recent (gestures or buttons) | EMULATED — Android gesture nav, driven by ADB/input commands | REAL — host keyboard, via ADB commands |
| Stylus / S Pen | ABSENT | ABSENT |

## 3. Sensors (all of them)

Real Android phones expose these sensors; Redroid's sensor HAL is a stub,
so Android sees them as present-but-empty unless a value is fed in by hand.
None of them touch host hardware.

| Sensor | Real phone | Redroid | Host |
|---|---|---|---|
| Accelerometer | REAL | EMULATED (stub, no motion) | ABSENT |
| Gyroscope | REAL | EMULATED (stub) | ABSENT |
| Magnetometer (compass) | REAL | EMULATED (stub) | ABSENT |
| Barometer (air pressure) | REAL | EMULATED (stub) | ABSENT |
| Proximity sensor | REAL | EMULATED (stub) | ABSENT |
| Ambient light sensor | REAL | EMULATED (stub) | ABSENT |
| Step counter / step detector | REAL | EMULATED (stub) | ABSENT |
| Gravity sensor | REAL | EMULATED (stub) | ABSENT |
| Linear acceleration | REAL | EMULATED (stub) | ABSENT |
| Rotation vector | REAL | EMULATED (stub) | ABSENT |
| Game rotation vector | REAL | EMULATED (stub) | ABSENT |
| Geomagnetic rotation vector | REAL | EMULATED (stub) | ABSENT |
| Significant motion | REAL | EMULATED (stub) | ABSENT |
| Heart rate sensor | REAL (some phones) | ABSENT | ABSENT |
| Body temperature / ambient temperature | REAL (some phones) | ABSENT | ABSENT |
| Relative humidity | REAL (some phones) | ABSENT | ABSENT |
| Hinge angle (foldables) | REAL (foldables) | ABSENT | ABSENT |
| Hall sensor (flip cover) | REAL (some phones) | ABSENT | ABSENT |
| Grip / squeeze sensor | REAL (some phones) | ABSENT | ABSENT |

Classic Android Emulator (QEMU) is different here: its virtual sensors can be
driven from the emulator console, so it can fake motion, GPS and light. Redroid
cannot — its sensors stay still unless we write a feeder for them later.

## 4. Location

| Hardware (real phone) | Emulator (Redroid) | Host computer |
|---|---|---|
| GPS / GNSS receiver (GPS, GLONASS, Galileo, BeiDou) | ABSENT — no satellite fix; location must be fed in by hand if an app needs it | ABSENT — the host has no GPS |
| Network location (Wi-Fi / cell towers) | EMULATED — Android can be given a fixed location | ABSENT |

## 5. Radios

| Hardware (real phone) | Emulator (Redroid) | Host computer |
|---|---|---|
| Cellular modem / baseband (2G / 3G / 4G LTE / 5G) | ABSENT — no modem, no calls, no SMS, no mobile data; telephony is a stub | ABSENT — the host has no modem |
| SIM card / eSIM | ABSENT — no SIM slot; telephony stub reports no SIM | ABSENT |
| Wi-Fi (802.11 a/b/g/n/ac/ax) | EMULATED — Android sees a Wi-Fi network; behind it is the container's wired network | REAL — host network interface (the container's eth0, NAT/bridged) |
| Bluetooth (Classic + LE) | ABSENT — no Bluetooth radio, no pairing, no BLE scan | ABSENT — host Bluetooth is not passed into the container |
| NFC | ABSENT — no NFC chip, no tap-to-pay, no tags | ABSENT |
| Ultra-wideband (UWB) | ABSENT | ABSENT |
| FM radio receiver | ABSENT | ABSENT |
| IR blaster | ABSENT | ABSENT |

## 6. Cameras

| Hardware (real phone) | Emulator (Redroid) | Host computer |
|---|---|---|
| Rear camera(s) — main, ultra-wide, telephoto | ABSENT — no camera device; camera apps see nothing | ABSENT — host webcam is NOT passed in (classic Emulator can pass a webcam; Redroid cannot) |
| Front camera | ABSENT | ABSENT |
| LED flash / torch | ABSENT | ABSENT |
| Depth / ToF sensor, LiDAR | ABSENT | ABSENT |

## 7. Audio

| Hardware (real phone) | Emulator (Redroid) | Host computer |
|---|---|---|
| Microphone(s) | ABSENT — no mic device; voice input gets silence | ABSENT — host mic is not passed in |
| Speaker / loudspeaker | ABSENT — no audio output device | ABSENT — host speakers are not used |
| Earpiece | ABSENT | ABSENT |
| 3.5 mm headphone jack / USB-C audio | ABSENT | ABSENT |

## 8. Biometrics and security

| Hardware (real phone) | Emulator (Redroid) | Host computer |
|---|---|---|
| Fingerprint sensor (under-display / side / rear) | ABSENT — no sensor; the classic Emulator fakes it from the console, Redroid does not | ABSENT |
| Face unlock (3D / IR) | ABSENT | ABSENT |
| Iris scanner | ABSENT | ABSENT |
| Hardware keystore / StrongBox / TEE | ABSENT — software keystore only | ABSENT |

## 9. Power

| Hardware (real phone) | Emulator (Redroid) | Host computer |
|---|---|---|
| Battery (Li-ion, 4,000–5,500 mAh) | EMULATED — Android is told a fake charge level; it never runs down | ABSENT — no battery |
| Charging — wired USB-C, wireless, reverse | EMULATED — always "charging" in the fake state | ABSENT |
| USB-C port (data, OTG, DisplayPort) | EMULATED — ADB over TCP on port 5555 is how we reach it; no real USB | REAL — host network only (ADB is TCP, not USB) |

## 10. Haptics and misc

| Hardware (real phone) | Emulator (Redroid) | Host computer |
|---|---|---|
| Vibration motor / haptics | ABSENT — vibrate calls do nothing; the host does not shake | ABSENT |
| Notification LED | ABSENT | ABSENT |
| Notification light / always-on display | EMULATED — screen only | ABSENT |

---

## What the emulator actually touches on the host computer

The complete list — this is everything Redroid uses on the host, and nothing
else:

1. **CPU** — 2 cores (capped) of the host's processor, running Android's ARM64 code directly.
2. **RAM** — 4 GB (capped) of host memory.
3. **Disk** — the container image (~800 MB), the Android data image, and the host folder we mount for files.
4. **Network interface** — the host's internet connection, shared into the container as a virtual wired network (this is what Android sees as "Wi-Fi").

That is all. No screen, no keyboard, no mouse, no camera, no mic, no GPS,
no cellular modem, no Bluetooth, no NFC, no fingerprint reader, no battery —
none of those exist on the host in a form the container can use, so they are
all faked in software or missing, exactly as listed above.

## What changes if we switch emulators

- **Classic Android Emulator (QEMU + KVM)** can do more: host webcam as the
  camera, host mic/speakers for audio, virtual fingerprint from the console,
  virtual sensors and GPS driven from the console, host Bluetooth in some
  setups. It needs KVM (real virtualization) — Codespaces and Oracle A1 do
  not have it, which is why we use Redroid.
- **A real phone** has all of it for real — that is the end goal for Alien OS
  if it ever runs on hardware instead of an emulator.

## Where this list lives

- Repo: `intoxicateddogwalker/alien-os` (this file: `alien-os-hardware-map.md`)
- Local: `~/workspace/goals/alien-os/files/alien-os-hardware-map.md`
- Built from: AOSP hardware list + Redroid 14 container behavior + the
  Alien OS deployment pack (Redroid in Docker, ADB on 127.0.0.1:5555,
  container capped 4 GB / 2 CPUs).
