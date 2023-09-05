--[[
TODO
zelda.item.log
zelda.item.stone
zelda.item.dirt
merge or something
--]]
local Tile = require 'zelda.tile'
local Item = require 'zelda.item.item'

local Dirt = Obj:subclass()
Dirt.classname = 'zelda.item.dirt'

Dirt.name = 'Dirt'
Dirt.sprite = 'dirt'
Dirt.tileType = assert(Tile.typeValues.Grass)

return Dirt
