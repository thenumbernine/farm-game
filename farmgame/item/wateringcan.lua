local vec3f = require 'vec-ffi.vec3f'
local Voxel = require 'farmgame.voxel'
local WateredGround = require 'farmgame.obj.wateredground'
local Item = require 'farmgame.item.item'

local ItemWateringCan = Item:subclass()
ItemWateringCan.classname = 'farmgame.item.wateringcan'
ItemWateringCan.name = 'watering can'
ItemWateringCan.sprite = 'item'
ItemWateringCan.seq = 'wateringcan'

-- static method
function ItemWateringCan:useInInventory(player)
	local map = player.map

	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()
	local topVoxelType = map:getType(x,y,z)
	if topVoxelType == Voxel.typeValues.Empty then
		local voxel = map:getTile(x,y,z-1)
		if voxel 
		and voxel.type == Voxel.typeValues.Tilled
		then
			if not map:hasObjType(x,y,z, WateredGround) then
				local voxelType = Voxel.typeForName.Watered
				voxel.type = voxelType.index
				voxel.tex = math.random(#voxelType.texrects)-1
				player.map:newObj{
					class = WateredGround,
					pos = vec3f(x, y, z),
				}
				map:buildDrawArrays(x, y, z, x, y, z)	
			end
		end
	end
end

return ItemWateringCan 
