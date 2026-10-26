--!strict
-- Maps a definition's Firing.Type to its component. New firing behaviour = a new module plus one line here.

local WeaponTypes = require(script.Parent.Parent.WeaponTypes)

local registry: { [string]: WeaponTypes.FiringComponentClass } = {
	Hitscan = require(script.Hitscan) :: any,
}

return registry
