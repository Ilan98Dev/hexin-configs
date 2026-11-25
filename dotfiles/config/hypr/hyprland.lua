-- =====================================================================
--  hyprland.lua — entry point
--
--  The configuration is split across small files in hypr/hexin/ so
--  each topic is easy to find. They load in the order listed below.
--
--  Values owned by hexin's Settings → Hyprland page live in
--  hexin/settings.lua. That is the ONE file the app rewrites, so
--  hand edits there are temporary; everything else is safe to edit.
--
--  Reload after editing:   hyprctl reload
--
--  Errors are reported to stderr (print goes to /dev/null under
--  Hyprland); look in the session log, e.g.
--  ~/.local/share/sddm/wayland-session.log
-- =====================================================================

local HOME = os.getenv("HOME") or ""
local DIR = HOME .. "/.config/hypr/hexin"

-- Diagnostics go to stderr: Hyprland runs with stdout on /dev/null, so a
-- plain print() would vanish. stderr lands in the session log
-- (~/.local/share/sddm/wayland-session.log on this machine).
local function log(msg)
	local out = io and io.stderr
	if out then
		out:write("[hexin] " .. msg .. "\n")
	else
		print("[hexin] " .. msg)
	end
end

-- Settings the Settings app owns. Missing or unreadable -> built-in defaults,
-- but say so out loud: a broken settings.lua should never fail silently.
local ok, s = pcall(dofile, DIR .. "/settings.lua")
if not ok then
	log("settings.lua failed: " .. tostring(s))
end
local SETTINGS = (ok and type(s) == "table") and s or {}

local files = {
	"10-programs.lua",
	"20-monitors.lua",
	"30-environment.lua",
	"40-autostart.lua",
	"50-look-and-feel.lua",
	"60-animations.lua",
	"70-layouts.lua",
	"75-misc.lua",
	"80-input.lua",
	"90-keybinds.lua",
	"95-window-rules.lua",
	"99-layer-rules.lua",
}

for _, name in ipairs(files) do
	local path = DIR .. "/" .. name
	local chunk, err = loadfile(path)
	if not chunk then
		log("could not load " .. name .. ": " .. tostring(err))
		error("[hexin] could not load " .. path .. ": " .. tostring(err))
	end
	-- Run it wrapped, so a runtime error names the file it came from
	-- instead of only "hyprland.lua". The 0 level keeps Lua from
	-- prepending this file's position to the message.
	local ran, rerr = pcall(chunk, SETTINGS)
	if not ran then
		log("error in " .. name .. ": " .. tostring(rerr))
		error("[hexin] error in " .. name .. ": " .. tostring(rerr), 0)
	end
end
