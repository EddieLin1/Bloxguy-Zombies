--!strict
-- Blood on the ground, in two layers (local only):
-- * Fresh stains: every splash, drip, trail, burst and death lays down a wet red splatter on the
--   surface below. After StainLifetime seconds it dries.
-- * Paint: permanent. The ground is split into square patches (PAINT_PATCH_SIZE studs). Each patch
--   that gets blood has a flat blood coat filling it edge to edge, so neighbouring coats join into one
--   even sheet of red instead of stacked circles; a coat is cut off where a wall crosses the patch,
--   so the red stops at the wall. Every stain drying there darkens the coat, and some of it seeps into
--   the neighbouring patches (NEIGHBOUR_SHARE, never through a wall), so over the waves the red
--   spreads until the fought-over ground is solid dark red (full saturation after BloodStainLimit
--   stains). On top, the first PAINT_SPLATTERS_PER_PATCH stains to dry in a patch stay as they were
--   (same shape, size and spin), dark and faint; later ones fade into the coat. Paint is never
--   removed, and its part count grows with how much floor is bloodied (one coat plus a few
--   splatters per patch at most), not with how many shots are fired, which keeps it light on the GPU.
-- What a splatter looks like:
-- * With an uploaded image (GameRules.BloodSplatterImages): one flat part with the splatter decal.
-- * Without one: a few flattened ovals in a random splatter layout (a lumpy core of overlapping blobs,
--   droplets flung to the sides and a streak shooting out), so it still is not a circle.
-- Every splatter gets a random size, stretch and spin, so no two match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local GameRules = require(Shared.Definitions.GameRules)

local FRESH_COLOR = Color3.fromRGB(140, 0, 0) -- oval colours
local PAINT_COLOR = Color3.fromRGB(85, 0, 0)
local FRESH_TINT = Color3.new(1, 1, 1) -- decal tints (multiply the image's own red)
local PAINT_TINT = Color3.fromRGB(150, 150, 150)
local SPLATTER_SCALE = 1.6 -- the images have empty margins, so draw them a bit larger than the ovals
local STRETCH_MIN = 0.65 -- each splatter is squashed to between this and 1 along one axis
local PAINT_PATCH_SIZE = 5 -- studs: blood drying within one patch darkens the same dried splatters
local PAINT_PATCH_HEIGHT = 2 -- studs: patches on floors this far apart vertically are separate
local PAINT_SPLATTERS_PER_PATCH = 3 -- dried splatters a patch keeps; later stains only darken them
local PAINT_MAX_OPACITY = 0.8 -- how dark a fully saturated patch gets
local PAINT_MIN_SHARE = 0.3 -- even one dried stain shows at this share of full darkness
local COAT_MAX_OPACITY = 0.9 -- how dark a fully soaked patch's coat gets (solid dark red)
local NEIGHBOUR_SHARE = 0.25 -- how much of each dried stain seeps into each of the 4 neighbouring patches
local WALL_PROBE_HEIGHT = 0.5 -- studs above the floor the wall checks run (below this counts as floor)
local SEEP_REACH = 0.25 -- studs into a neighbouring patch that seeping blood lands
local SPLAT_BASE_LIFT = 0.012 -- dried splatters sit above every coat
local THICKNESS = 0.05
local RAY_START_HEIGHT = 2 -- studs above the point the downward ray starts
local RAY_LENGTH = 15
local LAYER_STEP = 0.008 -- each splatter sits a hair higher than the last (above all its own ovals), so overlaps do not flicker
local LAYER_CYCLE = 10 -- after this many layers the offset starts again from the bottom
local FRESH_LIFT = 0.1 -- fresh stains sit above all paint (paint layers reach SPLAT_BASE_LIFT + LAYER_CYCLE * LAYER_STEP = 0.092)
local DRY_TIME = 1.5 -- seconds a fresh stain takes to fade as it soaks into the paint
local MAX_FRESH = 40 -- safety cap: beyond this many wet stains the oldest dries at once
local POOL_SIZE = 40

-- The oval splatter layout, in units of the splatter's size (1 = its full width)
local CORE_BLOBS = 2 -- overlapping ovals making the lumpy middle
local DROPLETS = 3
local STREAKS = 1
local OVAL_COUNT = CORE_BLOBS + DROPLETS + STREAKS
local OVAL_STEP = 0.001 -- studs between the ovals of one splatter

type Splatter = "Small" | "Medium" | "Large" | "Pool"
export type StainStyle = "Splash" | "Drip" | "Trail" | "Burst" | "Pool"

-- Size range (studs), opacity while wet (0 = invisible, 1 = solid), and which splatter images it may use
local STYLES: { [StainStyle]: { MinSize: number, MaxSize: number, Fresh: number, Splatters: { Splatter } } } = {
	Drip = { MinSize = 0.6, MaxSize = 1.2, Fresh = 0.55, Splatters = { "Small" } }, -- under pouring blood
	Splash = { MinSize = 1, MaxSize = 2.4, Fresh = 0.6, Splatters = { "Small", "Medium" } }, -- under a bullet hit
	Trail = { MinSize = 1.2, MaxSize = 2, Fresh = 0.5, Splatters = { "Medium", "Small" } }, -- behind a legless zombie
	Burst = { MinSize = 3.5, MaxSize = 5, Fresh = 0.6, Splatters = { "Large" } }, -- an exploding head
	Pool = { MinSize = 4, MaxSize = 6, Fresh = 0.35, Splatters = { "Pool" } }, -- faint pool where a zombie died
}

-- One splatter on the ground: either the decal part or the ovals are visible, never both.
type Splat = {
	Folder: Folder,
	DecalPart: Part,
	Decal: Decal,
	Ovals: { Part },
	UsesDecal: boolean,
}

type Stain = {
	Splat: Splat,
	Position: Vector3, -- on the surface
	Normal: Vector3,
	Dried: boolean,
	Timer: thread?,
}

type Patch = {
	X: number, -- patch grid coordinates
	Z: number,
	Coat: Part?, -- the soft blood coat under this patch, made when blood first reaches it
	Splats: { Splat }, -- the dried splatters kept here (at most PAINT_SPLATTERS_PER_PATCH)
	Stains: number, -- how much blood has dried here (seeped-in blood counts as a fraction)
}

local BloodStains = {}

local fresh: { Stain } = {}
local patches: { [string]: Patch } = {}
local freeSplats: { Splat } = {}
local layer = 0
local rng = Random.new()
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function makeFlatPart(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function newSplat(): Splat
	local folder = Instance.new("Folder")
	folder.Name = "BloodSplatter"
	local decalPart = makeFlatPart("Decal", folder)
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Transparency = 1
	decal.Parent = decalPart
	local ovals = {}
	for index = 1, OVAL_COUNT do
		local oval = makeFlatPart(`Oval{index}`, folder)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere -- squashed flat by the part's size: an oval
		mesh.Parent = oval
		table.insert(ovals, oval)
	end
	return { Folder = folder, DecalPart = decalPart, Decal = decal, Ovals = ovals, UsesDecal = false }
end

local function takeSplat(): Splat
	return table.remove(freeSplats) or newSplat()
end

local function releaseSplat(splat: Splat)
	splat.Folder.Parent = nil
	if #freeSplats < POOL_SIZE then
		table.insert(freeSplats, splat)
	else
		splat.Folder:Destroy()
	end
end

type LookTarget = { Instance: Instance, Goal: { [string]: any } }

-- The instances that show the blood and the properties to set on them for a look.
local function lookTargets(splat: Splat, opacity: number, wet: boolean): { LookTarget }
	local targets: { LookTarget } = {}
	if splat.UsesDecal then
		local goal: { [string]: any } = { Transparency = 1 - opacity, Color3 = if wet then FRESH_TINT else PAINT_TINT }
		table.insert(targets, { Instance = splat.Decal :: Instance, Goal = goal })
		return targets
	end
	for _, oval in splat.Ovals do
		local goal: { [string]: any } = { Transparency = 1 - opacity, Color = if wet then FRESH_COLOR else PAINT_COLOR }
		table.insert(targets, { Instance = oval :: Instance, Goal = goal })
	end
	return targets
end

local function setLook(splat: Splat, opacity: number, wet: boolean)
	for _, target in lookTargets(splat, opacity, wet) do
		for property, value in target.Goal do
			(target.Instance :: any)[property] = value
		end
	end
end

local function tweenLook(splat: Splat, opacity: number, wet: boolean): Tween?
	local last: Tween? = nil
	for _, target in lookTargets(splat, opacity, wet) do
		local tween = TweenService:Create(target.Instance, TweenInfo.new(DRY_TIME), target.Goal)
		tween:Play()
		last = tween
	end
	return last
end

-- Lays one oval flat in the splatter's frame: `u`, `v` (centre) and `length`, `width` are in
-- units of the splatter size, `angle` is which way its length points.
local function placeOval(oval: Part, frame: CFrame, size: number, u: number, v: number, length: number, width: number, angle: number, index: number)
	oval.Size = Vector3.new(math.max(length * size, 0.05), THICKNESS, math.max(width * size, 0.05))
	-- Each oval sits a hair above the previous one so overlapping ovals do not flicker
	oval.CFrame = frame * CFrame.new(u * size, index * OVAL_STEP, v * size) * CFrame.Angles(0, angle, 0)
end

-- A random splatter made of ovals: a lumpy core, droplets flung around it, and a streak shooting out.
local function layOutOvals(splat: Splat, frame: CFrame, size: number)
	local ovals = splat.Ovals
	local index = 1
	for blob = 1, CORE_BLOBS do
		local offset = if blob == 1 then 0 else rng:NextNumber(0.12, 0.25)
		local angle = rng:NextNumber(0, math.pi * 2)
		local length = if blob == 1 then rng:NextNumber(0.7, 0.85) else rng:NextNumber(0.4, 0.6)
		placeOval(ovals[index], frame, size, math.cos(angle) * offset, math.sin(angle) * offset, length, length * rng:NextNumber(0.6, 0.9), rng:NextNumber(0, math.pi), index)
		index += 1
	end
	for _ = 1, DROPLETS do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(0.45, 0.75)
		local drop = rng:NextNumber(0.07, 0.16)
		placeOval(ovals[index], frame, size, math.cos(angle) * distance, math.sin(angle) * distance, drop, drop, 0, index)
		index += 1
	end
	for _ = 1, STREAKS do
		local angle = rng:NextNumber(0, math.pi * 2)
		local length = rng:NextNumber(0.3, 0.5)
		local distance = 0.3 + length / 2
		-- An oval's length runs along its X axis; turn it to point outward from the centre
		placeOval(ovals[index], frame, size, math.cos(angle) * distance, math.sin(angle) * distance, length, rng:NextNumber(0.05, 0.09), -angle, index)
		index += 1
	end
end

-- Lays a splatter flat on a surface, about `size` studs across, with one of the allowed images if
-- uploaded, otherwise as ovals. Randomly stretched and spun.
local function placeSplat(splat: Splat, choices: { Splatter }, surface: Vector3, normal: Vector3, size: number)
	local image = GameRules.BloodSplatterImages[choices[rng:NextInteger(1, #choices)]]
	splat.UsesDecal = image ~= ""
	splat.Decal.Texture = image
	splat.Decal.Transparency = 1
	for _, oval in splat.Ovals do
		oval.Transparency = 1
	end

	-- A frame whose +Y points along the surface normal (lookAt points -Z at it; tip it back 90 degrees),
	-- randomly spun and stretched along one axis
	local flat = CFrame.lookAt(surface, surface + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	local frame = flat * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local stretch = rng:NextNumber(STRETCH_MIN, 1)
	if splat.UsesDecal then
		local drawn = size * SPLATTER_SCALE
		splat.DecalPart.Size = Vector3.new(drawn, THICKNESS, drawn * stretch)
		splat.DecalPart.CFrame = frame
	else
		layOutOvals(splat, frame, size)
		for _, oval in splat.Ovals do
			-- Squash the whole layout along the frame's Z axis
			local offset = frame:ToObjectSpace(oval.CFrame)
			oval.CFrame = frame * CFrame.new(offset.X, offset.Y, offset.Z * stretch) * offset.Rotation
		end
	end
end

local function nextLayer(): number
	layer = (layer + 1) % LAYER_CYCLE
	return THICKNESS / 2 + SPLAT_BASE_LIFT + layer * LAYER_STEP
end

local function refreshFilter()
	local ignore: { Instance } = { workspace.CurrentCamera }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, name in { Constants.Folders.Enemies, Constants.Folders.Pickups } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	params.FilterDescendantsInstances = ignore
end

local function getPatch(position: Vector3): Patch
	local x, z = math.floor(position.X / PAINT_PATCH_SIZE), math.floor(position.Z / PAINT_PATCH_SIZE)
	local key = `{x},{math.floor(position.Y / PAINT_PATCH_HEIGHT)},{z}`
	local existing = patches[key]
	if existing then
		return existing
	end
	local created: Patch = { X = x, Z = z, Coat = nil, Splats = {}, Stains = 0 }
	patches[key] = created
	return created
end

-- How far along the floor from `origin` (just above it) in `direction` before a wall, up to `distance`.
local function openDistance(origin: Vector3, direction: Vector3, distance: number): number
	if distance <= 0 then
		return 0
	end
	local hit = workspace:Raycast(origin + Vector3.new(0, WALL_PROBE_HEIGHT, 0), direction * distance, params)
	return if hit then hit.Distance else distance
end

-- The flat blood coat filling a patch, edge to edge, on the floor at `origin` (a spot on open floor
-- in the patch where blood landed). Any side with a wall between `origin` and the patch edge is cut
-- back to the wall, so the red stops at it. Square and level, so neighbours meet without overlapping.
-- Starts invisible.
local function ensureCoat(patch: Patch, origin: Vector3): Part
	local existing = patch.Coat
	if existing then
		return existing
	end
	local coat = Instance.new("Part")
	coat.Name = "BloodCoat"
	coat.Anchored = true
	coat.CanCollide = false
	coat.CanQuery = false
	coat.CanTouch = false
	coat.CastShadow = false
	coat.Material = Enum.Material.SmoothPlastic
	coat.Color = PAINT_COLOR
	coat.Transparency = 1

	local minX, minZ = patch.X * PAINT_PATCH_SIZE, patch.Z * PAINT_PATCH_SIZE
	local maxX, maxZ = minX + PAINT_PATCH_SIZE, minZ + PAINT_PATCH_SIZE
	local east = origin.X + openDistance(origin, Vector3.xAxis, maxX - origin.X)
	local west = origin.X - openDistance(origin, -Vector3.xAxis, origin.X - minX)
	local south = origin.Z + openDistance(origin, Vector3.zAxis, maxZ - origin.Z)
	local north = origin.Z - openDistance(origin, -Vector3.zAxis, origin.Z - minZ)

	coat.Size = Vector3.new(math.max(east - west, 0.05), THICKNESS, math.max(south - north, 0.05))
	coat.CFrame = CFrame.new((east + west) / 2, origin.Y + THICKNESS / 2, (south + north) / 2)
	coat.Parent = workspace.CurrentCamera
	patch.Coat = coat
	return coat
end

-- Adds dried blood to a patch: its coat and kept splatters get darker, up to full saturation.
local function addBlood(patch: Patch, amount: number)
	patch.Stains = math.min(patch.Stains + amount, GameRules.BloodStainLimit)
	local saturation = patch.Stains / GameRules.BloodStainLimit
	local coat = patch.Coat
	if coat then
		TweenService:Create(coat, TweenInfo.new(DRY_TIME), { Transparency = 1 - COAT_MAX_OPACITY * saturation }):Play()
	end
	local splatOpacity = PAINT_MAX_OPACITY * math.max(saturation, PAINT_MIN_SHARE)
	for _, splat in patch.Splats do
		tweenLook(splat, splatOpacity, false)
	end
end

-- Some of each dried stain seeps into the four neighbouring patches, so the red spreads outward. It
-- flows straight across the floor from where the stain dried, just over the patch edge, and never
-- through a wall.
local function seepIntoNeighbours(patch: Patch, origin: Vector3)
	local minX, minZ = patch.X * PAINT_PATCH_SIZE, patch.Z * PAINT_PATCH_SIZE
	local maxX, maxZ = minX + PAINT_PATCH_SIZE, minZ + PAINT_PATCH_SIZE
	local spots = {
		Vector3.new(maxX + SEEP_REACH, origin.Y, origin.Z),
		Vector3.new(minX - SEEP_REACH, origin.Y, origin.Z),
		Vector3.new(origin.X, origin.Y, maxZ + SEEP_REACH),
		Vector3.new(origin.X, origin.Y, minZ - SEEP_REACH),
	}
	for _, spot in spots do
		local offset = spot - origin
		local open = openDistance(origin, offset.Unit, offset.Magnitude) >= offset.Magnitude
		local result = open
			and workspace:Raycast(spot + Vector3.new(0, RAY_START_HEIGHT, 0), Vector3.new(0, -RAY_LENGTH, 0), params)
		-- Only onto the same floor, not down a ledge or up onto a box
		if result and math.abs(result.Position.Y - origin.Y) < PAINT_PATCH_HEIGHT then
			local neighbour = getPatch(result.Position)
			ensureCoat(neighbour, result.Position)
			addBlood(neighbour, NEIGHBOUR_SHARE)
		end
	end
end

-- Moves every part of a splatter along `offset`.
local function shiftSplat(splat: Splat, offset: Vector3)
	for _, part in splat.Folder:GetChildren() do
		if part:IsA("BasePart") then
			part.CFrame += offset
		end
	end
end

-- A drying stain becomes paint. The first PAINT_SPLATTERS_PER_PATCH stains to dry in a patch keep
-- their own splatter shape, sunk below the wet layer and turned dark; later ones fade away. Either
-- way the patch's coat gets darker, and some of the blood seeps into the neighbouring patches.
local function dry(stain: Stain)
	if stain.Dried then
		return
	end
	stain.Dried = true
	local index = table.find(fresh, stain)
	if index then
		table.remove(fresh, index)
	end
	local timer = stain.Timer
	if timer and coroutine.status(timer) ~= "dead" and timer ~= coroutine.running() then
		task.cancel(timer)
	end

	local patch = getPatch(stain.Position)
	ensureCoat(patch, stain.Position)

	if #patch.Splats < PAINT_SPLATTERS_PER_PATCH then
		-- Keep this splatter as permanent paint (it never goes back to the pool)
		shiftSplat(stain.Splat, -stain.Normal * FRESH_LIFT)
		stain.Splat.Folder.Name = "BloodPaint"
		table.insert(patch.Splats, stain.Splat)
	else
		local fade = tweenLook(stain.Splat, 0, true)
		if fade then
			fade.Completed:Once(function()
				releaseSplat(stain.Splat)
			end)
		else
			releaseSplat(stain.Splat)
		end
	end
	addBlood(patch, 1)
	seepIntoNeighbours(patch, stain.Position)
end

-- Lays a fresh stain on the ground below `position`. Does nothing if there is no ground below.
function BloodStains.Paint(position: Vector3, styleName: StainStyle)
	refreshFilter()
	local result = workspace:Raycast(position + Vector3.new(0, RAY_START_HEIGHT, 0), Vector3.new(0, -RAY_LENGTH, 0), params)
	if not result then
		return
	end
	local style = STYLES[styleName]
	local normal = result.Normal

	local splat = takeSplat()
	local surface = result.Position + normal * (nextLayer() + FRESH_LIFT)
	placeSplat(splat, style.Splatters, surface, normal, rng:NextNumber(style.MinSize, style.MaxSize))
	setLook(splat, style.Fresh, true)
	splat.Folder.Parent = workspace.CurrentCamera

	local stain: Stain = { Splat = splat, Position = result.Position, Normal = normal, Dried = false, Timer = nil }
	stain.Timer = task.delay(GameRules.StainLifetime, dry, stain)
	table.insert(fresh, stain)
	if #fresh > MAX_FRESH then
		dry(fresh[1])
	end
end

-- Wipes all blood off the ground, wet stains and permanent paint alike (when a new game starts).
function BloodStains.ClearAll()
	for _, stain in fresh do
		stain.Dried = true
		local timer = stain.Timer
		if timer and coroutine.status(timer) ~= "dead" then
			task.cancel(timer)
		end
		releaseSplat(stain.Splat)
	end
	table.clear(fresh)
	for _, patch in patches do
		local coat = patch.Coat
		if coat then
			coat:Destroy()
		end
		for _, splat in patch.Splats do
			splat.Folder:Destroy()
		end
	end
	table.clear(patches)
end

return BloodStains
