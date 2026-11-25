-- =====================================================================
--  hexin — keybinds
--
--  mainMod is SUPER. [shell] marks the binds that drive hexin.
--  PROGRAMS, SCREENSHOT_DIR and SHOT come from 10-programs.lua;
--  SETTINGS is passed in by the entry point (it reads settings.lua).
-- =====================================================================

local SETTINGS = ...

local mainMod = "SUPER"

-- ── the shell: hexin registers these as global shortcuts ────────
hl.bind(mainMod .. " + C", hl.dsp.global("quickshell:controlPanel")) -- [shell] control centre
hl.bind(mainMod .. " + ESCAPE", hl.dsp.global("quickshell:controlPanel")) -- [shell] power buttons live here
hl.bind(mainMod .. " + N", hl.dsp.global("quickshell:notificationCenter")) -- [shell] notification centre
hl.bind(mainMod .. " + W", hl.dsp.global("quickshell:wallpaper")) -- [shell] wallpaper switcher
hl.bind(mainMod .. " + comma", hl.dsp.global("quickshell:settings")) -- [shell] settings app
hl.bind(mainMod .. " + L", hl.dsp.global("quickshell:lock")) -- [shell] built-in lock (PAM)
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.global("quickshell:dnd")) -- [shell] do-not-disturb
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("qs ipc -c hexin call shell reload")) -- [shell] reload the shell
hl.bind(mainMod .. " + T", hl.dsp.global("quickshell:unityagent")) -- [shell] unityagent
hl.bind(mainMod .. " + K", hl.dsp.global("quickshell:keybinds")) -- [shell] searchable keybind cheatsheet

-- ── applications ───────────────────────────────────────────────────
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(PROGRAMS.terminal))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(PROGRAMS.browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(PROGRAMS.files))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd(PROGRAMS.messages))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(PROGRAMS.music))

-- ── launcher + clipboard history (hexin's own panels) ──────────
-- Without hyprland_global_shortcuts_v1 use the IPC form instead:
--   hl.dsp.exec_cmd("qs ipc -c hexin call panels toggle launcher")
--   hl.dsp.exec_cmd("qs ipc -c hexin call panels toggle clipboard")
hl.bind(mainMod .. " + SPACE", hl.dsp.global("quickshell:launcher")) -- [shell] App launcher
hl.bind("ALT + SPACE", hl.dsp.global("quickshell:spotlight")) -- [shell] Spotlight: apps, files, maths, web
hl.bind(mainMod .. " + V", hl.dsp.global("quickshell:clipboard")) -- [shell] Clipboard history

-- ── windows ────────────────────────────────────────────────────────
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + A", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only

-- Focus (arrows), move (SHIFT + arrows), resize (CTRL + arrows).
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + ALT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.move({ direction = "down" }))

hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })

-- Drag to move, right-drag to resize.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ── workspaces ─────────────────────────────────────────────────────
for i = 1, 10 do
	local key = i % 10 -- 10 maps to the 0 key
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- ── scratchpads (special workspaces) ───────────────────────────────
-- Window rules further down route each app onto its own scratchpad, so the
-- launch key and the toggle key stay separate and always make sense.
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + D", hl.dsp.workspace.toggle_special("discord"))
hl.bind(mainMod .. " + M", hl.dsp.workspace.toggle_special("music"))

-- Scroll to walk the existing workspaces.
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- ── screenshots and tools ──────────────────────────────────────────
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(SHOT))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.global("quickshell:recordRegion")) -- [shell] region screen recording
hl.bind("SHIFT + PRINT", hl.dsp.global("quickshell:recordFull")) -- [shell] fullscreen screen recording
hl.bind("PRINT", hl.dsp.exec_cmd(
	'mkdir -p "' .. SCREENSHOT_DIR .. '"'
	.. ' && f="' .. SCREENSHOT_DIR .. '/$(date +%F_%H-%M-%S).png"'
	.. ' && grim - > "$f" && wl-copy < "$f"'
	.. ' && qs ipc -c hexin call actions notify "Screenshot" "Screenshot saved"'
)) -- whole screen
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a")) -- pick a colour

-- ── game mode: owned by the shell (toggles animations/blur/shadows/gaps) ──
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.global("quickshell:gamemode"))

-- ── media, volume and brightness ───────────────────────────────────
-- Handed to hexin so the on-screen display appears with them; the shell
-- applies the change itself (wpctl / brightnessctl under the hood).
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("qs ipc -c hexin call audio up"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("qs ipc -c hexin call audio down"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("qs ipc -c hexin call audio mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("qs ipc -c hexin call audio micMute"), { locked = true })
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("qs ipc -c hexin call brightness up"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("qs ipc -c hexin call brightness down"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("qs ipc -c hexin call media playPause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("qs ipc -c hexin call media playPause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("qs ipc -c hexin call media next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("qs ipc -c hexin call media previous"), { locked = true })
