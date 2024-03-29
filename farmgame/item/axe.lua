local ffi = require 'ffi'
local vec3f = require 'vec-ffi.vec3f'
local Voxel = require 'farmgame.voxel'
local Item = require 'farmgame.item.item'

local ItemAxe = Item:subclass()
ItemAxe.classname = ...
ItemAxe.name = 'axe'
ItemAxe.sprite = 'item'
ItemAxe.seq = 'axe'

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

	local objIterUID = map:getNextObjIterUID()
	for dz=1,-1,-1 do
		local objs = map:getTileObjs(x,y,z)
		if objs then
			for _,obj in ipairs(objs) do
				if not obj.removeFlag
				and obj.iterUID ~= objIterUID
				and obj ~= player
				and obj.takesDamage
				and not obj.dead
				then
					obj.iterUID = objIterUID
					obj:damage(1, player, self)
					return
				end
			end
		end
	
		local tile = map:getTile(x,y,z+dz)
		if tile 
		and tile.type == Voxel.typeValues.Wood
		then
			tile.type = Voxel.typeValues.Empty
			-- change map type => change opacity => refresh light => refresh mesh
			map:updateMeshAndLight(x, y, z+dz)
			require 'farmgame.item.voxel.Wood':toItemObj{
				map = map,
				pos = vec3f(x,y,z+dz) + .5,
			}
			return
		end
	end
end

return ItemAxe 
