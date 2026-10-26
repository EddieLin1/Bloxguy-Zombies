---
name: roblox-ui
description: Use when designing or scripting any Roblox user interface: ScreenGuis, HUD (health, ammo, wave counter), menus, shop and inventory screens, health bars, notifications. Covers responsive scaling for mobile/desktop/console, layout constraints, code structure (controllers and component modules), data binding, and cleanup.
---

# Roblox UI

## Layout and scaling (no-code first)
Roughly half of Roblox players are on mobile, so design for the smallest screen first, then verify on desktop and console.

1. **Use the Device Emulator** in Studio (Test tab) with phones, tablets and Xbox presets while designing. Check portrait too if supported.
2. **Scale over Offset for size and position.** Offset is fixed pixels and breaks across screens. Use Scale values, then control proportions with modifiers.
3. **UIAspectRatioConstraint** keeps shapes consistent (square buttons stay square). Put artwork-heavy elements inside one frame that holds the constraint.
4. **UISizeConstraint** sets min/max pixel sizes so scaled elements do not become tiny or huge.
5. **AnchorPoint + Scale position** to pin elements to edges and centres (`AnchorPoint = (1,1)`, `Position = (1,0,1,0)` for bottom-right).
6. **Layout objects over manual positioning:** `UIListLayout`, `UIGridLayout`, `UIPadding`, `UIPageLayout`. Use `ScrollingFrame.AutomaticCanvasSize` so scrolling content sizes itself.
7. **UIScale** can scale an offset-designed UI uniformly (drive it from the viewport size in one LocalScript) when full scale-based design is impractical.
8. **UICorner and UIStroke** on Scale values (or fixed per-component) so rounded corners look the same across screens.
9. Offset is fine for things that should not scale: thin borders, fixed icon sizes inside constrained frames.
10. Mind the **Roblox platform UI**: top bar, chat, mobile jump/thumbstick area. Keep HUD clear of them; consider `ScreenInsets` / `IgnoreGuiInset` deliberately.
11. On mobile keep text minimal, make touch targets large, and keep corners free for thumbs. Lead with icons.

## Instances setup
- Set `ResetOnSpawn = false` on persistent ScreenGuis (HUD, menus), so they do not reset on death.
- One ScreenGui per major layer (HUD, Menus, Popups, Notifications) with sensible `DisplayOrder`.
- Name everything clearly; scripts find children by name, so renaming in Studio breaks code. Look up children by stable names in one place (the screen module's constructor) and keep the references, rather than scattering `FindFirstChild` calls.
- Build static layouts in Studio; only generate dynamic lists (inventory rows, scoreboard) in code from a template.

## Code structure
- **One bootstrap LocalScript** in `StarterPlayerScripts`, not LocalScripts inside GUI objects. It requires a `UIController` that sets up all screens.
- **One module per screen/component** (`HUD`, `ShopScreen`, `HealthBar`, `Toast`). Each exposes `new(guiRoot)`, `Show()`, `Hide()`, `Destroy()`, plus update methods.
- **Separate state from view** (MVC-like): a model/store holds state (ammo, wave, coins); controllers update the model from input and server events; views render from the model. UI modules should not know game rules.
- **Decouple UI from gameplay code.** Gameplay raises events (Attributes changing, remotes firing); UI subscribes. Never call UI functions from weapon or enemy code.
- Frameworks such as Fusion (reactive, declarative) are an option for complex UIs; plain modules with a small Signal and the pattern above work well and add no dependency. Pick one approach and use it consistently.

## Data binding from the server
- For continuously displayed values (wave, enemies remaining, countdown, a player's coins), put them in Attributes or leaderstat-like values and listen with `GetAttributeChangedSignal`. Update the label only when it changes.
- For discrete events (kill feed, wave cleared, purchase success/failure), use a RemoteEvent from the server.
- The UI never owns game truth. A shop button sends a buy request; the server validates and replies; the UI updates from the reply or the replicated currency.

```lua
--!strict
-- UI/HUD (module)
local HUD = {}
HUD.__index = HUD

export type HUD = typeof(setmetatable({} :: {
	_gui: ScreenGui,
	_maid: any,
}, HUD))

function HUD.new(gui: ScreenGui, maid: any): HUD
	local self = setmetatable({ _gui = gui, _maid = maid }, HUD)
	local waveLabel = gui.Wave :: TextLabel
	local function refresh()
		waveLabel.Text = `Wave {workspace:GetAttribute("Wave") or 0}`
	end
	maid:GiveTask(workspace:GetAttributeChangedSignal("Wave"):Connect(refresh))
	refresh()
	return self
end

function HUD.Destroy(self: HUD)
	self._maid:Destroy()
end

return HUD
```
(`maid:GiveTask` is the Maid from `roblox-performance-cleanup`.)

## Per-frame work
Do not update UI every frame unless animating something. Prefer change events, tweens (`TweenService`), or short timers. For smooth bars (health, cooldowns) tween `Size` on change instead of per-frame loops.

## Common components
- **Health/ammo HUD:** bind to attributes; flash on damage with a tween.
- **Enemy health bars:** use `BillboardGui` on a shared template with `Adornee`, show only for the nearest or recently damaged enemies, and limit count.
- **Damage numbers and toasts:** pool instances and recycle them, do not clone and destroy per hit.
- **Menus/shop:** a `PanelStack` or screen manager (push/pop, one visible at a time) keeps navigation simple and works with gamepad back/B.
- **Notifications:** queue them; show one at a time or a stacked max of N.

## Input across platforms
Menus must be operable by mouse, touch and gamepad. Use `ContextActionService` for actions that need touch buttons or gamepad bindings, and set a sensible `GuiService.SelectedObject` for gamepad focus. See `roblox-input-camera`.

## Cleanup
Every connection made by a screen goes into the screen's Maid and is destroyed in `Destroy`. Screens that hide and show repeatedly should connect once (on creation), not on every `Show`.

## Checklist
- [ ] Looks right in phone, tablet, desktop and console emulators.
- [ ] Sizes use Scale + constraints; layouts use Layout objects.
- [ ] No LocalScripts inside GUIs; logic in modules under one bootstrap.
- [ ] State is separate from view; UI reads replicated data and never decides game outcomes.
- [ ] Connections cleaned up; no per-frame updates without need.

## Based on
DevForum: "Designing UI - Tips and Best Practices" (Roblox UI team: emulator, scale over offset, constraints, platform UI), "How to scale and position UI - the CORRECT way!", "UI Design Starter Guide", "Why does my UI do this thing?", "Best practices for mobile users", "Decoupling game logic and UI", "UI code structure advice", "Proper UI Component handling?" (Fusion option).
