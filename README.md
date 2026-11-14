# GSOS

**A macOS-inspired Linux distribution for low-end PCs, with Windows and Android app support.**

GSOS is an experimental Arch Linux–based live ISO. It combines a KDE Plasma 6 (Wayland) desktop styled after macOS with adaptive performance profiles, so it stays smooth on modest hardware.

> **Status: early test build.** The ISO builds automatically with GitHub Actions. Boot testing and tuning are in progress, so expect rough edges.

## Features

- **macOS-style desktop:** KDE Plasma 6 with the WhiteSur theme, icons and cursors, a floating dock and a top menu bar.
- **Adaptive performance profiles:** `Lite`, `Smooth`, `Balanced` and `Liquid` profiles, chosen automatically from your hardware or switched by hand with a Plasma widget. Lite turns off effects for very low-end PCs.
- **Windows apps:** Wine and Winetricks are included.
- **Android apps:** Waydroid is included.
- **Local AI (optional):** Ollama is included for the GSPI assistant.
- **Installer:** Calamares graphical installer on the live ISO.
- **Kernel:** `linux-zen`, which Waydroid needs for binder support.

## Repository layout

```
.
├── .github/workflows/build-gsos.yml   # builds the ISO in an Arch Linux container
├── gsos-archiso/                      # archiso profile overlay
│   ├── packages.x86_64                # packages installed on the ISO
│   └── airootfs/                      # files copied into the live system
├── yours/                             # core scripts and widget metadata
│   ├── gsos-profile-switcher          # applies a performance profile
│   ├── gsos-theme-installer           # installs and applies the macOS theme
│   └── metadata.json                  # Plasma widget metadata
└── BUILD_GSOS.md                      # manual build guide (WSL2 / VirtualBox)
```

## Build the ISO (GitHub Actions)

1. Open the **Actions** tab.
2. Select **Build GSOS ISO**, then **Run workflow** on the `main` branch.
3. When the run finishes (roughly 1–3 hours on the free runner), download **GSOS-iso** from the **Artifacts** section of the run's Summary page. Artifacts expire after 7 days.

To build on your own machine instead, follow [BUILD_GSOS.md](BUILD_GSOS.md).

## Try it

1. Unzip the download to get `GSOS.iso`.
2. Test in a virtual machine first (VMware or QEMU with 3D acceleration recommended, 4 GB RAM, 2 CPUs, EFI enabled).
3. For real hardware, write the ISO to a USB stick with Rufus in **DD Image mode** (or Ventoy), then boot from it.

## Known limitations

- Wine runs many Windows apps but not all (some Adobe, Office and anti-cheat games fail).
- The Calamares install-to-disk configuration is a starter and still needs testing.
- The dock and menu-bar layout script and the GTK theme step are still being debugged.
- Waydroid needs a Wayland session and works best on real hardware.
- This is not macOS, and is not affiliated with or endorsed by Apple Inc.

## Credits

- [Arch Linux](https://archlinux.org) and [archiso](https://gitlab.archlinux.org/archlinux/archiso)
- [KDE Plasma](https://kde.org/plasma-desktop/)
- [WhiteSur themes](https://github.com/vinceliuice) by vinceliuice
- [Calamares](https://calamares.io), [Wine](https://www.winehq.org), [Waydroid](https://waydro.id) and [Ollama](https://ollama.com)

## About this project

GSOS was developed with AI assistance (ChatGPT and Claude) and debugged and tested by the author.

## License

License to be decided. Until a license file is added, all rights are reserved by the author.
