-- =====================================================================
--  hyprunity — look and feel
--
--  Static decoration lives here. The numbers the Settings app can change
--  come from settings.lua, passed in as this chunk's argument.
-- =====================================================================

local SETTINGS = ...
local S = SETTINGS or {}

-- Value from settings.lua, or a default if the file is missing a key.
local function v(key, default)
	if S[key] == nil then
		return default
	end
	return S[key]
end

hl.config({
	general = {
		gaps_in = v("gaps_in", 5),
		gaps_out = v("gaps_out", 12),
		border_size = v("border_size", 2),

		col = {
			-- Managed alongside the theme (Settings → Hyprland).
			active_border = v("active_border", "rgba(f97316ff)"),
			inactive_border = v("inactive_border", "rgba(44464f77)"),
		},

		resize_on_border = false,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = v("rounding", 8),
		rounding_power = 2,

		shadow = {
			enabled = v("shadow", true),
			range = v("shadow_range", 4),
			render_power = v("shadow_power", 3),
			color = 0xee1a1a1a,
		},

		blur = {
			enabled = v("blur", true),
			size = v("blur_size", 8),
			passes = v("blur_passes", 2),
			new_optimizations = true,
			ignore_opacity = true,
		},

		active_opacity = v("active_opacity", 0.95),
		inactive_opacity = v("inactive_opacity", 0.95),
	},

	animations = {
		enabled = v("animations", true),
	},
})
