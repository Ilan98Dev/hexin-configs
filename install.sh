#!/usr/bin/env bash
# =====================================================================
#  hyprunity installer
#
#  Arch Linux (x86_64) only. Installs the packages hyprunity uses, then
#  copies the configs into ~/.config and the helper scripts into
#  ~/.local/bin. Anything it replaces is moved to
#      ~/.local/state/hyprunity/install-backup-<timestamp>
#  so nothing is lost. Your wallpaper folder is never touched.
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
log "Backups will go to ${BACKUP_DIR/#$HOME/\~}"

# ── 2. packages ─────────────────────────────────────────────────────
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
  vesktop
  bibata-cursor-theme-bin
  adw-gtk3
)

log "Installing official packages (this upgrades the system, as Arch expects)…"
sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}"

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
  warn "The shell works without them; the browser, Discord client and cursor theme will be missing."
fi

# ── 3. backups ──────────────────────────────────────────────────────
backup_path() {
  local path="$1"
  [ -e "$path" ] || [ -L "$path" ] || return 0
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

# ── 4. configs ──────────────────────────────────────────────────────
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

# ── 5. runtime folders and small integrations ───────────────────────
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
  cp "$KITTY_CONF" "$KITTY_CONF.bak-$STAMP"
  printf '\n# hyprunity palette\ninclude hyprunity-theme.conf\n' >>"$KITTY_CONF"
  log "Added the hyprunity palette include to kitty.conf."
fi

# ── 6. system services ──────────────────────────────────────────────
if systemctl list-unit-files NetworkManager.service >/dev/null 2>&1; then
  sudo systemctl enable --now NetworkManager.service >/dev/null 2>&1 ||
    warn "Could not enable NetworkManager.service."
fi
if systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
  sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 ||
    warn "Could not enable bluetooth.service."
fi

# ── 7. start / reload ───────────────────────────────────────────────
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  hyprctl reload >/dev/null 2>&1 || true
  if qs ipc -c hyprunity call shell reload >/dev/null 2>&1; then
    log "Reloaded the running hyprunity shell."
  else
    (setsid sh -c 'exec qs -c hyprunity >"$HOME/.local/state/hyprunity/shell.log" 2>&1' >/dev/null 2>&1 &)
    log "Started hyprunity."
  fi
else
  log "Not inside a Hyprland session; start the shell with: qs -c hyprunity"
fi

cat <<EOF

${B}Done.${N}

  Configs      ~/.config/quickshell/hyprunity, ~/.config/hypr, ~/.config/hyprunity
  Scripts      ~/.local/bin/hyprunity-theme-sync, hyprunity-matugen-apply
  Backups      ${BACKUP_DIR/#$HOME/\~}

  ${B}Next${N}
    1. Log out and back in (or start Hyprland if you have not yet).
    2. The first-run tour opens on first launch.
    3. SUPER + , opens Settings; SUPER + K lists every keybind.

  If something looks wrong, read the shell log:
    ~/.local/state/hyprunity/shell.log

EOF
