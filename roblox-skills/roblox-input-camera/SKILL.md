---
name: roblox-input-camera
description: Use when handling player input (keyboard, mouse, touch, gamepad), aiming, shooting input, actions bound to keys or on-screen buttons, or controlling the camera (including a top-down or fixed-angle shooter camera) in a Roblox game.
---

# Input and camera

## Input principles
- Input is **client-only**. Read input on the client, translate it into intent, send intent to the server over a validated remote.
- Bind **actions**, not keys. Name actions for what they do (`"Reload"`, `"Fire"`, `"Interact"`), define the names as constants at the top of the file, and map multiple inputs to each.
- Support keyboard + mouse, touch and gamepad from the start. A feature that only works with a mouse is half-built on Roblox.

## ContextActionService (CAS)
Use `ContextActionService:BindAction(name, handler, createTouchButton, ...inputs)` for gameplay actions. It stacks and unbinds by context, creates optional touch buttons, and supports gamepad cleanly.

```lua
--!strict
local ContextActionService = game:GetService("ContextActionService")

local ACTION_RELOAD = "Reload"
local ACTION_FIRE = "Fire"

local function onReload(_actionName: string, inputState: Enum.UserInputState, _input: InputObject)
	if inputState == Enum.UserInputState.Begin then
		ReloadRemote:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

local function onFire(_actionName: string, inputState: Enum.UserInputState, _input: InputObject)
	-- Begin = start holding fire, End = stop (a client loop sends requests at the weapon interval)
	return Enum.ContextActionResult.Sink
end

local function bind()
	ContextActionService:BindAction(ACTION_RELOAD, onReload, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction(ACTION_FIRE, onFire, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
end

local function unbind()
	ContextActionService:UnbindAction(ACTION_RELOAD)
	ContextActionService:UnbindAction(ACTION_FIRE)
end
```
- Bind when the context begins (weapon equipped, round started, menu closed) and `UnbindAction` when it ends. Do not leave stale bindings.
- Debug in the Developer Console (F9) "Action Bindings" tab; it also shows bindings made by Roblox's default control and camera scripts, which can conflict with yours or steal inputs like right mouse.
- Return `Enum.ContextActionResult.Sink` to consume an input, `Pass` to let lower-priority handlers also see it. Use `BindActionAtPriority` when ordering matters.

## UserInputService (UIS)
- Use for raw polling such as `GetMouseLocation()`, `GetGamepadState`, or tracking `TouchStarted` / `TouchEnded` / `TouchMoved`.
- In `InputBegan`/`InputEnded` callbacks always check `gameProcessedEvent` and ignore input that GUIs already consumed.
- Do not rely on `Tool.Activated` for mobile hold-to-fire: it effectively emulates a mouse click, and holding a finger pans the camera instead. Drive automatic weapons from a client script using touch input or CAS and spawn effects through the server.

## Auto-fire pattern
Hold-to-fire runs a client loop at the weapon's fire interval while the action is held, sending `WeaponFire(direction)` for each shot. The server still enforces rate and ammo, so this loop is only for responsiveness and effects. Stop the loop on `End`, on unequip, on death, and when the UI opens.

## Aiming in a top-down game
Convert the pointer to a ground-plane point, then a direction from the character:

```lua
--!strict
local UserInputService = game:GetService("UserInputService")

local camera = workspace.CurrentCamera

local function getAimDirection(rootPosition: Vector3): Vector3?
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	if math.abs(ray.Direction.Y) < 1e-4 then return nil end
	-- intersect with a horizontal plane at the character's gun height
	local planeY = rootPosition.Y
	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then return nil end
	local hit = ray.Origin + ray.Direction * t
	local flat = Vector3.new(hit.X - rootPosition.X, 0, hit.Z - rootPosition.Z)
	if flat.Magnitude < 0.1 then return nil end
	return flat.Unit
end
```
- Send only the unit direction to the server; the server uses its own origin.
- On touch, use a virtual aim stick (second thumbstick UI) or auto-aim at the nearest enemy. On gamepad, read the right stick (`Enum.KeyCode.Thumbstick2`) and use its vector as the direction.
- Rotate the character locally for responsiveness (`AutoRotate = false` and set the root CFrame orientation on the client each frame), but treat visuals as cosmetic; the server's authoritative direction comes from the fire request.

## Top-down camera
- Set `camera.CameraType = Enum.CameraType.Scriptable` and update `camera.CFrame` every frame. Use `RunService:BindToRenderStep` with `Enum.RenderPriority.Camera.Value + 1`, so it runs after Roblox's camera logic.
- Place the camera above and slightly behind the character looking down at a fixed angle; smooth movement with a lerp/`Alpha` towards the target.
- Because the default control and camera scripts are disabled/overridden, test that mouse, touch, and gamepad movement still work. Movement is usually left to the default PlayerModule controls; only the camera is custom.
- Re-apply camera settings on character respawn and when menus open or close (menus may want `Custom` or a fixed camera).
- Mobile: if camera dragging conflicts with your touch controls, remember a custom camera script must handle `Touch` input itself; check `gameProcessedEvent` so thumbstick or button touches do not move the camera.

## Camera effects
Screen shake: apply a short-lived offset to `camera.CFrame` inside the same render step, decaying over time. Keep magnitudes small; provide a settings toggle.

## Settings and accessibility
Expose sensitivity (if applicable), keybinds if feasible, toggle vs hold for fire/aim, camera shake on/off. Persist via `roblox-player-data` (settings table).

## Cleanup
Store `RBXScriptConnection`s and bound render steps in the controller's Maid, and `UnbindFromRenderStep` / `UnbindAction` in `Destroy`.

## Checklist
- [ ] Actions named by purpose, defined as constants, bound and unbound by context.
- [ ] Keyboard/mouse, touch and gamepad paths all exist.
- [ ] Client sends only intent (direction, action), never results.
- [ ] Hold-to-fire is a client loop; the server enforces limits.
- [ ] Camera runs at the right render priority and survives respawn.

## Based on
Creator Hub ContextActionService reference (action naming, bind/unbind per context, touch and gamepad, Action Bindings debug tab); DevForum: "Trouble creating an automatic gun that can be used on mobile" (Tool.Activated limitation, use touch events or CAS), "Camera not moving on mobile", "Camera not work (Mobile)".
