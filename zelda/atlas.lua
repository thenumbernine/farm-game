-- TODO maybe just generate this file?
-- but idk idun wanna generated files in the zelda folder...
-- and the fromlua() doesn't like 'return's so ...
-- bleh i'm lazy
local path = require 'ext.path'
local table = require 'ext.table'
local fromlua = require 'ext.fromlua'
local atlasMap = assert(fromlua(assert(path'sprites/atlas.lua':read())))
local atlasKeys = table.keys(atlasMap)

-- return all keys of a specific prefix
local function getAllKeys(prefix)
	return atlasKeys:filter(function(key)
		return key:sub(1,#prefix) == prefix
	end)
end

return {
	atlasMap = atlasMap,
	atlasKeys = atlasKeys,
	getAllKeys = getAllKeys,
}
