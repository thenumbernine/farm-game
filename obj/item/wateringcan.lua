local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local WateredGround = require 'zelda.obj.wateredground'
local Item = require 'zelda.obj.item.item'

local ItemWateringCan = Item:subclass()

ItemWateringCan.name = 'watering can'

function ItemWateringCan:use(player)
	local game = player.game
	local map = game.map

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
		game:newObj{
			class = WateredGround,
			pos = vec3f(x+.5, y+.5, z),
		}
	end
end

return ItemWateringCan 
