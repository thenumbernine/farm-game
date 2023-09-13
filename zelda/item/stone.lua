--[[
TODO
zelda.item.log
zelda.item.stone
zelda.item.dirt
merge or something
--]]
local Voxel = require 'zelda.voxel'
local Item = require 'zelda.item.item'

local Stone = require 'zelda.obj.placeabletile'(Item):subclass()
Stone.classname = 'zelda.item.stone'

Stone.name = 'stone'
Stone.sprite = 'stone'
Stone.tileType = assert(Voxel.typeValues.Stone)

return Stone
