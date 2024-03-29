local ffi = require 'ffi'
local vec3f = require 'vec-ffi.vec3f'
local Voxel = require 'farmgame.voxel'
local Item = require 'farmgame.item.item'

local ItemShovel = Item:subclass()
ItemShovel.classname = ...
ItemShovel.name = 'shovel'
ItemShovel.sprite = 'item'
ItemShovel.seq = 'shovel'

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
	
	for dz=1,-1,-1 do
		local tile = map:getTile(x,y,z+dz)
		if tile
		and (
			tile.type == Voxel.typeValues.Grass
			or tile.type == Voxel.typeValues.Dirt
		)
		then
			tile.type = Voxel.typeValues.Empty
			-- TODO here remove all the hoe and water and seeds and stuff somehow ...
			-- in fact, seeds => pick-up-able seeds?
			map:updateMeshAndLight(x, y, z+dz)	
			-- TODO instead of addItem, have it plop out an item object first ...
			-- in case the player's inventory is full
			player:addItem(require 'farmgame.item.voxel.Dirt')
			return
		end
	end
end

return ItemShovel 
