--[[
TODO
zelda.item.log
zelda.item.stone
zelda.item.dirt
merge or something
--]]
local Voxel = require 'zelda.voxel'
local Item = require 'zelda.item.item'

local Dirt = Item:subclass()
Dirt.classname = 'zelda.item.dirt'

Dirt.name = 'Dirt'
Dirt.sprite = 'dirt'
Dirt.tileType = assert(Voxel.typeValues.Grass)

return Dirt
