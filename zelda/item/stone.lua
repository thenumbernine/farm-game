--[[
TODO
zelda.item.log
zelda.item.stone
zelda.item.dirt
merge or something
--]]
local Tile = require 'zelda.tile'
local Item = require 'zelda.item.item'

local Stone = require 'zelda.obj.placeabletile'(Item):subclass()
Stone.classname = 'zelda.item.stone'

Stone.name = 'stone'
Stone.sprite = 'stone'
Stone.tileType = assert(Tile.typeValues.Stone)

return Stone
