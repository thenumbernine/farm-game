local vec3f = require 'vec-ffi.vec3f'
local Voxel = require 'zelda.voxel'
local WateredGround = require 'zelda.obj.wateredground'
local Item = require 'zelda.item.item'

local ItemWateringCan = Item:subclass()
ItemWateringCan.classname = 'zelda.item.wateringcan'
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
	local groundVoxel = map:getTile(x,y,z-1)
	if groundVoxel 
	and groundVoxel.type == Voxel.typeValues.Grass
	and topVoxelType == Voxel.typeValues.Empty
	then
		local half = -.5 * groundVoxel.shape
		local dx, dy, dz = x+.5, y+.5, z + half
		if not map:hasObjType(dx,dy,dz, WateredGround) then
			player.map:newObj{
				class = WateredGround,
				pos = vec3f(dx, dy, dz),
			}
		end
	end
end

return ItemWateringCan 
