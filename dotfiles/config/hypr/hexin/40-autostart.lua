-- =====================================================================
--  hexin — autostart
--
--  Everything that should come up with the session. exec_cmd is
--  fire-and-forget, so each line here is independent.
-- =====================================================================

hl.on("hyprland.start", function()
	-- Keyring before anything that may want a stored secret.
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11")
	hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")

	-- ONE chained command: exec is fire-and-forget, so as separate lines a
	-- portal would race the env import and start without WAYLAND_DISPLAY.
	-- Pushing every hl.env() name into systemd/D-Bus is what lets a
	-- D-Bus-activated portal see the session at all. daemon-reload first so a
	-- unit re-laid by a package update is the one that runs; reset-failed so a
	-- unit that hit its start limit last session can start again.
	hl.exec_cmd(
		"dbus-update-activation-environment --systemd --all; "
			.. "systemctl --user daemon-reload; "
			.. "systemctl --user reset-failed hyprpolkitagent.service "
			.. "xdg-desktop-portal.service xdg-desktop-portal-hyprland.service "
			.. "xdg-desktop-portal-gtk.service 2>/dev/null; "
			.. "systemctl --user start hyprland-session.target; "
			-- hexin has no polkit agent of its own, so use the stock one. It
			-- must run as a child of THIS session: the packaged user unit
			-- (hyprpolkitagent.service) cannot register — polkit rejects it with
			-- "Passed session and the session the caller is in differs" because a
			-- systemd --user service is not part of the graphical session — and
			-- then segfaults inside its own cleanup path. Started here, it
			-- registers as "polkit agent for session N" and stays up.
			.. "/usr/lib/hyprpolkitagent/hyprpolkitagent; "
			-- Portals restart last, once the desktop is up: a previous session's
			-- frontend survives otherwise (nothing stops graphical-session.target)
			-- and every portal request times out instead of reaching the backend.
			.. "systemctl --user try-restart xdg-desktop-portal.service "
			.. "xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service"
	)

	-- Clipboard history (SUPER + V). Two watchers: text and images.
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	-- Idle handling: dim, then lock, then turn the panel off, then suspend.
	-- hypridle is installed but nothing started it, so a laptop never slept.
	-- Its listeners live in ~/.config/hypr/hypridle.conf.
	hl.exec_cmd("hypridle")

	-- The UnityAgent daemon. It only comes up when the universal switch in
	-- Settings → UnityAgent is on. The shell starts it later if the switch is
	-- turned back on, so this is only the login path. If the settings file
	-- cannot be read, fall back to Config's default (on).
	local function unity_agent_enabled()
		if not io or not io.open then
			return true
		end
		local file = io.open(os.getenv("HOME") .. "/.config/hexin/settings.json", "r")
		if not file then
			return true
		end
		local text = file:read("*a")
		file:close()
		-- settings.json is written by the shell; the unityAgent object is flat.
		local agent = text:match('"unityAgent"%s*:%s*(%b{})')
		if not agent then
			return true
		end
		return agent:match('"enabled"%s*:%s*(%a+)') ~= "false"
	end

	if unity_agent_enabled() then
		hl.exec_cmd("python3 " .. os.getenv("HOME") .. "/.config/hexin/scripts/unityagentd.py & disown")
	end

	-- Its output is kept: Hyprland sends exec_cmd output to /dev/null, so a QML
	-- warning would otherwise vanish into nothing. The file is fresh each login.
	hl.exec_cmd(
		"mkdir -p $HOME/.local/state/hexin; " .. "qs -c hexin >$HOME/.local/state/hexin/shell.log 2>&1"
	)
end)
