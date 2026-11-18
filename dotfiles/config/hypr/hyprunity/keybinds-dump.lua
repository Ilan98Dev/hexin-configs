-- =====================================================================
--  keybinds-dump.lua — machine-readable keybinds for the shell
--
--  The shell's SUPER + K cheatsheet reads 90-keybinds.lua through this
--  helper. It runs the real file with a stubbed Hyprland API, so loops,
--  variables (mainMod, PROGRAMS, SHOT) and new binds are resolved exactly
--  like they are in the live config instead of being regex-guessed.
--
--  Output (stdout): {"binds":[{...}, ...], "error": ""}
--
--  Each bind carries the keys, the dispatcher kind + arguments, the source
--  line, its section heading and any trailing comment. The QML side turns
--  that into labels and searchable text.
-- =====================================================================

local HOME = os.getenv("HOME") or ""
local DIR = HOME .. "/.config/hypr/hyprunity"
local SOURCE = DIR .. "/90-keybinds.lua"

-- Read the source once so comments and section headings can be attached to
-- the binds the interpreter reports.
local lines = {}
do
	local file = io.open(SOURCE, "r")
	if file then
		for line in file:lines() do
			lines[#lines + 1] = line
		end
		file:close()
	end
end

-- `--` outside a string literal starts a comment. Returns the text after it.
local function commentOn(line)
	local quote = nil
	local i = 1
	while i <= #line do
		local c = line:sub(i, i)
		if quote then
			if c == "\\" then
				i = i + 1
			elseif c == quote then
				quote = nil
			end
		elseif c == '"' or c == "'" then
			quote = c
		elseif c == "-" and line:sub(i + 1, i + 1) == "-" then
			return (line:sub(i + 2):gsub("^%s+", ""):gsub("%s+$", ""))
		end
		i = i + 1
	end
	return nil
end

-- The comment can sit on the closing line of a multi-line hl.bind(...), so
-- walk forward a little and stop if the next statement starts first.
local headingOn

local function trailingComment(startLine)
	for i = startLine, math.min(#lines, startLine + 10) do
		if i > startLine and headingOn(lines[i] or "") then
			return ""
		end
		if i > startLine and (lines[i] or ""):find("hl.bind", 1, true) then
			return ""
		end
		local c = commentOn(lines[i] or "")
		if c and c ~= "" then
			return c
		end
	end
	return ""
end

-- Section headings look like:  -- ── windows ───────────────
headingOn = function(line)
	return line:match("^%s*%-%-%s*──%s*(.-)%s+─")
end

local headings = {}
for i, line in ipairs(lines) do
	local name = headingOn(line)
	if name and name ~= "" then
		headings[#headings + 1] = { line = i, name = name }
	end
end

local function sectionFor(line)
	local found = ""
	for _, h in ipairs(headings) do
		if h.line <= line then
			found = h.name
		else
			break
		end
	end
	return found
end

-- A proxy that turns every hl.dsp.* call into a small descriptor. Nested
-- tables such as hl.dsp.window.close and hl.dsp.workspace.toggle_special
-- work because indexing returns another callable proxy.
local function proxy(path)
	return setmetatable({}, {
		__index = function(_, key)
			return proxy(path .. "." .. key)
		end,
		__call = function(_, ...)
			return { kind = path, args = { ... } }
		end,
	})
end

local binds = {}

hl = {
	dsp = proxy("dsp"),
	bind = function(keys, action, options)
		local info = debug.getinfo(2, "l")
		local line = info and info.currentline or 0
		local args = {}
		if action and type(action.args) == "table" then
			for i, value in ipairs(action.args) do
				args[i] = value
			end
		end
		binds[#binds + 1] = {
			keys = keys,
			kind = action and action.kind or "",
			args = args,
			options = options or {},
			line = line,
			section = sectionFor(line),
			comment = trailingComment(line),
		}
	end,
}

-- The real config sets these two globals before loading the keybinds.
pcall(dofile, DIR .. "/10-programs.lua")
PROGRAMS = PROGRAMS or {}
SHOT = SHOT or ""
SCREENSHOT_DIR = SCREENSHOT_DIR or ""

local SETTINGS = {}
do
	local ok, settings = pcall(dofile, DIR .. "/settings.lua")
	if ok and type(settings) == "table" then
		SETTINGS = settings
	end
end

local errorText = ""
local chunk, loadError = loadfile(SOURCE)
if not chunk then
	errorText = tostring(loadError)
else
	local ok, runError = pcall(chunk, SETTINGS)
	if not ok then
		errorText = tostring(runError)
	end
end

-- ── tiny JSON writer ─────────────────────────────────────────────────
local function escape(value)
	value = tostring(value)
	value = value:gsub("\\", "\\\\")
	value = value:gsub('"', '\\"')
	value = value:gsub("\n", "\\n")
	value = value:gsub("\r", "\\r")
	value = value:gsub("\t", "\\t")
	return '"' .. value .. '"'
end

local function encode(value)
	local kind = type(value)
	if kind == "string" then
		return escape(value)
	elseif kind == "number" or kind == "boolean" then
		return tostring(value)
	elseif kind == "table" then
		if #value > 0 then
			local parts = {}
			for i, item in ipairs(value) do
				parts[i] = encode(item)
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for key, item in pairs(value) do
			parts[#parts + 1] = escape(key) .. ":" .. encode(item)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

local out = { '{"binds":[' }
for i, bind in ipairs(binds) do
	if i > 1 then
		out[#out + 1] = ","
	end
	out[#out + 1] = encode(bind)
end
out[#out + 1] = '],"error":' .. escape(errorText) .. "}"
io.write(table.concat(out))
