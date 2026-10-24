-- ClientMain (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Shooting input, bullet tracers, HUD, notifications and spectating.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local FireRemote = remotes:WaitForChild("Fire")
local ShotFx = remotes:WaitForChild("ShotFx")
local Notify = remotes:WaitForChild("Notify")

local weaponByName = {}
for _, w in ipairs(Config.Weapons) do
	weaponByName[w.Name] = w
end

---------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ZombieHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextScaled = true
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = props.Parent or gui
	return l
end

local waveLabel = label({ Name = "Wave", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0, 260, 0, 40), Text = "" })
local leftLabel = label({ Name = "ZombiesLeft", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.new(0, 260, 0, 22), Font = Enum.Font.GothamBold, Text = "" })

local pointsLabel = label({ Name = "Points", Position = UDim2.new(0, 16, 0, 16), Size = UDim2.new(0, 260, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, Text = "0 pts" })
local killsLabel = label({ Name = "Kills", Position = UDim2.new(0, 16, 0, 50), Size = UDim2.new(0, 260, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, Text = "Kills: 0" })

local comboFrame = Instance.new("Frame")
comboFrame.Name = "Combo"
comboFrame.BackgroundTransparency = 1
comboFrame.Position = UDim2.new(0, 16, 0, 84)
comboFrame.Size = UDim2.new(0, 220, 0, 70)
comboFrame.Visible = false
comboFrame.Parent = gui
local comboLabel = label({ Parent = comboFrame, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 210, 60), Text = "x1 COMBO" })
local barBack = Instance.new("Frame")
barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
barBack.BorderSizePixel = 0
barBack.Position = UDim2.new(0, 0, 0, 44)
barBack.Size = UDim2.new(1, 0, 0, 8)
barBack.Parent = comboFrame
local barFill = Instance.new("Frame")
barFill.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
barFill.BorderSizePixel = 0
barFill.Size = UDim2.new(1, 0, 1, 0)
barFill.Parent = barBack
local nextLabel = label({ Parent = comboFrame, Position = UDim2.new(0, 0, 0, 54), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, Text = "" })

local weaponLabel = label({ Name = "Weapon", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.new(0, 360, 0, 34), Text = "" })

local messageLabel = label({ Name = "Message", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.28, 0), Size = UDim2.new(0.7, 0, 0, 60), Text = "" })
local notifyLabel = label({ Name = "Notify", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.38, 0), Size = UDim2.new(0.5, 0, 0, 36), Text = "", TextTransparency = 1, TextStrokeTransparency = 1 })

-- Crosshair sits in the exact screen center (separate gui that ignores the top bar inset)
local crossGui = Instance.new("ScreenGui")
crossGui.Name = "CrosshairGui"
crossGui.ResetOnSpawn = false
crossGui.IgnoreGuiInset = true
crossGui.Parent = player.PlayerGui
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
crosshair.Size = UDim2.new(0, 22, 0, 22)
crosshair.BackgroundTransparency = 1
crosshair.Visible = false
crosshair.Parent = crossGui
for _, s in ipairs({ { UDim2.new(0, 2, 0, 8), UDim2.new(0.5, 0, 0, 0) }, { UDim2.new(0, 2, 0, 8), UDim2.new(0.5, 0, 1, 0) },
	{ UDim2.new(0, 8, 0, 2), UDim2.new(0, 0, 0.5, 0) }, { UDim2.new(0, 8, 0, 2), UDim2.new(1, 0, 0.5, 0) } }) do
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Size = s[1]
	line.Position = s[2]
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BorderSizePixel = 0
	line.Parent = crosshair
end

-- Game state display
local messageToken = 0
local function refreshState()
	local state = ReplicatedStorage:GetAttribute("State")
	local wave = ReplicatedStorage:GetAttribute("Wave") or 0
	local msg = ReplicatedStorage:GetAttribute("Message") or ""

	waveLabel.Text = (state == "Playing" or state == "Break") and ("WAVE " .. wave) or ""
	leftLabel.Text = state == "Playing" and ("Zombies left: " .. (ReplicatedStorage:GetAttribute("ZombiesLeft") or 0)) or ""

	messageToken += 1
	local token = messageToken
	messageLabel.Text = msg
	messageLabel.TextTransparency = 0
	messageLabel.TextStrokeTransparency = 0.4
	messageLabel.TextColor3 = state == "GameOver" and Color3.fromRGB(255, 70, 70) or Color3.new(1, 1, 1)
	if state == "Playing" then
		-- "WAVE X" banner fades out after a moment
		task.delay(2.5, function()
			if token == messageToken then
				TweenService:Create(messageLabel, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end
end
for _, attr in ipairs({ "State", "Wave", "Message" }) do
	ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(refreshState)
end
ReplicatedStorage:GetAttributeChangedSignal("ZombiesLeft"):Connect(function()
	if ReplicatedStorage:GetAttribute("State") == "Playing" then
		leftLabel.Text = "Zombies left: " .. (ReplicatedStorage:GetAttribute("ZombiesLeft") or 0)
	end
end)
refreshState()

local function refreshStats()
	pointsLabel.Text = (player:GetAttribute("Points") or 0) .. " pts"
	killsLabel.Text = "Kills: " .. (player:GetAttribute("Kills") or 0)
end
player:GetAttributeChangedSignal("Points"):Connect(refreshStats)
player:GetAttributeChangedSignal("Kills"):Connect(refreshStats)
refreshStats()

-- Notifications (new weapon, pickups)
local notifyToken = 0
Notify.OnClientEvent:Connect(function(text, color)
	notifyToken += 1
	local token = notifyToken
	notifyLabel.Text = text
	notifyLabel.TextColor3 = color or Color3.new(1, 1, 1)
	notifyLabel.TextTransparency = 0
	notifyLabel.TextStrokeTransparency = 0.4
	task.delay(2.5, function()
		if token == notifyToken then
			TweenService:Create(notifyLabel, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)

---------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------
local fxParent = workspace.CurrentCamera

local function drawTracer(a, b, color)
	local dist = (b - a).Magnitude
	if dist < 0.1 then return end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(0.12, 0.12, dist)
	p.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -dist / 2)
	p.Transparency = 0.2
	p.Parent = fxParent
	TweenService:Create(p, TweenInfo.new(0.1), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.12)
end

local function playShotSound(w, handle)
	if w.Sound == nil or w.Sound == "" or not handle then return end
	local s = Instance.new("Sound")
	s.SoundId = w.Sound
	s.Volume = 0.6
	s.Parent = handle
	s:Play()
	Debris:AddItem(s, 2)
end

-- Other players' shots
ShotFx.OnClientEvent:Connect(function(shooter, toolName, origin, endpoints)
	if shooter == player then return end
	local w = weaponByName[toolName]
	if not w then return end
	for _, e in ipairs(endpoints) do
		drawTracer(origin, e, w.Color)
	end
	local tool = shooter.Character and shooter.Character:FindFirstChild(toolName)
	playShotSound(w, tool and tool:FindFirstChild("Handle"))
end)

---------------------------------------------------------------------
-- Shooting
---------------------------------------------------------------------
---------------------------------------------------------------------
-- Always-on mouse lock (like permanent Shift Lock)
-- The mouse stays locked to the center, moving it turns the camera,
-- and your character always faces where the camera looks.
---------------------------------------------------------------------
local SHOULDER_OFFSET = Vector3.new(1.75, 0.5, 0)
player.CameraMinZoomDistance = 6

RunService:BindToRenderStep("ZombieMouseLock", Enum.RenderPriority.Camera.Value + 1, function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		hum.AutoRotate = false
		hum.CameraOffset = SHOULDER_OFFSET
		local look = workspace.CurrentCamera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	else
		-- Dead / spectating: give the mouse back
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)

---------------------------------------------------------------------
-- Up/down aiming: tilt the upper body / gun arm and head toward
-- where the camera is looking. Works for R15 and R6 characters.
-- Other players' tilt arrives through their "AimPitch" attribute.
---------------------------------------------------------------------
local AimRemote = remotes:WaitForChild("Aim")
local originalC0 = setmetatable({}, { __mode = "k" })
local smoothPitch = setmetatable({}, { __mode = "k" })
local lastSentPitch, lastSendTime = 0, 0

local function setJoint(motor, rotation)
	if not motor then return end
	if not originalC0[motor] then
		originalC0[motor] = motor.C0
	end
	motor.C0 = originalC0[motor] * rotation
end

local function applyAim(char, pitch)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if hum.RigType == Enum.HumanoidRigType.R15 then
		local upperTorso = char:FindFirstChild("UpperTorso")
		local head = char:FindFirstChild("Head")
		setJoint(upperTorso and upperTorso:FindFirstChild("Waist"), CFrame.Angles(pitch * 0.6, 0, 0))
		setJoint(head and head:FindFirstChild("Neck"), CFrame.Angles(pitch * 0.4, 0, 0))
	else
		-- R6 has no waist, so tilt the head and the gun arm instead
		local torso = char:FindFirstChild("Torso")
		if not torso then return end
		setJoint(torso:FindFirstChild("Neck"), CFrame.Angles(-pitch * 0.8, 0, 0))
		setJoint(torso:FindFirstChild("Right Shoulder"), CFrame.Angles(0, 0, pitch))
	end
end

RunService:BindToRenderStep("ZombieAimPitch", Enum.RenderPriority.Camera.Value + 2, function(dt)
	-- Local player: use the camera directly
	local look = workspace.CurrentCamera.CFrame.LookVector
	local myPitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), -1.3, 1.3)
	local myChar = player.Character
	if myChar then
		applyAim(myChar, myPitch)
		local now = os.clock()
		if math.abs(myPitch - lastSentPitch) > 0.02 and now - lastSendTime > 0.06 then
			lastSentPitch, lastSendTime = myPitch, now
			AimRemote:FireServer(myPitch)
		end
	end

	-- Other players: smoothly follow their replicated pitch
	local alpha = math.clamp(dt * 12, 0, 1)
	for _, other in ipairs(Players:GetPlayers()) do
		local char = other ~= player and other.Character
		if char then
			local target = char:GetAttribute("AimPitch") or 0
			local current = smoothPitch[char] or target
			current += (target - current) * alpha
			smoothPitch[char] = current
			applyAim(char, current)
		end
	end
end)

local firing = false
local lastShot = 0
local hooked = setmetatable({}, { __mode = "k" })

local function hookTool(tool)
	if not tool:IsA("Tool") or hooked[tool] then return end
	hooked[tool] = true
	tool.Activated:Connect(function() firing = true end)
	tool.Deactivated:Connect(function() firing = false end)
	tool.Unequipped:Connect(function() firing = false end)
end

local function onCharacter(char)
	firing = false
	char.ChildAdded:Connect(hookTool)
	for _, c in ipairs(char:GetChildren()) do hookTool(c) end

	-- Spectate a teammate after dying
	local hum = char:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		firing = false
		task.wait(2)
		if player.Character ~= char then return end
		for _, other in ipairs(Players:GetPlayers()) do
			local ohum = other ~= player and other.Character and other.Character:FindFirstChildOfClass("Humanoid")
			if ohum and ohum.Health > 0 then
				workspace.CurrentCamera.CameraSubject = ohum
				break
			end
		end
	end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then onCharacter(player.Character) end

local function getAimPosition()
	-- Aim at whatever is under the center crosshair
	local camera = workspace.CurrentCamera
	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { fxParent }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(exclude, p.Character) end
	end
	local pickups = workspace:FindFirstChild("Pickups")
	if pickups then table.insert(exclude, pickups) end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return result and result.Position or (ray.Origin + ray.Direction * 1000)
end

local rng = Random.new()
local function spreadDirection(dir, degrees)
	if degrees <= 0 then return dir end
	local a = math.rad(degrees)
	return (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(rng:NextNumber(-a, a), rng:NextNumber(-a, a), 0)).LookVector
end

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local w = tool and weaponByName[tool.Name]

	-- Crosshair + weapon/ammo display
	if w then
		crosshair.Visible = true
		local ammo = tool:GetAttribute("Ammo") or 0
		weaponLabel.Text = w.Name .. "   " .. (ammo == -1 and "∞" or tostring(ammo))
		weaponLabel.TextColor3 = (ammo == 0) and Color3.fromRGB(255, 80, 80) or Color3.new(1, 1, 1)
	else
		crosshair.Visible = false
		weaponLabel.Text = ""
	end

	-- Combo meter
	local combo = player:GetAttribute("Combo") or 0
	local expire = player:GetAttribute("ComboExpire") or 0
	local remaining = expire - workspace:GetServerTimeNow()
	if combo > 0 and remaining > 0 then
		comboFrame.Visible = true
		comboLabel.Text = "x" .. combo .. " COMBO"
		barFill.Size = UDim2.new(math.clamp(remaining / Config.ComboTimeout, 0, 1), 0, 1, 0)
		local nextW
		for _, cw in ipairs(Config.Weapons) do
			if cw.UnlockCombo > combo then
				nextW = cw
				break
			end
		end
		nextLabel.Text = nextW and ("Next: " .. nextW.Name .. " at x" .. nextW.UnlockCombo) or ""
	else
		comboFrame.Visible = false
	end

	-- Fire
	if not (firing and w) then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local now = os.clock()
	if now - lastShot < w.FireRate then return end
	if (tool:GetAttribute("Ammo") or 0) == 0 then return end
	lastShot = now
	if not w.Auto then
		firing = false
	end

	local aim = getAimPosition()
	FireRemote:FireServer(tool.Name, aim)

	-- Instant local tracers so shooting feels responsive
	local handle = tool:FindFirstChild("Handle")
	local origin = handle and handle.Position or char.HumanoidRootPart.Position
	local dir = aim - origin
	if dir.Magnitude > 0.1 then
		local length = math.min(dir.Magnitude, w.Range)
		for _ = 1, w.Pellets do
			drawTracer(origin, origin + spreadDirection(dir.Unit, w.Spread) * length, w.Color)
		end
	end
	playShotSound(w, handle)
end)
