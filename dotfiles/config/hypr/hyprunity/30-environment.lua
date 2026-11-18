-- =====================================================================
--  hyprunity — environment
-- =====================================================================

-- Cursor (Bibata is installed; Hyprland's default cursor is not themed).
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")

-- Intel iGPU: dropping DMA-BUF modifiers dodges Hyprland's post-capture black
-- screen, which is exactly what a screenshot/screencopy triggers. (Never set
-- this on an nvidia-driven panel.)
hl.env("AQ_NO_MODIFIERS", "1")

-- Native Wayland first so GTK/Qt/Electron get the compositor's scaling.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- GTK4 opens its display through a Mutter-only service channel and hangs on
-- wlroots compositors; pin the GL renderer so nautilus always starts.
hl.env("GSK_RENDERER", "gl")

-- qt6ct, not kde: plasma-integration is not installed, so "kde" would strip
-- plain Qt apps of their palette and icons.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.env("PATH", (os.getenv("HOME") or "") .. "/.local/bin:" .. (os.getenv("PATH") or ""))
hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")
