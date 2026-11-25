-- =====================================================================
--  hexin — input
-- =====================================================================

hl.config({
	input = {
		kb_layout = "us",
		follow_mouse = 1,
		sensitivity = 0,
		accel_profile = "flat",
		touchpad = {
			natural_scroll = false,
		},
	},
})

-- Three fingers left/right to switch workspaces.
hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- FIX: the default shipped a placeholder rule for a mouse that does not exist
-- ("epic-mouse-v1"). Add real per-device tweaks here instead, e.g.
--   hl.device({ name = "elan0x1234:00-04f3:0000-touchpad", disable_while_typing = true })
