function widget:GetInfo() return { name = "zz live", desc = "test only: runs the commands of live.ps1 (file LuaUI/Config/live_cmd.txt in the data folder) in the running test game", layer = 0, enabled = true } end
-- Test widget of pve_test.ps1 -Live. Once a second it reads LuaUI/Config/live_cmd.txt of the write folder. The first line is an id; a command is run once per id (the engine setting zzliveLast keeps it over a
-- "luaui reload", which loads the widgets again and forgets WG). The other lines: "cmd <text>" = Spring.SendCommands (e.g. "cmd luaui reload", "cmd screenshot png"), "lua <code>" = the code is run,
-- "say <text>" = a line of the log. Results: lines "[zzlive]" of the log.
local lastCheck = 0
local R_missing
local function run(line)
	local kind, rest = line:match("^(%a+)%s?(.*)$")
	if kind == "cmd" then
		Spring.Echo("[zzlive] cmd " .. rest)
		Spring.SendCommands(rest)
	elseif kind == "lua" then
		local f, err = loadstring(rest)
		if not f then Spring.Echo("[zzlive] lua error " .. tostring(err)) return end
		local ok, res = pcall(f)
		Spring.Echo("[zzlive] lua " .. (ok and "ok " or "failed ") .. tostring(res))
	elseif kind == "say" then
		Spring.Echo("[zzlive] " .. rest)
	end
end

function widget:Update()
	local now = os.clock()
	if now - lastCheck < 1 then return end
	lastCheck = now
	local text = VFS.LoadFile("LuaUI/Config/live_cmd.txt", VFS.RAW_FIRST)
	if not text and io and io.open then
		local fh = io.open("LuaUI/Config/live_cmd.txt", "r")
		if fh then text = fh:read("*a"); fh:close() end
	end
	if not text or text == "" then
		R_missing = (R_missing or 0) + 1
		if R_missing % 15 == 1 then Spring.Echo("[zzlive] no command file readable (" .. tostring(VFS.RAW_FIRST) .. " io " .. tostring(io ~= nil) .. ")") end
		return
	end
	local id, body = text:match("^([^\r\n]*)\r?\n?(.*)$")
	if not id or id == "" or id == Spring.GetConfigString("zzliveLast", "") then return end
	Spring.SetConfigString("zzliveLast", id)
	Spring.Echo("[zzlive] command " .. id .. " (frame " .. Spring.GetGameFrame() .. ")")
	for line in body:gmatch("[^\r\n]+") do run(line) end
end

function widget:Initialize()
	Spring.Echo("[zzlive] ready (loaded at frame " .. Spring.GetGameFrame() .. ", last command " .. Spring.GetConfigString("zzliveLast", "") .. ")")
end
