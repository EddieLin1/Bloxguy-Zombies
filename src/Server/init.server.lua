--!strict
-- Server bootstrap: requires every Service, runs all Init()s (wiring, no yielding), then all Start()s.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

-- The pre-refactor scripts still saved in the place file. If they run alongside this code, both games
-- spawn zombies and create remotes at once, which breaks shooting and damage.
local LEGACY_SCRIPTS: { { Parent: Instance, Name: string } } = {
	{ Parent = ServerScriptService, Name = "GameManager" },
	{ Parent = StarterPlayer:WaitForChild("StarterPlayerScripts"), Name = "ClientMain" },
	{ Parent = ReplicatedStorage, Name = "GameConfig" },
}
for _, legacy in LEGACY_SCRIPTS do
	local found = legacy.Parent:FindFirstChild(legacy.Name)
	if found then
		warn(`[Bloxguy Zombies] Old script {found:GetFullName()} is still in the place. Delete it in Studio, it conflicts with the new code.`)
	end
end

type Service = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

local services: { [string]: Service } = {}
for _, module in script.Services:GetChildren() do
	if module:IsA("ModuleScript") then
		-- Dynamic require: the analyser cannot resolve it, so cast through any.
		services[module.Name] = (require :: any)(module)
	end
end

for _, service in services do
	if service.Init then
		service.Init()
	end
end

for _, service in services do
	if service.Start then
		task.spawn(service.Start)
	end
end
