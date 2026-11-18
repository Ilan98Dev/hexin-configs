-- =====================================================================
--  hyprunity — window and workspace rules
-- =====================================================================

-- Cap a floating size to the panel so nothing ever reads as a broken
-- fullscreen: Hyprland evaluates these per window.
local function fit(w, h)
	return {
		"min(" .. w .. ", monitor_w * 0.92)",
		"min(" .. h .. ", monitor_h * 0.88)",
	}
end

-- hyprunity's settings app is a normal floating window; give it a sane size.
-- It is the widest window the shell opens, so it gets a slightly higher height
-- cap than fit()'s 88% — 680px would otherwise be shaved to ~676 on a 768px
-- panel.
hl.window_rule({
	name = "hyprunity-settings",
	match = { title = "^(Shell Settings)$" },
	float = true,
	size = { "min(1170, monitor_w * 0.92)", "min(680, monitor_h * 0.92)" },
	center = true,
})

-- UnityAgent is a full chat window, not a drawer: float it and size it to the
-- same footprint as the settings app.
hl.window_rule({
	name = "hyprunity-unityagent",
	match = { title = "^(UnityAgent)$" },
	float = true,
	size = fit(1100, 720),
	center = true,
})

-- Catch every Quickshell window by class as well: the title-based rule above
-- can race the map event, and a tiled chat window is unreadable.
hl.window_rule({
	name = "hyprunity-quickshell-float",
	match = { class = "^(org.quickshell)$" },
	float = true,
	center = true,
})

-- System dialogs that are always floating.
hl.window_rule({
	name = "float-system-dialogs",
	match = {
		class = "(pavucontrol|nm-connection-editor|blueman-manager|org.kde.polkit-kde-authentication-agent-1|xdg-desktop-portal-gtk)",
	},
	float = true,
	center = true,
})

-- hyprunity has no polkit agent, so the stock Qt one answers prompts: it must
-- float, or it lands tiled in the corner of the screen.
hl.window_rule({
	name = "float-polkit-agent",
	match = { class = "hyprpolkitagent" },
	float = true,
	center = true,
})

hl.window_rule({
	name = "float-file-pickers",
	match = { title = "(Open File|Save File|Save As|Choose Files|Open Folder)" },
	float = true,
})

-- Files: floating and centred, capped to the panel. Tiled on a 1366x768 screen
-- it ends up a cramped half-column; this is the size the rest of the desktop
-- is laid out for.
hl.window_rule({
	name = "float-nautilus",
	match = { class = "org.gnome.Nautilus" },
	float = true,
	size = fit(1500, 850),
	center = true,
})

-- Scratchpad routing: each app always lands on its own special workspace, so
-- SUPER + D / M just reveal it.
hl.window_rule({
	name = "scratch-discord",
	match = { class = "^(vesktop|discord)$" },
	workspace = "special:discord",
})
hl.window_rule({
	name = "scratch-music",
	match = { class = "^(ryotunes|[Ss]potify)$" },
	workspace = "special:music",
})

-- Music players size and centre themselves; keep them floating and opaque.
hl.window_rule({
	name = "float-music",
	match = { class = "^(ryotunes|[Ss]potify)$" },
	float = true,
	opaque = true,
})

-- Ignore maximise requests: tiling setups never want them.
hl.window_rule({
	name = "suppress-maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix dragging with XWayland's invisible helper windows.
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Hyprland's own runner.
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})
