local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local HoedGround = require 'zelda.obj.hoedground'
local Item = require 'zelda.obj.item.item'

local ItemShovel = Item:subclass()

ItemShovel.name = 'shovel'

-- static method
function ItemShovel:useInInventory(player)
	local game = player.game
	local map = game.map
	
	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()
	
	for dz=0,-1,-1 do
		local tile = map:getTile(x,y,z+dz)
		if tile
		and tile.type == Tile.typeValues.Grass
		then
			tile.type = Tile.typeValues.Empty
			map:buildDrawArrays()
			player:addItem(require 'zelda.obj.dirt')
			return
		end
	end
end

return ItemShovel 
