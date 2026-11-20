#!/usr/bin/env bash
# =====================================================================
#  hyprunity installer
#
#  Arch Linux (x86_64) only. Installs the packages hyprunity uses, then
#  copies the configs into ~/.config and the helper scripts into
#  ~/.local/bin. Before touching anything it asks whether to run a full
#  system update and whether to back up the files it replaces. Backups go
#  to ~/.local/state/hyprunity/install-backup-<timestamp>; if you decline,
#  replaced files are deleted instead. Your wallpaper folder is never touched.
# =====================================================================
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$REPO_DIR/dotfiles/config"
BIN_SRC="$REPO_DIR/dotfiles/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.local/state/hyprunity/install-backup-$STAMP"

if [ -t 1 ]; then
  B=$'\033[1m'
  G=$'\033[32m'
  Y=$'\033[33m'
  R=$'\033[31m'
  D=$'\033[2m'
  N=$'\033[0m'
else
  B=""
  G=""
  Y=""
  R=""
  D=""
  N=""
fi

log() { printf '%s==>%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s==>%s %s\n' "$Y" "$N" "$*"; }
die() {
  printf '%s==>%s %s\n' "$R" "$N" "$*" >&2
  exit 1
}

# ── 1. platform checks ──────────────────────────────────────────────
[ "$(uname -s)" = "Linux" ] || die "This installer only supports Linux."
[ "$(uname -m)" = "x86_64" ] || die "hyprunity currently supports x86_64 only (found $(uname -m))."
[ -f /etc/arch-release ] || die "This installer targets Arch Linux (or an Arch-based distro). /etc/arch-release not found."
command -v pacman >/dev/null 2>&1 || die "pacman not found. Is this really an Arch-based system?"
[ "$(id -u)" -ne 0 ] || die "Run this as your normal user, not as root. sudo is used where needed."
command -v sudo >/dev/null 2>&1 || die "sudo is required."
[ -d "$CONFIG_SRC" ] && [ -d "$BIN_SRC" ] || die "dotfiles/ is missing. Run the script from the repository root."

log "Target: $(. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-Arch Linux}") · $(uname -m)"

# ── 2. choices ──────────────────────────────────────────────────────
# Defaults are "yes" so a non-interactive run (piped, CI, sandbox) behaves like
# the original installer. Interactive runs get a real choice.
FULL_UPDATE=1
BACKUP=1
if [ -t 0 ]; then
  printf '%s==>%s Run a full system update first (pacman -Syu)? [Y/n] ' "$G" "$N"
  read -r reply || reply=""
  case "$reply" in
    [nN]*) FULL_UPDATE=0 ;;
  esac

  printf '%s==>%s Back up the config files this installer replaces? [Y/n] ' "$G" "$N"
  read -r reply || reply=""
  case "$reply" in
    [nN]*) BACKUP=0 ;;
  esac
fi

if [ "$BACKUP" -eq 1 ]; then
  log "Backups will go to ${BACKUP_DIR/#$HOME/\~}"
else
  warn "Backups are off: replaced files will be deleted."
fi

# ── 3. packages ─────────────────────────────────────────────────────
PACMAN_PKGS=(
  hyprland
  quickshell
  hypridle
  hyprpolkitagent
  hyprsunset
  hyprpicker
  xdg-desktop-portal
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
  xdg-utils
  gnome-keyring
  polkit
  wl-clipboard
  cliphist
  brightnessctl
  networkmanager
  bluez
  bluez-utils
  upower
  libnotify
  grim
  slurp
  kitty
  matugen
  python
  lua
  ydotool
  gpu-screen-recorder
  spotify-launcher
  nautilus
  pavucontrol
  ttf-jetbrains-mono-nerd
  qt6ct
  pacman-contrib
  neovim
  git
  base-devel
)

# Audio is only pulled in when the system does not already have PipeWire.
if ! command -v wpctl >/dev/null 2>&1; then
  PACMAN_PKGS+=(pipewire pipewire-pulse wireplumber)
fi

AUR_PKGS=(
  zen-browser-bin
  bibata-cursor-theme-bin
  adw-gtk3
)

log "Installing official packages…"
if [ "$FULL_UPDATE" -eq 1 ]; then
  log "Running a full system update (pacman -Syu)."
  sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}"
else
  log "Skipping the full system update (pacman -S)."
  sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
fi

AUR_HELPER=""
for helper in yay paru; do
  if command -v "$helper" >/dev/null 2>&1; then
    AUR_HELPER="$helper"
    break
  fi
done

if [ -n "$AUR_HELPER" ]; then
  log "Installing AUR packages with $AUR_HELPER…"
  "$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"
else
  warn "No AUR helper (yay/paru) found. Install these when you can:"
  printf '    %s\n' "${AUR_PKGS[*]}"
  warn "The shell works without them; the browser and cursor theme will be missing."
fi

# UnityAgent uses ydotool to move the pointer and click. The package ships a
# user service (ydotoold) plus a udev rule for /dev/uinput; enable the service
# for the current user so the agent can inject input without root.
if command -v ydotool >/dev/null 2>&1; then
  log "Enabling the ydotool daemon for UnityAgent mouse control…"
  if ! id -nG "$(id -un)" | tr ' ' '\n' | grep -qx input; then
    log "Adding $(id -un) to the input group (ydotoold needs /dev/uinput)…"
    sudo usermod -aG input "$(id -un)" ||
      warn "Could not add $(id -un) to the input group. Run: sudo usermod -aG input $(id -un)"
  fi
  sudo modprobe uinput >/dev/null 2>&1 ||
    warn "Could not load the uinput module; mouse control may need a reboot."
  if systemctl --user enable --now ydotool.service >/dev/null 2>&1; then
    log "ydotoold is running as a user service."
  else
    warn "Could not start ydotoold yet. After logging out and back in, run: systemctl --user enable --now ydotool.service"
  fi
else
  warn "ydotool was not installed; UnityAgent mouse control will be unavailable."
fi

# ── 4. backups ──────────────────────────────────────────────────────
backup_path() {
  local path="$1"
  [ -e "$path" ] || [ -L "$path" ] || return 0
  if [ "$BACKUP" -ne 1 ]; then
    rm -rf -- "$path"
    return 0
  fi
  local rel="${path#"$HOME"/}"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  mv "$path" "$BACKUP_DIR/$rel"
  log "Backed up ${path/#$HOME/\~}"
}

copy_item() {
  local src="$1" dst="$2"
  [ -e "$src" ] || die "Missing source: $src"
  backup_path "$dst"
  install -d "$(dirname "$dst")"
  cp -a "$src" "$dst"
}

# ── 5. configs ──────────────────────────────────────────────────────
log "Installing Quickshell config…"
copy_item "$CONFIG_SRC/quickshell/hyprunity" "$HOME/.config/quickshell/hyprunity"

log "Installing Hyprland config…"
# Hyprland 0.55+ uses hyprland.lua when it exists; the old .conf would
# otherwise keep loading. Move it aside (backed up, never deleted).
if [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
  backup_path "$HOME/.config/hypr/hyprland.conf"
  warn "Moved hyprland.conf aside — hyprunity uses the Lua config (Hyprland 0.55+)."
fi
copy_item "$CONFIG_SRC/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
copy_item "$CONFIG_SRC/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
copy_item "$CONFIG_SRC/hypr/hyprunity" "$HOME/.config/hypr/hyprunity"

log "Installing shell settings + UnityAgent…"
copy_item "$CONFIG_SRC/hyprunity" "$HOME/.config/hyprunity"

log "Installing matugen templates…"
copy_item "$CONFIG_SRC/matugen" "$HOME/.config/matugen"

log "Installing helper scripts…"
install -d "$HOME/.local/bin"
for src in "$BIN_SRC"/*; do
  [ -f "$src" ] || continue
  dst="$HOME/.local/bin/$(basename "$src")"
  backup_path "$dst"
  install -m 0755 "$src" "$dst"
done

# ── 6. runtime folders and small integrations ───────────────────────
install -d "$HOME/.local/state/hyprunity" \
  "$HOME/.local/state/quickshell/user/generated" \
  "$HOME/.config/gtk-3.0" \
  "$HOME/.config/gtk-4.0" \
  "$HOME/.config/kitty"

# kitty only reads the generated palette if its config includes it.
KITTY_CONF="$HOME/.config/kitty/kitty.conf"
if [ ! -f "$KITTY_CONF" ]; then
  printf '# Generated by the hyprunity installer\ninclude hyprunity-theme.conf\n' >"$KITTY_CONF"
  log "Created ~/.config/kitty/kitty.conf with the hyprunity palette include."
elif ! grep -qE '^[[:space:]]*include[[:space:]]+hyprunity-theme\.conf' "$KITTY_CONF"; then
  if [ "$BACKUP" -eq 1 ]; then
    mkdir -p "$BACKUP_DIR/.config/kitty"
    cp "$KITTY_CONF" "$BACKUP_DIR/.config/kitty/kitty.conf"
  fi
  printf '\n# hyprunity palette\ninclude hyprunity-theme.conf\n' >>"$KITTY_CONF"
  if [ "$BACKUP" -eq 1 ]; then
    log "Added the hyprunity palette include to kitty.conf (original in the backup folder)."
  else
    log "Added the hyprunity palette include to kitty.conf."
  fi
fi

# ── 7. system services ──────────────────────────────────────────────
if systemctl list-unit-files NetworkManager.service >/dev/null 2>&1; then
  sudo systemctl enable --now NetworkManager.service >/dev/null 2>&1 ||
    warn "Could not enable NetworkManager.service."
fi
if systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
  sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 ||
    warn "Could not enable bluetooth.service."
fi

# ── 8. start / reload ───────────────────────────────────────────────
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  hyprctl reload >/dev/null 2>&1 || true
  if qs ipc -c hyprunity call shell reload >/dev/null 2>&1; then
    log "Reloaded the running hyprunity shell."
  else
    (setsid sh -c 'exec qs -c hyprunity >"$HOME/.local/state/hyprunity/shell.log" 2>&1' >/dev/null 2>&1 &)
    log "Started hyprunity."
  fi
  # The agent runs as a separate Python process, so reloading the shell does
  # not pick up a new unityagentd.py. The shell's boot check restarts it.
  pkill -f '^python3 .*unityagentd[.]py' >/dev/null 2>&1 || true
else
  log "Not inside a Hyprland session; start the shell with: qs -c hyprunity"
fi

if [ "$BACKUP" -eq 1 ]; then
  BACKUP_SUMMARY="${BACKUP_DIR/#$HOME/\~}"
else
  BACKUP_SUMMARY="none (disabled)"
fi

cat <<EOF

${B}Done.${N}

  Configs      ~/.config/quickshell/hyprunity, ~/.config/hypr, ~/.config/hyprunity
  Scripts      ~/.local/bin/hyprunity-theme-sync, hyprunity-matugen-apply
  Backups      $BACKUP_SUMMARY

  ${B}Next${N}
    1. Log out and back in (or start Hyprland if you have not yet).
    2. The first-run tour opens on first launch.
    3. SUPER + , opens Settings; SUPER + K lists every keybind.
    4. Settings → UnityAgent → Mouse control turns screen control on or off.

  If something looks wrong, read the shell log:
    ~/.local/state/hyprunity/shell.log

EOF
