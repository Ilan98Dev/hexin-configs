-- =====================================================================
--  hyprunity — layer rules (the shell's own surfaces)
-- =====================================================================

-- Frost the shell's panels and toasts so they read as glass, and keep the
-- frost inside the card: ignore_alpha stops the compositor from blurring the
-- transparent rectangle a surface reserves for its shadow.
-- qs-wallpaper is deliberately left out — it covers the whole output.
for _, ns in ipairs({ "qs-bar", "qs-panels", "qs-notifications", "qs-osd" }) do
	hl.layer_rule({
		name = "hyprunity-blur-" .. ns,
		match = { namespace = "^" .. ns .. "$" },
		blur = true,
		ignore_alpha = 0.3,
	})
end

-- The wallpaper rides the background layer; a popin would read as a flicker,
-- so fade it instead (image <-> solid colour crossfades cleanly).
hl.layer_rule({
	name = "wallpaper-fade",
	match = { namespace = "^qs-wallpaper$" },
	animation = "fade",
})
