GSOS (Arch Linux)


​GSOS is a custom Arch Linux-based operating system designed as a clean, reliable daily-driver built with mkarchiso and GitHub Actions. It pairs a custom dark slate-and-electric-blue aesthetic with locked KDE/KWin settings, a bottom taskbar layout, custom desktop utilities, and Calamares installer integration.


​Key Features & Stack





​Base & Kernel: Built on Arch Linux with mkarchiso and the linux-zen kernel.




​Visual Identity & UI: Custom dark slate palette with electric-blue accents, Papirus-Dark icons, custom wallpaper/logos/splash screen (org.gsos.splash), and right-aligned window controls (IAX).




​Immutable Settings: Read-only KDE/KWin configuration keys ([$i]) and Kiosk restrictions to keep core appearance settings consistent.




​First-Login Setup: Automated once-per-user initialization (gsos-first-login.sh) for performance profile selection, Flathub setup, plasmashell panel/taskbar layout, wallpaper application, and launching Calamares on the live ISO.




​Custom Apps (Python / PyQt6):




​GSOS Store (gsos-store.py): Curated app browser and manager backed by Flatpak/Flathub.




​About GSOS (gsos-about.py): System and hardware summary tool with hostname renaming and clipboard copy support.








​Installer & Target Prep: Calamares branding and post-install chroot preparation (shellprocess-gsos-prep.conf) to transition from the live ISO environment to a standard installed system.
