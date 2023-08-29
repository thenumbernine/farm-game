local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local Obj = require 'zelda.obj.obj'

-- TODO move to obj/item/ ?
-- or ... no need for obj/item/ at all?
-- idk how to organize
-- maybe Log (and tools) should be in zelda/items
-- and no need for zelda/obj/items
local Log = require 'zelda.obj.placeabletile'(Obj):subclass()

Log.name = 'log'
Log.sprite = 'log'
Log.tileType = assert(Tile.typeValues.Wood)

return Log
