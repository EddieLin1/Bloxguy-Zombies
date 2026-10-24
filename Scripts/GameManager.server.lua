-- GameManager (Script in ServerScriptService)
-- Runs the whole game: rounds, waves, zombies, weapons, combos, pickups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

Players.CharacterAutoLoads = false

---------------------------------------------------------------------
-- Setup: remotes and folders
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local FireRemote = Instance.new("RemoteEvent")
FireRemote.Name = "Fire"
FireRemote.Parent = remotes
local ShotFx = Instance.new("RemoteEvent")
ShotFx.Name = "ShotFx"
ShotFx.Parent = remotes
local Notify = Instance.new("RemoteEvent")
Notify.Name = "Notify"
Notify.Parent = remotes
local AimRemote = Instance.new("UnreliableRemoteEvent")
AimRemote.Name = "Aim"
AimRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

-- Up/down aim angle from each client, shared with everyone through a character attribute
AimRemote.OnServerEvent:Connect(function(player, pitch)
	if typeof(pitch) ~= "number" or pitch ~= pitch then return end
	local char = player.Character
	if char then
		char:SetAttribute("AimPitch", math.clamp(pitch, -1.3, 1.3))
	end
end)

local function makeFolder(name)
	local f = workspace:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = workspace
	return f
end
local zombieFolder = makeFolder("Zombies")
local fxFolder = makeFolder("Effects")
local pickupFolder = makeFolder("Pickups")

local rng = Random.new()

local weaponByName = {}
for i, w in ipairs(Config.Weapons) do
	w.Index = i
	weaponByName[w.Name] = w
end

local function setState(state, message)
	ReplicatedStorage:SetAttribute("State", state)
	ReplicatedStorage:SetAttribute("Message", message or "")
end
setState("Waiting", "Waiting for players...")
ReplicatedStorage:SetAttribute("Wave", 0)
ReplicatedStorage:SetAttribute("ZombiesLeft", 0)

---------------------------------------------------------------------
-- Player data
---------------------------------------------------------------------
local data = {} -- [player] = { Points, Combo, ComboExpire, Kills, BestCombo, LastFire, Unlocked }

local function updateStats(player)
	local pd = data[player]
	if not pd then return end
	player:SetAttribute("Points", pd.Points)
	player:SetAttribute("Kills", pd.Kills)
	player:SetAttribute("Combo", pd.Combo)
	player:SetAttribute("ComboExpire", pd.ComboExpire)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Kills.Value = pd.Kills
		ls.Points.Value = pd.Points
	end
end

local function resetPlayerData(player)
	data[player] = {
		Points = 0,
		Combo = 0,
		ComboExpire = 0,
		Kills = 0,
		BestCombo = 0,
		LastFire = {},
		Unlocked = { [Config.Weapons[1].Name] = true },
	}
	updateStats(player)
end

local function isAlive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart") ~= nil
end

local function alivePlayers()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if isAlive(p) then
			table.insert(list, p)
		end
	end
	return list
end

---------------------------------------------------------------------
-- Weapons (Tools)
---------------------------------------------------------------------
local function findTool(player, name)
	local char = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	return (char and char:FindFirstChild(name)) or (backpack and backpack:FindFirstChild(name))
end

local function makeTool(w)
	local tool = Instance.new("Tool")
	tool.Name = w.Name
	tool.ToolTip = w.Name
	tool.CanBeDropped = false
	tool:SetAttribute("Weapon", w.Name)
	tool:SetAttribute("Ammo", w.Ammo)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.7, 1.2 + w.Index * 0.35)
	handle.Color = Color3.fromRGB(35, 35, 40)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Size = Vector3.new(0.42, 0.15, handle.Size.Z * 0.6)
	stripe.Color = w.Color
	stripe.Material = Enum.Material.Neon
	stripe.CanCollide = false
	stripe.Massless = true
	stripe.CFrame = handle.CFrame * CFrame.new(0, 0.3, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = stripe
	weld.Parent = stripe
	stripe.Parent = tool

	return tool
end

local function giveTool(player, w)
	local existing = findTool(player, w.Name)
	if existing then
		existing:SetAttribute("Ammo", w.Ammo)
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and isAlive(player) then
		makeTool(w).Parent = backpack
	end
end

local function checkUnlocks(player, pd)
	for _, w in ipairs(Config.Weapons) do
		if w.UnlockCombo > 0 and pd.Combo == w.UnlockCombo then
			if not pd.Unlocked[w.Name] then
				pd.Unlocked[w.Name] = true
				giveTool(player, w)
				Notify:FireClient(player, "NEW WEAPON: " .. w.Name .. "!", w.Color)
			else
				local tool = findTool(player, w.Name)
				if tool then
					tool:SetAttribute("Ammo", w.Ammo)
				end
				Notify:FireClient(player, w.Name .. " ammo refilled!", w.Color)
			end
		end
	end
end

---------------------------------------------------------------------
-- Pickups
---------------------------------------------------------------------
local function spawnPickup(position)
	local crate = Instance.new("Part")
	crate.Name = "SupplyCrate"
	crate.Size = Vector3.new(2, 2, 2)
	crate.Anchored = true
	crate.CanCollide = false
	crate.Material = Enum.Material.WoodPlanks
	crate.Color = Color3.fromRGB(150, 110, 60)
	crate.CFrame = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 255, 120)
	light.Range = 8
	light.Brightness = 2
	light.Parent = crate
	crate.Parent = pickupFolder

	local taken = false
	crate.Touched:Connect(function(hit)
		if taken then return end
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player or not isAlive(player) then return end
		taken = true

		local hum = char:FindFirstChildOfClass("Humanoid")
		hum.Health = math.min(hum.MaxHealth, hum.Health + Config.PickupHeal)

		local tools = {}
		for _, t in ipairs(char:GetChildren()) do table.insert(tools, t) end
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			for _, t in ipairs(backpack:GetChildren()) do table.insert(tools, t) end
		end
		for _, tool in ipairs(tools) do
			local w = tool:IsA("Tool") and weaponByName[tool.Name]
			if w and w.Ammo > 0 then
				local ammo = tool:GetAttribute("Ammo") or 0
				tool:SetAttribute("Ammo", math.min(w.Ammo, ammo + math.ceil(w.Ammo * Config.PickupAmmoFraction)))
			end
		end
		Notify:FireClient(player, "+" .. Config.PickupHeal .. " Health  +Ammo", Color3.fromRGB(120, 255, 120))
		crate:Destroy()
	end)

	Debris:AddItem(crate, 30)
end

---------------------------------------------------------------------
-- Zombie template
---------------------------------------------------------------------
local function buildManualRig()
	local model = Instance.new("Model")
	local function part(name, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1))
	root.Transparency = 1
	root.CanCollide = false
	local torso = part("Torso", Vector3.new(2, 2, 1))
	local head = part("Head", Vector3.new(2, 1, 1))
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	local la = part("Left Arm", Vector3.new(1, 2, 1))
	local ra = part("Right Arm", Vector3.new(1, 2, 1))
	local ll = part("Left Leg", Vector3.new(1, 2, 1))
	local rl = part("Right Leg", Vector3.new(1, 2, 1))

	local function motor(name, p0, p1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
	end
	local rootCF = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	motor("RootJoint", root, torso, rootCF, rootCF)
	motor("Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rl, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, ll, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	Instance.new("Animator").Parent = hum
	hum.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildZombieTemplate()
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[Zombies] Using fallback zombie rig:", model)
		model = buildManualRig()
	end
	model.Name = "Zombie"

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BodyColors") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("Accessory")
			or (d:IsA("LuaSourceContainer")) then
			d:Destroy()
		end
	end

	local skin = Color3.fromRGB(110, 160, 80)
	local colors = {
		Head = skin,
		["Left Arm"] = skin,
		["Right Arm"] = skin,
		Torso = Color3.fromRGB(95, 75, 55),
		["Left Leg"] = Color3.fromRGB(50, 60, 90),
		["Right Leg"] = Color3.fromRGB(50, 60, 90),
	}
	for name, color in pairs(colors) do
		local p = model:FindFirstChild(name)
		if p then p.Color = color end
	end

	-- Classic zombie pose: arms stretched forward
	local torso = model:FindFirstChild("Torso")
	if torso then
		local rs = torso:FindFirstChild("Right Shoulder")
		local ls = torso:FindFirstChild("Left Shoulder")
		if rs then rs.C0 = rs.C0 * CFrame.Angles(0, 0, math.rad(90)) end
		if ls then ls.C0 = ls.C0 * CFrame.Angles(0, 0, math.rad(-90)) end
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = hum
	end
	return model
end

local zombieTemplate = buildZombieTemplate()
local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = "rbxassetid://180426354" -- classic R6 walk

---------------------------------------------------------------------
-- Raycast helpers
---------------------------------------------------------------------
local function characterList()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(list, p.Character) end
	end
	return list
end

local function mapParams(extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = characterList()
	table.insert(list, zombieFolder)
	table.insert(list, fxFolder)
	table.insert(list, pickupFolder)
	if extra then table.insert(list, extra) end
	params.FilterDescendantsInstances = list
	return params
end

local function getZombieModel(inst)
	local current = inst
	while current and current.Parent ~= zombieFolder do
		current = current.Parent
		if current == workspace or current == nil then return nil end
	end
	return current
end

---------------------------------------------------------------------
-- Zombies
---------------------------------------------------------------------
local aliveZombies = 0
local zombiesLeft = 0

local function setZombiesLeft(n)
	zombiesLeft = math.max(0, n)
	ReplicatedStorage:SetAttribute("ZombiesLeft", zombiesLeft)
end

local function nearestPlayer(position)
	local best, bestDist
	for _, p in ipairs(alivePlayers()) do
		local root = p.Character.HumanoidRootPart
		local d = (root.Position - position).Magnitude
		if not bestDist or d < bestDist then
			best, bestDist = p.Character, d
		end
	end
	return best, bestDist
end

local function findSpawnPosition()
	local spawnFolder = workspace:FindFirstChild("ZombieSpawns")
	if spawnFolder then
		local points = {}
		for _, p in ipairs(spawnFolder:GetChildren()) do
			if p:IsA("BasePart") then table.insert(points, p) end
		end
		if #points > 0 then
			return points[rng:NextInteger(1, #points)].Position + Vector3.new(0, 3, 0)
		end
	end

	local players = alivePlayers()
	local params = mapParams()
	for _ = 1, 25 do
		local center = Vector3.zero
		if #players > 0 then
			center = players[rng:NextInteger(1, #players)].Character.HumanoidRootPart.Position
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(Config.SpawnDistanceMin, Config.SpawnDistanceMax)
		local p = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local result = workspace:Raycast(Vector3.new(p.X, center.Y + 200, p.Z), Vector3.new(0, -500, 0), params)
		-- Must land on open ground roughly level with the players (not on a roof)
		if result and result.Normal.Y > 0.7 and result.Position.Y < center.Y + 6 then
			local tooClose = false
			for _, pl in ipairs(players) do
				if (pl.Character.HumanoidRootPart.Position - result.Position).Magnitude < Config.SpawnDistanceMin * 0.7 then
					tooClose = true
					break
				end
			end
			if not tooClose then
				return result.Position + Vector3.new(0, 3, 0)
			end
		end
	end
	return Vector3.new(rng:NextNumber(-60, 60), 5, rng:NextNumber(-60, 60))
end

local function onZombieKilled(model)
	local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
	local uid = model:GetAttribute("LastHitBy")
	local player = uid and Players:GetPlayerByUserId(uid)
	local pd = player and data[player]
	if pd then
		local now = workspace:GetServerTimeNow()
		if now > pd.ComboExpire then
			pd.Combo = 0
		end
		pd.Combo += 1
		pd.BestCombo = math.max(pd.BestCombo, pd.Combo)
		pd.ComboExpire = now + Config.ComboTimeout
		pd.Kills += 1
		pd.Points += Config.PointsPerKill * pd.Combo
		updateStats(player)
		checkUnlocks(player, pd)
	end
	if root and rng:NextNumber() < Config.PickupDropChance then
		spawnPickup(root.Position - Vector3.new(0, 1.5, 0))
	end
end

local function runZombieAI(model, hum, root)
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local waypoints, wpIndex, lastPathTime = nil, 0, 0
	local lastAttack = 0

	while hum.Health > 0 and model.Parent == zombieFolder do
		local target, dist = nearestPlayer(root.Position)
		if target then
			local troot = target.HumanoidRootPart
			if dist <= Config.ZombieAttackRange then
				hum:MoveTo(troot.Position)
				if os.clock() - lastAttack >= Config.ZombieAttackCooldown then
					lastAttack = os.clock()
					local thum = target:FindFirstChildOfClass("Humanoid")
					if thum then thum:TakeDamage(Config.ZombieDamage) end
				end
			else
				local blocked = workspace:Raycast(root.Position, troot.Position - root.Position, mapParams())
				if not blocked or dist < 10 then
					waypoints = nil
					hum:MoveTo(troot.Position)
				else
					if not waypoints or os.clock() - lastPathTime > 1.5 then
						lastPathTime = os.clock()
						local ok = pcall(function()
							path:ComputeAsync(root.Position, troot.Position)
						end)
						if ok and path.Status == Enum.PathStatus.Success then
							waypoints = path:GetWaypoints()
							wpIndex = 2
						else
							waypoints = nil
						end
					end
					local wp = waypoints and waypoints[wpIndex]
					if wp then
						if wp.Action == Enum.PathWaypointAction.Jump then
							hum.Jump = true
						end
						hum:MoveTo(wp.Position)
						local flat = Vector3.new(wp.Position.X - root.Position.X, 0, wp.Position.Z - root.Position.Z)
						if flat.Magnitude < 3 then
							wpIndex += 1
						end
					else
						hum:MoveTo(troot.Position)
					end
				end
			end
		end

		-- Fell off the map: put it back at a spawn point
		if root.Position.Y < workspace.FallenPartsDestroyHeight + 50 then
			model:PivotTo(CFrame.new(findSpawnPosition()))
		end
		task.wait(0.2)
	end
end

local function spawnZombie(stats)
	local model = zombieTemplate:Clone()
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")

	hum.MaxHealth = stats.Health
	hum.Health = stats.Health
	hum.WalkSpeed = stats.Speed * rng:NextNumber(0.85, 1.15)

	model:PivotTo(CFrame.new(findSpawnPosition()) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = zombieFolder
	pcall(function() root:SetNetworkOwner(nil) end)

	aliveZombies += 1
	local counted = false
	local function remove(killed)
		if counted then return end
		counted = true
		aliveZombies -= 1
		setZombiesLeft(zombiesLeft - 1)
		if killed then onZombieKilled(model) end
	end
	hum.Died:Connect(function()
		remove(true)
		Debris:AddItem(model, 3)
	end)
	model.Destroying:Connect(function() remove(false) end)

	-- Walk animation
	local animator = hum:FindFirstChildOfClass("Animator")
	local ok, track = pcall(function() return animator:LoadAnimation(walkAnim) end)
	if ok and track then
		hum.Running:Connect(function(speed)
			if speed > 0.5 and not track.IsPlaying then
				track:Play()
			elseif speed <= 0.5 and track.IsPlaying then
				track:Stop()
			end
		end)
	end

	task.spawn(runZombieAI, model, hum, root)
end

local function clearWorld()
	zombieFolder:ClearAllChildren()
	pickupFolder:ClearAllChildren()
	fxFolder:ClearAllChildren()
	aliveZombies = 0
	setZombiesLeft(0)
end

---------------------------------------------------------------------
-- Shooting
---------------------------------------------------------------------
local function spreadDirection(dir, degrees)
	if degrees <= 0 then return dir end
	local a = math.rad(degrees)
	local cf = CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(rng:NextNumber(-a, a), rng:NextNumber(-a, a), 0)
	return cf.LookVector
end

local function castBullet(player, origin, dir, w)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = characterList()
	table.insert(exclude, fxFolder)
	table.insert(exclude, pickupFolder)

	local pos = origin
	local remaining = w.Range
	local pierced = 0
	while remaining > 0 do
		params.FilterDescendantsInstances = exclude
		local result = workspace:Raycast(pos, dir * remaining, params)
		if not result then
			return pos + dir * remaining
		end
		local model = getZombieModel(result.Instance)
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if not hum then
			return result.Position -- hit a wall
		end
		if hum.Health > 0 then
			local damage = w.Damage
			if result.Instance.Name == "Head" then
				damage *= Config.HeadshotMultiplier
			end
			model:SetAttribute("LastHitBy", player.UserId)
			hum:TakeDamage(damage)
			pierced += 1
			if pierced >= w.Pierce then
				return result.Position
			end
		end
		table.insert(exclude, model)
		remaining -= (result.Position - pos).Magnitude
		pos = result.Position
	end
	return pos
end

FireRemote.OnServerEvent:Connect(function(player, toolName, aimPos)
	if typeof(toolName) ~= "string" or typeof(aimPos) ~= "Vector3" then return end
	local pd = data[player]
	local w = weaponByName[toolName]
	if not pd or not w or not isAlive(player) then return end

	local char = player.Character
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= toolName then return end

	-- Rate limit (small tolerance for network jitter)
	local now = os.clock()
	if now - (pd.LastFire[toolName] or 0) < w.FireRate * 0.8 then return end
	pd.LastFire[toolName] = now

	local ammo = tool:GetAttribute("Ammo") or 0
	if ammo ~= -1 then
		if ammo <= 0 then return end
		tool:SetAttribute("Ammo", ammo - 1)
	end

	local handle = tool:FindFirstChild("Handle")
	local origin = handle and handle.Position or char.HumanoidRootPart.Position
	-- Don't allow shooting from far away from the character
	if (origin - char.HumanoidRootPart.Position).Magnitude > 8 then
		origin = char.HumanoidRootPart.Position
	end
	local baseDir = aimPos - origin
	if baseDir.Magnitude < 0.1 then return end
	baseDir = baseDir.Unit

	local endpoints = {}
	for _ = 1, w.Pellets do
		table.insert(endpoints, castBullet(player, origin, spreadDirection(baseDir, w.Spread), w))
	end
	ShotFx:FireAllClients(player, toolName, origin, endpoints)
end)

---------------------------------------------------------------------
-- Players
---------------------------------------------------------------------
local matchActive = false

local function onCharacterAdded(player, char)
	local pd = data[player]
	if not pd then return end
	player:WaitForChild("Backpack")
	for _, w in ipairs(Config.Weapons) do
		if pd.Unlocked[w.Name] then
			giveTool(player, w)
		end
	end
end

local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = ls
	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Parent = ls
	ls.Parent = player

	resetPlayerData(player)
	player.CharacterAdded:Connect(function(char)
		task.defer(onCharacterAdded, player, char)
	end)
	-- Joining mid-match or during intermission: spawn right away
	if matchActive or ReplicatedStorage:GetAttribute("State") ~= "GameOver" then
		task.spawn(function() player:LoadCharacter() end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	data[player] = nil
end)

-- Reset combos that timed out
task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		for player, pd in pairs(data) do
			if pd.Combo > 0 and now > pd.ComboExpire then
				pd.Combo = 0
				updateStats(player)
			end
		end
		task.wait(0.25)
	end
end)

---------------------------------------------------------------------
-- Main game loop
---------------------------------------------------------------------
while true do
	-- Wait for players
	while #Players:GetPlayers() == 0 do
		setState("Waiting", "Waiting for players...")
		task.wait(1)
	end

	-- Intermission (everyone can run around)
	for t = Config.Intermission, 1, -1 do
		setState("Intermission", "Game starts in " .. t)
		for _, p in ipairs(Players:GetPlayers()) do
			if not isAlive(p) then
				task.spawn(function() p:LoadCharacter() end)
			end
		end
		task.wait(1)
	end

	-- Start match
	clearWorld()
	for _, p in ipairs(Players:GetPlayers()) do
		resetPlayerData(p)
		task.spawn(function() p:LoadCharacter() end)
	end
	matchActive = true
	task.wait(2)

	local wave = 0
	while true do
		wave += 1
		local stats = Config.Wave(wave)
		ReplicatedStorage:SetAttribute("Wave", wave)
		setZombiesLeft(stats.Count)
		setState("Playing", "WAVE " .. wave)

		local toSpawn = stats.Count
		while zombiesLeft > 0 and #alivePlayers() > 0 do
			if toSpawn > 0 and aliveZombies < Config.MaxZombiesAlive then
				spawnZombie(stats)
				toSpawn -= 1
				task.wait(stats.SpawnInterval)
			else
				task.wait(0.25)
			end
		end

		if #alivePlayers() == 0 then break end

		for t = Config.WaveBreak, 1, -1 do
			setState("Break", ("Wave %d cleared! Next wave in %d"):format(wave, t))
			task.wait(1)
		end
	end

	matchActive = false
	setState("GameOver", ("GAME OVER  -  You reached wave %d"):format(wave))
	task.wait(Config.GameOverTime)
	clearWorld()
end
