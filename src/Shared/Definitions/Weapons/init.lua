--!strict
-- Index of every weapon definition in this folder. Add a weapon by adding a ModuleScript here;
-- hotbar order follows UnlockCombo.

local Types = require(script.Parent.Parent.Types)
local DefinitionIndex = require(script.Parent.Parent.Util.DefinitionIndex)

type WeaponDefinition = Types.WeaponDefinition

local ordered: { WeaponDefinition } = DefinitionIndex.Load(script)
table.sort(ordered, function(a: WeaponDefinition, b: WeaponDefinition): boolean
	return a.UnlockCombo < b.UnlockCombo
end)

local byId: { [string]: WeaponDefinition } = {}
for _, definition in ordered do
	assert(byId[definition.Id] == nil, `Duplicate weapon id "{definition.Id}"`)
	byId[definition.Id] = definition
end

local Weapons = {}

function Weapons.Get(id: string): WeaponDefinition
	local definition = byId[id]
	if not definition then
		error(`Unknown weapon id "{id}"`, 2)
	end
	return definition
end

-- For ids that come from replicated data, where a miss should be ignored rather than error.
function Weapons.Find(id: string): WeaponDefinition?
	return byId[id]
end

-- Every weapon, sorted by UnlockCombo.
function Weapons.All(): { WeaponDefinition }
	return ordered
end

return Weapons
