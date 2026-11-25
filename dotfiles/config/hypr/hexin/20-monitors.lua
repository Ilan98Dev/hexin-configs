-- =====================================================================
--  hexin — monitors
-- =====================================================================

-- The laptop panel, pinned, so the layout never depends on EDID timing.
hl.monitor({ output = "eDP-1", mode = "1366x768@60.0", position = "0x0", scale = 1 })
-- Anything else (a dock, a projector) takes its preferred mode.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
