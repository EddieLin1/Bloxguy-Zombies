--!strict
-- Requires every ModuleScript under a definitions folder, so adding an item means adding one file.

local DefinitionIndex = {}

function DefinitionIndex.Load(container: Instance): { any }
	local definitions = {}
	for _, child in container:GetChildren() do
		if child:IsA("ModuleScript") then
			-- Dynamic require: the analyser cannot resolve it, so cast through any.
			table.insert(definitions, (require :: any)(child))
		end
	end
	return definitions
end

return DefinitionIndex
