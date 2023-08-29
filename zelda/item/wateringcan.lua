local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local WateredGround = require 'zelda.obj.wateredground'
local Item = require 'zelda.item.item'

local ItemWateringCan = Item:subclass()

ItemWateringCan.name = 'watering can'

-- static method
function ItemWateringCan:useInInventory(player)
	local map = player.map

	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()
	local topTile = map:get(x,y,z)
	local groundTile = map:get(x,y,z-1)
	if groundTile == Tile.typeValues.Grass
	and topTile == Tile.typeValues.Empty
	and not map:hasObjType(x,y,z, WateredGround)
	then
		player.map:newObj{
			class = WateredGround,
			pos = vec3f(x+.5, y+.5, z + .002),
		}
	end
end

return ItemWateringCan 
