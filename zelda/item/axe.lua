local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local Item = require 'zelda.item.item'

local ItemAxe = Item:subclass()

ItemAxe.name = 'axe'

-- static method
function ItemAxe:useInInventory(player)
	local map = player.map
	local game = player.game

	-- TODO dif animation than sword
	if player.attackEndTime >= game.time then return end
	player.swingPos = vec3f(player.pos.x, player.pos.y, player.pos.z + .7)
	player.attackTime = game.time
	player.attackEndTime = game.time + player.attackDuration

	-- TODO traceline
	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()

	for dz=-1,1 do
		local tile = map:getTile(x,y,z-dz)
		if tile 
		and tile.type == Tile.typeValues.Wood
		then
			tile.type = Tile.typeValues.Empty
			map:buildDrawArrays()
			-- TODO instead of addItem, have it plop out an item object first ...
			-- in case the player's inventory is full
			player:addItem(require 'zelda.obj.log')
			return
		end

		local objs = map:getTileObjs(x,y,z)
		if objs then
			for _,obj in ipairs(objs) do
				if not obj.removeFlag
				and obj ~= player
				and obj.takesDamage
				and not obj.dead
				then
					obj:damage(1, player, self)
					return
				end
			end
		end
	end
end

return ItemAxe 
