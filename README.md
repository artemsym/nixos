# gothness/nixos

NixOS configuration for a single workstation running niri + ClavisShell.

## Hardware

- CPU: Intel Core i7-9700K
- GPU: NVIDIA GeForce RTX 2070 (proprietary drivers)
- Display: ASUS VG2791R (HDMI-A-1, 144Hz) + Samsung LC27RG50 (DP-1, 240Hz)

## Stack

- **Compositor**: niri (Wayland scrolling WM)
- **Shell**: ClavisShell (quickshell-based, QML)
- **Display manager**: ly
- **Terminal**: foot
- **Prompt**: starship
- **Wallpaper**: linux-wallpaperengine (Steam Workshop)
- **Proxy**: v2rayA

## Notable: First NixOS derivation for ClavisShell

`clavis-shell.nix` is believed to be the first published Nix derivation
for [StatIndet/quickshell](https://github.com/StatIndet/quickshell)
(ClavisShell), a quickshell-based desktop shell with niri compositor support.

### What makes it non-trivial

- **libcava**: not available in nixpkgs as a library — built from source
  with a hand-written pkg-config file
- **M3Shapes**: `qt_add_qml_module` without `LIBRARY_OUTPUT_DIRECTORY`
  causes the backing `libM3Shapes.so` to land outside the install tree —
  patched with `substituteInPlace`
- **Runtime paths**: QML import paths and shared library paths wired via
  a wrapper script

## Structure

flake.nix — system + home-manager flake
configuration.nix — NixOS system config
home.nix — home-manager user config
hardware-configuration.nix
niri-config.kdl — niri compositor config
waybar-style.css — waybar theme (kept for reference)
clavis-shell.nix — ClavisShell derivation


## Usage

```bash
sudo nixos-rebuild switch --flake .#gothness
```
