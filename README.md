# GSOS (Arch Linux)

GSOS is a custom Arch Linux-based operating system designed as a clean, reliable daily-driver built with `mkarchiso` and GitHub Actions. It pairs a custom dark slate-and-electric-blue aesthetic with locked KDE/KWin settings, a bottom taskbar layout, custom desktop utilities, and Calamares installer integration.

---

## Screenshots

| Desktop & Custom Wallpaper | Application Launcher | GSOS Store |
| :---: | :---: | :---: |
| ![GSOS Desktop](1795178828224.png) | ![GSOS Launcher](1795178832022.jpg) | ![GSOS Store](1795178814912.png) |

---

## Key Features & Stack

* **Base & Kernel:** Built on Arch Linux with `mkarchiso` and the `linux-zen` kernel.
* **Visual Identity & UI:** Custom dark slate palette with electric-blue accents, `Papirus-Dark` icons, custom wallpaper/logos/splash screen (`org.gsos.splash`), and right-aligned window controls (`IAX`).
* **Immutable Settings:** Read-only KDE/KWin configuration keys (`[$i]`) and Kiosk restrictions to keep core appearance settings consistent.
* **First-Login Setup:** Automated once-per-user initialization (`gsos-first-login.sh`) for performance profile selection, Flathub setup, `plasmashell` panel/taskbar layout, wallpaper application, and launching Calamares on the live ISO.
* **Custom Apps (Python / PyQt6):**
  * **GSOS Store (`gsos-store.py`):** Curated app browser and manager backed by Flatpak/Flathub.
  * **About GSOS (`gsos-about.py`):** System and hardware summary tool with hostname renaming and clipboard copy support.
* **Installer & Target Prep:** Calamares branding and post-install chroot preparation (`shellprocess-gsos-prep.conf`) to transition from the live ISO environment to a standard installed system.

---

## Repository Structure

```text
├── .github/
│   └── workflows/
│       └── build gsos.yml          # GitHub Actions workflow ("Build GSOS ISO")
├── gsos-archiso/
│   ├── airootfs/                   # Live filesystem overlay (etc, root, usr)
│   ├── scripts/
│   │   └── gsos-theme.sh           # Main theme, apps, autostart, and branding bundle script
│   ├── BUILD_GSOS.md               # Build documentation/notes
│   └── packages.x86_64             # Archiso package list
├── yours/
│   ├── gsos-profile-switcher       # Performance profile utility
│   ├── gsos-theme-installer        # Theme installer script
│   └── metadata.json               # Custom metadata
├── BUILD_GSOS.md
├── LICENSE
└── README.md
