--[[
TODO
zelda.item.log
zelda.item.stone
zelda.item.dirt
merge or something
--]]
local Tile = require 'zelda.tile'
local Item = require 'zelda.item.item'

--[[
Right now placeabletile only adds the static member 'useInInventory'
and this member drives zelda.obj.* objects and zelda.item.* items that can be used in inventory.
So just use this in the 'itemClass' of a zelda.obj.item
--]]
local Log = require 'zelda.obj.placeabletile'(Item):subclass()
Log.classname = 'zelda.item.log'

Log.name = 'log'
Log.sprite = 'log'
Log.tileType = assert(Tile.typeValues.Wood)

return Log
