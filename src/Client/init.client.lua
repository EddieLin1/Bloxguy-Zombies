--!strict
-- Client bootstrap: requires every Controller, runs all Init()s (wiring, no yielding), then all Start()s.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules index ReplicatedStorage.Shared directly, so wait until the initial replication is done.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
ReplicatedStorage:WaitForChild("Shared")

type Controller = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

local controllers: { [string]: Controller } = {}
for _, module in script.Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		-- Dynamic require: the analyser cannot resolve it, so cast through any.
		controllers[module.Name] = (require :: any)(module)
	end
end

for _, controller in controllers do
	if controller.Init then
		controller.Init()
	end
end

for _, controller in controllers do
	if controller.Start then
		task.spawn(controller.Start)
	end
end
