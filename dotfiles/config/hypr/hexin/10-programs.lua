-- =====================================================================
--  hexin — programs
--
--  Change a name here and every bind and rule that uses it follows.
--  These are globals on purpose: 90-keybinds.lua and 95-window-rules.lua
--  read them after this file has run.
-- =====================================================================

PROGRAMS = {
	terminal = "kitty -1",
	files = "nautilus",
	browser = "zen-browser",
	music = "spotify-launcher",
	messages = "vesktop",
	volume = "pavucontrol",
}

-- Extra commands, kept next to the programs so there is one place to look.
SCREENSHOT_DIR = "$HOME/Pictures/Screenshots"

-- Save to a timestamped file, copy it, then tell hexin it worked so the
-- shell can show the same notification as the control-centre button. `&&`
-- keeps the notice quiet when slurp is cancelled or grim fails.
SHOT = 'mkdir -p "' .. SCREENSHOT_DIR .. '"'
	.. ' && f="' .. SCREENSHOT_DIR .. '/$(date +%F_%H-%M-%S).png"'
	.. ' && g=$(slurp < /dev/null) && [ -n "$g" ] && grim -g "$g" - > "$f"'
	.. ' && wl-copy < "$f"'
	.. ' && qs ipc -c hexin call actions notify "Screenshot" "Screenshot saved"'
