local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local HoedGround = require 'zelda.obj.hoedground'
local Item = require 'zelda.item.item'

local ItemShovel = Item:subclass()

ItemShovel.name = 'shovel'

-- static method
function ItemShovel:useInInventory(player)
	local map = player.map
	local game = player.game

	-- TODO dif animation than sword
	if player.attackEndTime >= game.time then return end
	player.swingPos = vec3f(player.pos.x, player.pos.y, player.pos.z + .7)
	player.attackTime = game.time
	player.attackEndTime = game.time + player.attackDuration

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
			-- TODO here remove all the hoe and water and seeds and stuff somehow ...
			-- in fact, seeds => pick-up-able seeds?

			map:buildDrawArrays(
				x,y,z-dz,
				x,y,z-dz)
			-- TODO instead of addItem, have it plop out an item object first ...
			-- in case the player's inventory is full
			player:addItem(require 'zelda.obj.dirt')
			return
		end
	end
end

return ItemShovel 
