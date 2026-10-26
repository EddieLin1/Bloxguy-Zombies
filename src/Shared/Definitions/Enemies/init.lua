--!strict
-- Index of every enemy definition in this folder. Add an enemy type by adding a ModuleScript here.

local Types = require(script.Parent.Parent.Types)
local DefinitionIndex = require(script.Parent.Parent.Util.DefinitionIndex)

type EnemyDefinition = Types.EnemyDefinition

local all: { EnemyDefinition } = DefinitionIndex.Load(script)
local byId: { [string]: EnemyDefinition } = {}
for _, definition in all do
	assert(byId[definition.Id] == nil, `Duplicate enemy id "{definition.Id}"`)
	byId[definition.Id] = definition
end

local Enemies = {}

function Enemies.Get(id: string): EnemyDefinition
	local definition = byId[id]
	if not definition then
		error(`Unknown enemy id "{id}"`, 2)
	end
	return definition
end

function Enemies.All(): { EnemyDefinition }
	return all
end

return Enemies
