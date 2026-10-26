--!strict
-- Workspace folders that hold runtime objects (enemies, pickups), created on first use.

local WorldFolders = {}

function WorldFolders.Get(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

return WorldFolders
