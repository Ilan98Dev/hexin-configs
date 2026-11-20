<p align="center">
  <img src="assets/logo.png" width="112" alt="hyprunity logo">
</p>

<h1 align="center">hyprunity</h1>

<p align="center">
  A complete Quickshell desktop for <b>UnityOS / Hyprland</b> — bar, control centre,
  notifications, launcher, lock screen, settings app and an AI agent, in one config.
</p>

---

hyprunity replaces the usual pile of desktop tools (waybar, fuzzel, swaync, wlogout,
hyprlock, …) with a single Quickshell configuration and a small, readable Hyprland
Lua config. It is built around the UnityOS palette: dark violet surfaces, an orange
accent and purple highlights.

Everything is live-configurable from the built-in Settings app, scriptable over IPC,
and themed together. **UnityAgent** adds a chat window that can read files, run
commands, install packages and diagnose crashes — always behind an approval card.

## Features

- **Bar** — per monitor, top or bottom, floating or flush. Launcher, workspace dots,
  window title, clock/calendar, MPRIS media controls, system tray with real menus,
  CPU/RAM, and a volume · network · Bluetooth · battery · notification cluster.
  Every item can be hidden or dragged into a different order in Settings → Bar.
- **Control centre** — volume/brightness/mic sliders, media, stats, night light,
  caffeine, game mode, screen recording and power actions.
- **Notification daemon** — popups, a persistent notification centre, Do Not Disturb,
  critical bypass, clickable actions and per-app icons.
- **Launcher and Spotlight** — `SUPER + Space` lists every app; `ALT + Space`
  searches apps, files in your home folders, quick maths, shell actions and the
  web. Web rows open DuckDuckGo in the browser set under Settings → Commands
  (defaults to `zen-browser`, falls back to `xdg-open`). No fuzzel or rofi.
- **Clipboard history** — native Quickshell panel, searchable.
- **Calendar** — click the clock.
- **Wallpaper layer** — bundled wallpaper, your own image, or none (let hyprpaper/swww
  show through), with a configurable scrim.
- **Lock screen** — a real `ext-session-lock` surface with PAM authentication.
- **Settings app** — appearance, wallpaper, bar layout, notifications, control centre,
  Hyprland decoration, commands, UnityAgent and general options. Changes apply live.
- **Theme presets** — UnityOS, Catppuccin (Mocha/Latte), Tokyo Night, Gruvbox, Nord,
  Rosé Pine, Dracula, plus **Auto (Matugen)** to derive the palette from the wallpaper.
- **System error watcher** — notices new `coredumpctl` crashes and failed systemd units,
  with a **Fix with AI** button that opens UnityAgent with the details filled in.
- **UnityAgent** — provider-agnostic chat (OpenAI, Google, custom OpenAI-compatible
  endpoints), tool use with approvals, projects under `~/Projects/UnityAgent`,
  web fetch/search, screenshots, ydotool mouse control and package management.
- **Extras** — keybind cheatsheet (`SUPER + K`), first-run tour, OSD, screen recording,
  night light, caffeine mode and game mode.

## Requirements

- **Arch Linux** (or an Arch-based distro) on **x86_64**
- **Hyprland 0.55+** — this repo uses the Lua configuration format (`hyprland.lua`)
- **Quickshell 0.3.2+**
- A PipeWire session, NetworkManager, BlueZ and UPower for the bar indicators
- A Nerd Font for the icon glyphs (the default is JetBrainsMono Nerd Font)

`install.sh` installs all of this for you. The full list:

| Official repositories | AUR |
|---|---|
| `hyprland`, `quickshell`, `hypridle`, `hyprpolkitagent`, `hyprsunset`, `hyprpicker` | `zen-browser-bin` |
| `xdg-desktop-portal`, `-hyprland`, `-gtk`, `xdg-utils`, `gnome-keyring`, `polkit` | `bibata-cursor-theme-bin` |
| `wl-clipboard`, `cliphist`, `brightnessctl`, `grim`, `slurp` | `adw-gtk3` |
| `pipewire`, `pipewire-pulse`, `wireplumber` (skipped if already present) | |
| `networkmanager`, `bluez`, `bluez-utils`, `upower`, `libnotify` | |
| `kitty`, `nautilus`, `pavucontrol`, `spotify-launcher`, `neovim` | |
| `matugen`, `python`, `lua`, `ydotool`, `gpu-screen-recorder`, `pacman-contrib` | |
| `ttf-jetbrains-mono-nerd`, `qt6ct`, `git`, `base-devel` | |

The AUR packages are optional: without them the shell still runs, but the default
browser (`zen-browser`) and cursor theme will be missing. A Discord client is not
installed; add `vesktop-bin` from the AUR yourself if you want one.

## Installation

```bash
git clone https://github.com/Ilan98Dev/Hyprunity.git
cd Hyprunity
./install.sh
```

The installer:

1. checks that it is running on Arch Linux / x86_64, as a normal user;
2. asks whether to run a full system update (`pacman -Syu`) or just install the
   packages (`pacman -S`), and whether to back up the files it replaces;
3. installs the official packages with `pacman`, then the AUR packages with
   `yay` or `paru` if one is available;
4. copies the configs into `~/.config` and the helper scripts into `~/.local/bin`;
5. moves anything it replaces into
   `~/.local/state/hyprunity/install-backup-<timestamp>` (or deletes it if you
   declined the backup);
6. adds the palette include to `~/.config/kitty/kitty.conf`;
7. enables `NetworkManager`, `bluetooth` and the user `ydotool.service` (adding
   you to the `input` group if needed), reloads Hyprland and starts the shell.

It **never touches your wallpaper folder**. The default wallpaper is bundled with
the shell; Settings → Wallpaper points at `~/Pictures/Wallpapers` only when you
choose an image of your own.

If you already have a `~/.config/hypr/hyprland.conf`, it is moved into the backup
folder: Hyprland uses `hyprland.lua` when it exists, and the old file would
otherwise be silently ignored anyway.

After the installer, **log out and back in** (or start Hyprland if you have not yet).
The first-run tour opens on first launch.

Re-running the installer is safe when backups are on (the default): it moves what
it replaces into the backup folder, so your previous configs stay there. If you
turn backups off, replaced files are deleted instead. Note that it ships the
default `~/.config/hyprunity/settings.json`, so a reinstall resets the shell
settings to those defaults (your old file is in the backup).

### Manual installation

Copy the trees yourself if you prefer:

```bash
cp -a dotfiles/config/.  ~/.config/
install -Dm755 dotfiles/bin/* ~/.local/bin/
```

Then make sure `~/.config/hypr/hyprland.lua` is the config Hyprland loads (remove or
rename an existing `hyprland.conf`), and start the shell with `qs -c hyprunity`.

## Keybindings

The full, always-current list is in the shell: **`SUPER + K`** opens a searchable
cheatsheet generated from `~/.config/hypr/hyprunity/90-keybinds.lua`.

| Key | Action |
|---|---|
| `SUPER + C` / `SUPER + Esc` | control centre |
| `SUPER + N` | notification centre |
| `SUPER + T` | UnityAgent |
| `SUPER + K` | keybind cheatsheet |
| `SUPER + ,` | settings |
| `SUPER + W` | wallpaper picker |
| `SUPER + Space` | app launcher |
| `ALT + Space` | Spotlight: apps, files, maths, actions and the web |
| `SUPER + V` | clipboard history |
| `SUPER + L` | lock |
| `SUPER + Shift + N` | do not disturb |
| `SUPER + Shift + B` | reload the shell |
| `SUPER + Return` | terminal (kitty) |
| `SUPER + B` | browser (Zen) |
| `SUPER + E` | files (Nautilus) |
| `SUPER + Shift + D` | messages (Vesktop) |
| `SUPER + Shift + M` | music (Spotify) |
| `SUPER + Q` / `F` / `A` / `P` / `J` | close / fullscreen / float / pseudo / split |
| `SUPER + arrows` | focus · `SUPER + Alt + arrows` move · `SUPER + Ctrl + arrows` resize |
| `SUPER + 1…0` | workspaces · `SUPER + Alt + 1…0` move window |
| `SUPER + S` / `D` / `M` | scratchpads (magic / Discord / music) |
| `SUPER + Shift + S` | screenshot a region |
| `Print` | screenshot the whole screen |
| `SUPER + Ctrl + S` / `Shift + Print` | record region / whole screen |
| `SUPER + Shift + C` | colour picker |
| `SUPER + Shift + G` | game mode |
| `XF86Audio*`, `XF86MonBrightness*` | volume, mic, media and brightness (with OSD) |

## Configuration

| What | Where |
|---|---|
| Shell settings (all Settings pages) | `~/.config/hyprunity/settings.json` |
| Hyprland values the Settings app owns | `~/.config/hypr/hyprunity/settings.lua` |
| Hyprland config (monitors, binds, rules, autostart) | `~/.config/hypr/hyprland.lua` + `~/.config/hypr/hyprunity/*.lua` |
| Idle / lock / suspend behaviour | `~/.config/hypr/hypridle.conf` |
| UnityAgent daemon | `~/.config/hyprunity/scripts/unityagentd.py` |
| Matugen templates (Auto palette) | `~/.config/matugen/` |
| Runtime state and logs | `~/.local/state/hyprunity/` |

`settings.json` lives outside the Quickshell config directory on purpose: Quickshell
reloads whenever a file inside its config directory changes, so keeping settings
there would restart the shell on every slider movement. The file is watched, so
hand edits apply live.

The Hyprland Lua config is split by topic. `hyprland.lua` is a small loader; it reads
`settings.lua` and passes the values to `50-look-and-feel.lua`, then loads the rest
with `pcall` so a broken file names itself in the log. Settings → Hyprland only ever
rewrites `settings.lua`.

### UnityAgent

Open **Settings → UnityAgent** and choose a provider, model and API key. The key is
stored in the agent's own state folder (`~/.local/state/hyprunity/unityagent/`), not
in this repository and not in `settings.json`.

The daemon starts with the session when the universal switch is on. Read-only tools
(listing, reading, searching, web fetch, screenshots) run immediately; project
creation, file writes, package installs, shell commands and mouse clicks show an
approval card first. Per-feature switches in Settings → UnityAgent remove the
matching tools.

With **Mouse control** on, the agent can see the screen with `screenshot` and drive
the pointer with `ydotool`: move, scroll, and click (moves and scrolling run
immediately, clicks ask for approval). The installer installs `ydotool`, adds you
to the `input` group and enables the user service; if you set it up by hand, run
`sudo usermod -aG input "$USER"` and `systemctl --user enable --now ydotool.service`.

### Auto (Matugen) palette

Choose **Appearance → Preset → Auto (Matugen)**. Changing the wallpaper re-runs
`matugen`, which writes `colors.json` for the shell and `gtk.css` for GTK apps. The
helper scripts `hyprunity-matugen-apply` and `hyprunity-theme-sync` keep kitty, GTK
and the Hyprland border colour in step. This needs `matugen` (installed by the
installer); without it, use one of the static presets.

### IPC

Everything is scriptable:

```bash
qs ipc -c hyprunity call panels toggle control
qs ipc -c hyprunity call panels toggle notifications
qs ipc -c hyprunity call panels toggle launcher
qs ipc -c hyprunity call panels toggle spotlight
qs ipc -c hyprunity call panels toggle clipboard
qs ipc -c hyprunity call panels toggle wallpaper
qs ipc -c hyprunity call settings toggle
qs ipc -c hyprunity call audio up | down | mute | micMute
qs ipc -c hyprunity call brightness up | down
qs ipc -c hyprunity call notifications toggleDnd | clear
qs ipc -c hyprunity call media playPause | next | previous
qs ipc -c hyprunity call actions notify "Title" "Body"
qs ipc -c hyprunity call actions gameMode | screenshot | caffeine | nightLight
qs ipc -c hyprunity call unityagent ask "What is using port 8080?"
qs ipc -c hyprunity call shell reload | lock
```

`qs ipc -c hyprunity show` lists every target and function.

## Project structure

```
install.sh                         installer (Arch / x86_64)
tests/install-smoke.sh             installer test (stubbed, changes nothing)
dotfiles/
├── bin/
│   ├── hyprunity-matugen-apply    wallpaper -> palette (shell + GTK + kitty + borders)
│   └── hyprunity-theme-sync       active preset -> kitty / GTK / border colour
└── config/
    ├── quickshell/hyprunity/      the shell
    │   ├── shell.qml              surfaces, IPC, global shortcuts
    │   ├── config/                Theme, Config, Icons, Models
    │   ├── services/              audio, network, media, notifications, agent, …
    │   ├── components/            shared widgets
    │   └── modules/               bar, panels, notifications, osd, lock,
    │                              settings, wallpaper, welcome, unityagent
    ├── hypr/
    │   ├── hyprland.lua           loader
    │   ├── hypridle.conf          idle / lock / suspend
    │   └── hyprunity/             topic files + settings.lua + keybinds dump
    ├── hyprunity/
    │   ├── settings.json          default shell settings
    │   └── scripts/               UnityAgent daemon + FIFO reader
    └── matugen/                   Auto palette templates
```

## Testing

The installer has a smoke test that runs it against a throwaway `HOME` with
`pacman`, `sudo`, `systemctl`, `hyprctl` and `qs` stubbed out:

```bash
bash tests/install-smoke.sh
```

It changes nothing on the real system and covers a fresh install, a reinstall
over existing files (including backups), and the in-session reload path.

## Troubleshooting

**The shell does not start.** Run it in a terminal and read the log:

```bash
qs -c hyprunity
cat ~/.local/state/hyprunity/shell.log
```

**Hyprland ignores the config.** Check that `~/.config/hypr/hyprland.lua` exists and
that no `hyprland.conf` is being loaded instead. Then:

```bash
hyprctl configerrors
hyprctl reload
```

**Two bars / two notification daemons.** Stop any other bar or notification daemon
(`waybar`, `swaync`, `dunst`, `mako`) before starting hyprunity.

**No icons or odd glyphs.** Install a Nerd Font (`ttf-jetbrains-mono-nerd`) and pick
it in Settings → Appearance.

**Bluetooth / battery missing from the bar.** Make sure `bluetooth.service` is running
and `upower` is installed; the indicators hide themselves when the service is absent.

**UnityAgent says the key is missing.** Set it in Settings → UnityAgent. Keys are
per-user and are never stored in this repo.

**Reset the shell settings.** Delete `~/.config/hyprunity/settings.json` and reload;
the defaults are written on the next start. The old file is recreated with the values
currently in memory, so restart the shell (`qs kill -c hyprunity && qs -c hyprunity`)
for a true reset.

## Credits

Built on [Quickshell](https://quickshell.org) and [Hyprland](https://hyprland.org).
Some code snippets are adapted from [Ryoku](https://ryoku.dev). The UnityOS
palette and branding belong to the UnityOS project. Package names and defaults
target Arch Linux.

## License

MIT — see [LICENSE](LICENSE).
