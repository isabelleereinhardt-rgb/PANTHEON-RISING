--[[
	HONORIS Studio Inventory — READ-ONLY AUDIT SCRIPT
	=================================================

	What it does:
	  Walks your place and PRINTS a report to the Output window:
	    * every Script / LocalScript / ModuleScript (path, size, risk flags)
	    * every RemoteEvent / RemoteFunction / Bindable
	    * Teams and SpawnLocations
	    * ScreenGuis in StarterGui
	    * instance counts in Workspace (for performance)
	    * possible free-model backdoors (require(<number>), loadstring, getfenv)

	What it does NOT do:
	  It never creates, changes, moves, or deletes anything. It only reads.

	How to run it (pick one):
	  1. With the Roblox Studio MCP connected to Claude Code on your PC:
	     ask Claude to run this file's contents with the MCP "run code" tool.
	  2. By hand: View > Command Bar, paste the whole file, press Enter.
	     Then click in the Output window, Ctrl+A, Ctrl+C, and paste the
	     report back to Claude.
]]

local OUT = {}
local function out(line)
	table.insert(OUT, line)
end

local SERVICES = {
	"Workspace", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService",
	"ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Teams",
	"Lighting", "SoundService", "TextChatService",
}

-- { Lua pattern to look for in script source, label to print }
-- UPPERCASE labels are things that deserve a careful look.
local FLAGS = {
	{ "OnServerEvent", "remote-handler" },
	{ "OnServerInvoke", "remotefunction-handler" },
	{ "OnClientInvoke", "CLIENT-INVOKE(server can hang)" },
	{ "FireServer", "fires-server" },
	{ "InvokeServer", "invokes-server" },
	{ "DataStoreService", "datastore" },
	{ "GetOrderedDataStore", "ordered-datastore" },
	{ "MemoryStoreService", "memorystore" },
	{ "MessagingService", "messaging" },
	{ "TeleportService", "teleport" },
	{ "MarketplaceService", "marketplace" },
	{ "ProcessReceipt", "process-receipt" },
	{ ":Kick%(", "kick" },
	{ "BanAsync", "ban" },
	{ "HttpService", "http" },
	{ "[Pp]layer%.Name%s*[=~]=", "NAME-BASED-CHECK" },
	{ "DisplayName%s*[=~]=", "DISPLAYNAME-CHECK" },
	{ "UserId%s*[=~]=", "userid-check" },
	{ "GetRankInGroup", "group-rank-check" },
	{ "loadstring", "LOADSTRING" },
	{ "getfenv", "GETFENV" },
	{ "setfenv", "SETFENV" },
	{ "require%s*%(%s*%d+", "REQUIRE-BY-ASSET-ID(possible backdoor)" },
	{ "while%s+true%s+do", "while-true-loop" },
	{ "wait%(%s*%)", "bare-wait()" },
}

local function getSource(inst)
	local ok, src = pcall(function()
		return inst.Source
	end)
	return ok and src or nil
end

local function enabledState(inst)
	if inst:IsA("ModuleScript") then
		return "module"
	end
	local ok, enabled = pcall(function()
		return inst.Enabled
	end)
	if ok then
		return enabled and "enabled" or "DISABLED"
	end
	return "?"
end

local function runContext(inst)
	if not inst:IsA("Script") or inst:IsA("LocalScript") then
		return ""
	end
	local ok, ctx = pcall(function()
		return inst.RunContext
	end)
	return ok and (" ctx=" .. tostring(ctx.Name)) or ""
end

local function maxLineLength(src)
	local longest = 0
	for line in string.gmatch(src, "[^\n]*") do
		if #line > longest then
			longest = #line
		end
	end
	return longest
end

-------------------------------------------------------------------------------
out("===== HONORIS INVENTORY BEGIN =====")
out(("PlaceId=%d GameId=%d StreamingEnabled=%s"):format(
	game.PlaceId, game.GameId, tostring(workspace.StreamingEnabled)))

-- 1. Scripts ------------------------------------------------------------------
out("")
out("--- SCRIPTS (path | class | state | lines | flags) ---")
local scriptCount, flaggedCount = 0, 0
for _, serviceName in ipairs(SERVICES) do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)
	if ok and service then
		for _, inst in ipairs(service:GetDescendants()) do
			if inst:IsA("LuaSourceContainer") then
				scriptCount += 1
				local src = getSource(inst) or ""
				local lines = select(2, string.gsub(src, "\n", "")) + 1
				local hits = {}
				for _, flag in ipairs(FLAGS) do
					if string.find(src, flag[1]) then
						table.insert(hits, flag[2])
					end
				end
				if maxLineLength(src) > 1000 then
					table.insert(hits, "VERY-LONG-LINE(obfuscation?)")
				end
				if serviceName == "Workspace" and inst:IsA("Script") and not inst:IsA("LocalScript") then
					table.insert(hits, "SERVER-SCRIPT-IN-WORKSPACE")
				end
				if #hits > 0 then
					flaggedCount += 1
				end
				out(("%s | %s%s | %s | %d | %s"):format(
					inst:GetFullName(), inst.ClassName, runContext(inst),
					enabledState(inst), lines, table.concat(hits, ",")))
			end
		end
	end
end
out(("Total scripts: %d (with flags: %d)"):format(scriptCount, flaggedCount))

-- 2. Remotes and bindables ------------------------------------------------------
out("")
out("--- REMOTES / BINDABLES ---")
local REMOTE_CLASSES = {
	RemoteEvent = true, UnreliableRemoteEvent = true, RemoteFunction = true,
	BindableEvent = true, BindableFunction = true,
}
for _, serviceName in ipairs(SERVICES) do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)
	if ok and service then
		for _, inst in ipairs(service:GetDescendants()) do
			if REMOTE_CLASSES[inst.ClassName] then
				out(("%s | %s"):format(inst:GetFullName(), inst.ClassName))
			end
		end
	end
end

-- 3. Teams and spawns -----------------------------------------------------------
out("")
out("--- TEAMS ---")
for _, team in ipairs(game:GetService("Teams"):GetChildren()) do
	if team:IsA("Team") then
		out(("%s | color=%s | autoAssign=%s"):format(
			team.Name, team.TeamColor.Name, tostring(team.AutoAssignable)))
	end
end
out("--- SPAWN LOCATIONS ---")
for _, inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("SpawnLocation") then
		out(("%s | color=%s | neutral=%s | enabled=%s"):format(
			inst:GetFullName(), inst.TeamColor.Name, tostring(inst.Neutral), tostring(inst.Enabled)))
	end
end

-- 4. GUIs -----------------------------------------------------------------------
out("")
out("--- STARTERGUI SCREENGUIS (name | enabled | resetOnSpawn | descendants | buttons) ---")
for _, gui in ipairs(game:GetService("StarterGui"):GetChildren()) do
	if gui:IsA("LayerCollector") then
		local buttons = 0
		for _, d in ipairs(gui:GetDescendants()) do
			if d:IsA("GuiButton") then
				buttons += 1
			end
		end
		local ok, reset = pcall(function()
			return gui.ResetOnSpawn
		end)
		out(("%s | %s | %s | %d | %d"):format(
			gui.Name, tostring(gui.Enabled), ok and tostring(reset) or "?",
			#gui:GetDescendants(), buttons))
	end
end

-- 5. Workspace top level and performance counts -----------------------------------
out("")
out("--- WORKSPACE TOP LEVEL (name | class | descendants) ---")
for _, child in ipairs(workspace:GetChildren()) do
	out(("%s | %s | %d"):format(child.Name, child.ClassName, #child:GetDescendants()))
end
out("--- WORKSPACE INSTANCE COUNTS ---")
local COUNT_CLASSES = {
	"BasePart", "MeshPart", "UnionOperation", "Model", "Humanoid",
	"ParticleEmitter", "Beam", "Trail", "Light", "Sound",
	"ProximityPrompt", "ClickDetector", "Script", "LocalScript",
}
local counts = {}
for _, inst in ipairs(workspace:GetDescendants()) do
	for _, className in ipairs(COUNT_CLASSES) do
		if inst:IsA(className) then
			counts[className] = (counts[className] or 0) + 1
		end
	end
end
for _, className in ipairs(COUNT_CLASSES) do
	out(("%s=%d"):format(className, counts[className] or 0))
end

out("===== HONORIS INVENTORY END =====")

for _, line in ipairs(OUT) do
	print(line)
end
