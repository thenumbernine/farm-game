local vec3f = require 'vec-ffi.vec3f'
local Item = require 'farmgame.item.item'

local ItemSword = Item:subclass()
ItemSword.classname = ...
ItemSword.name = 'sword'
ItemSword.sprite = 'item'
ItemSword.seq = 'sword'

-- static method
function ItemSword:useInInventory(player)
	local game = player.game
	local map = player.map

	if player.attackEndTime >= game.time then return end
	player.swingPos = vec3f(player.pos.x, player.pos.y, player.pos.z + .7)
	player.attackTime = game.time
	player.attackEndTime = game.time + player.attackDuration

	-- see if we hit anyone
	-- TODO iterate through all blocks within some range around us ...
	-- then iterate over their objs ...
	-- TODO TODO just do traceline.
	-- but nah, dif sword attacks
	local attackDist = 2	-- should match rFar in the draw code.  TODO as well consider object bbox / bounding radius.
	local objIterUID = map:getNextObjIterUID()
	for k =
		math.floor(player.pos.z - attackDist),
		math.floor(player.pos.z + attackDist)
	do
		for j =
			math.floor(player.pos.y - attackDist),
			math.floor(player.pos.y + attackDist)
		do
			for i =
				math.floor(player.pos.x - attackDist),
				math.floor(player.pos.x + attackDist)
			do
				if i >= 0 and i < map.size.x
				and j >= 0 and j < map.size.y
				and k >= 0 and k < map.size.z
				then
					local voxelIndex = i + map.size.x * (j + map.size.y * k)
					local objs = map.objsPerTileIndex[voxelIndex]
					if objs then
						for _,obj in ipairs(objs) do
							if not obj.removeFlag
							and obj ~= player
							and obj.iterUID ~= objIterUID
							and obj.takesDamage
							and not obj.dead
							then
								obj.iterUID = objIterUID
								if (player.pos - obj.pos):lenSq() < attackDist*attackDist then
									obj:damage(1, player, self)
								end
							end
						end
					end
				end
			end
		end
	end
end

return ItemSword
