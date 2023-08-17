local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local Obj = require 'zelda.obj.obj'

-- TODO placeable item ...
-- ... two kinds?
-- 1. place item <-> change map data
-- 2. place item <-> place object

-- TODO do I need an 'Item' parent class?
-- not as long as I have .use() ...
-- - as a behavior?

local ItemBed = Obj:subclass()

ItemBed.name = 'bed'
ItemBed.sprite = 'bed'

-- TODO eventually dont do this 
ItemBed.useGravity = false
ItemBed.collidesWithTiles = false

function ItemBed:use(player)
	local game = player.game
	local map = game.map

	-- TODO traceline and then step back
	local dst = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor)

	-- TODO also make sure no objects exist here
	local topTile = map:get(dst:unpack())
	if topTile == Tile.typeValues.Empty 
	-- TODO and no solid object exists on this tile
	then
		local obj = player.items:remove(player.selectedItem)
		obj.pos:set((dst+.5):unpack())
	end
end

return ItemBed 
