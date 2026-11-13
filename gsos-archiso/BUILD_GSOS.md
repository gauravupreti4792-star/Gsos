# BUILD_GSOS.md — build `GSOS.iso` from Windows (Arch on WSL2 or VirtualBox)

Expect **30–90 minutes** and **~25 GB free disk**, **8 GB+ RAM** for the build. Nothing here has been run end to end yet, so treat the first build as a debugging run and read the troubleshooting section at the bottom.

Everything marked `YOURNAME` is your Windows user name. `$WIN` is the Windows folder that holds your GSOS files.

---

## 0. What goes where on your Windows PC

Put this on your Windows drive, for example `C:\Users\YOURNAME\GSOS\`:

```
GSOS\
├── gsos-archiso\                  <- the folder from this answer (packages.x86_64, airootfs\, BUILD_GSOS.md)
└── yours\
    ├── gsos-profile-switcher      <- your existing file, untouched
    ├── gsos-theme-installer       <- your existing file, untouched
    ├── gsos-profile-menu          <- optional, from your v1.1.0 tree
    ├── metadata.json              <- your existing plasmoid/metadata.json
    └── gsos-profile-manager.desktop   <- optional, from your v1.1.0 tree
```

**Save the two scripts with Unix line endings (LF).** In VS Code: click `CRLF` in the bottom-right bar and choose `LF`, then save. CRLF breaks bash scripts (`bad interpreter: ^M`).

---

## 1. Prepare Arch Linux

### Option A — WSL2 (recommended)

In **PowerShell** (not admin needed):

```powershell
wsl --update
wsl --install archlinux
```

Open "Arch Linux" from the Start menu. (Give WSL enough resources: create `C:\Users\YOURNAME\.wslconfig` with the lines below, then run `wsl --shutdown` once.)

```ini
[wsl2]
memory=8GB
swap=8GB
processors=4
```

### Option B — VirtualBox

Create an Arch VM (4+ cores, 8 GB RAM, 60 GB disk), install Arch with `archinstall`, and add a Shared Folder pointing at `C:\Users\YOURNAME\GSOS` (auto-mount). Then use the same commands below; replace `/mnt/c/Users/YOURNAME/GSOS` with your shared-folder path (e.g. `/media/sf_GSOS`).

### Inside Arch (both options), as root:

```bash
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm
pacman -S --noconfirm --needed archiso base-devel git sudo

# makepkg refuses to run as root, so create a build user
useradd -m -G wheel builder
passwd builder
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
su - builder
```

From here on you are the `builder` user.

---

## 2. Set your paths

```bash
export WIN=/mnt/c/Users/YOURNAME/GSOS        # change YOURNAME (VirtualBox: your shared folder)
ls "$WIN/gsos-archiso" "$WIN/yours"          # sanity check: both must list files
```

---

## 3. Build Calamares into a local repo (it is not in the official Arch repos)

```bash
sudo install -d -o builder -g builder /opt/gsos-localrepo
mkdir -p ~/aur && cd ~/aur
export MAKEFLAGS="-j2"

for p in ckbcomp calamares; do
  git clone "https://aur.archlinux.org/$p.git"
  ( cd "$p" && makepkg -si --noconfirm --needed )
  cp "$p"/*.pkg.tar.zst /opt/gsos-localrepo/
done

repo-add /opt/gsos-localrepo/gsos-local.db.tar.gz /opt/gsos-localrepo/*.pkg.tar.zst
```

If `makepkg` stops because another AUR dependency is missing, build that one the same way (clone, `makepkg -si`, copy the `.pkg.tar.zst` into `/opt/gsos-localrepo/`, run `repo-add` again), then retry. The same trick works for any package that `mkarchiso` later reports as "target not found" (for example `waydroid` if it is not in your mirror's `extra`).

> Shortcut: the third-party Chaotic-AUR repo ships prebuilt `calamares`. It saves build time but means trusting a third party's binaries inside your ISO, so this recipe builds from source.

---

## 4. Assemble the archiso profile

```bash
mkdir -p ~/gsos-build && cd ~/gsos-build
rm -rf gsos-archiso
cp -r /usr/share/archiso/configs/releng ./gsos-archiso

# 4a. Overlay the GSOS files (packages.x86_64 + airootfs/)
cp -r "$WIN/gsos-archiso/." ./gsos-archiso/
rm -f ./gsos-archiso/BUILD_GSOS.md

# 4b. Add your existing files (not modified)
cd gsos-archiso/airootfs
install -Dm755 "$WIN/yours/gsos-profile-switcher"  usr/local/bin/gsos-profile-switcher
install -Dm755 "$WIN/yours/gsos-theme-installer"   usr/local/bin/gsos-theme-installer
[ -f "$WIN/yours/gsos-profile-menu" ] && install -Dm755 "$WIN/yours/gsos-profile-menu" usr/local/bin/gsos-profile-menu
install -Dm644 "$WIN/yours/metadata.json" usr/share/plasma/plasmoids/org.gsos.profilemanager/metadata.json
[ -f "$WIN/yours/gsos-profile-manager.desktop" ] && install -Dm644 "$WIN/yours/gsos-profile-manager.desktop" usr/share/applications/org.gsos.profilemanager.desktop
sed -i 's/\r$//' usr/local/bin/* root/customize_airootfs.sh        # strip any CRLF just in case
cd ../..

# 4c. Switch the kernel to linux-zen (Waydroid needs binder support)
rm -f gsos-archiso/airootfs/etc/mkinitcpio.d/linux.preset
grep -rl 'vmlinuz-linux\|initramfs-linux' gsos-archiso/syslinux gsos-archiso/grub gsos-archiso/efiboot 2>/dev/null \
  | xargs -r sed -i 's/vmlinuz-linux\b/vmlinuz-linux-zen/g; s/initramfs-linux\.img/initramfs-linux-zen.img/g'

# 4d. Enable multilib (for 32-bit Wine) and add the local Calamares repo
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' gsos-archiso/pacman.conf
cat >> gsos-archiso/pacman.conf <<'EOF'

[gsos-local]
SigLevel = Optional TrustAll
Server = file:///opt/gsos-localrepo
EOF

# 4e. Name the ISO
sed -i 's/^iso_name=.*/iso_name="gsos"/; s/^iso_label=.*/iso_label="GSOS_LIVE"/' gsos-archiso/profiledef.sh

# 4f. Quick checks
grep -n 'multilib' -A1 gsos-archiso/pacman.conf | head
grep -rn 'vmlinuz' gsos-archiso/syslinux/*.cfg | head -3
```

---

## 5. Build the ISO

Build in the Linux filesystem (not under `/mnt/c`, which is slow and breaks file permissions):

```bash
cd ~/gsos-build
sudo rm -rf /tmp/gsos-work
sudo mkarchiso -v -w /tmp/gsos-work -o ~/gsos-build/out ./gsos-archiso 2>&1 | tee ~/gsos-build/build.log
ls -lh ~/gsos-build/out/
```

---

## 6. Copy `GSOS.iso` to your Windows drive

```bash
cp ~/gsos-build/out/gsos-*.iso "$WIN/GSOS.iso"
sha256sum ~/gsos-build/out/gsos-*.iso "$WIN/GSOS.iso"     # both lines must match
```

It now sits at `C:\Users\YOURNAME\GSOS\GSOS.iso`.

---

## 7. Test it before touching real hardware

- **QEMU / virt-manager or VMware** with 3D acceleration is the most reliable test for Plasma Wayland.
- **VirtualBox**: new VM, type Linux / Arch Linux (64-bit), 4 GB RAM, 2 CPUs, **Enable EFI**, graphics controller **VMSVGA** with 128 MB video memory, attach `GSOS.iso`. Plasma on Wayland can show a black screen in VirtualBox; if so, test in QEMU or on a USB stick instead.
- **USB stick**: use **Rufus** and choose **DD Image mode** when asked (or use Ventoy). Double-check the target drive; it will be erased.

Expected flow on the live ISO: auto-login as `liveuser` → first-login script applies the auto profile, macOS theme and the dock/top-bar layout → Calamares opens (there is also an "Install GSOS" desktop icon).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `error: target not found: <pkg>` | Build that package from the AUR into `/opt/gsos-localrepo` (step 3), or remove it from `packages.x86_64`. |
| `bad interpreter: /usr/bin/env bash^M` | A script has Windows line endings. Re-run the `sed -i 's/\r$//'` line from step 4b. |
| `mkarchiso` fails with mount or permission errors on WSL | Make sure you are on WSL2 (`wsl -l -v` shows VERSION 2) and that you build under `~`, not `/mnt/c`. If it still fails, use the VirtualBox route. |
| Theme missing on the ISO | The theme installer needs internet inside the chroot. Check `build.log` for `[GSOS] WARNING: theme installer failed`, fix the network, rebuild. |
| Dock/top bar not created | See `~/.cache/gsos-first-login.log` on the live system. The Plasma scripting calls are written from memory for Plasma 6 and may need a property tweak for your exact Plasma version. |
| Calamares installs but won't boot | The Calamares config in `airootfs/etc/calamares/` is a starter. Check `/var/log/Calamares.log` and the `shellprocess-gsos-prep.conf` steps first. |
| Waydroid won't start | It needs the `linux-zen` kernel with binder; confirm with `uname -r` showing `zen`, then run `sudo waydroid init`. |

After each rebuild: `sudo rm -rf /tmp/gsos-work` first, otherwise stale files are reused.
