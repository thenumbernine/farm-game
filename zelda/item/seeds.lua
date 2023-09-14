--[[
TODO merge this with obj/seededground
--]]
local vec3f = require 'vec-ffi.vec3f'
local Voxel = require 'zelda.voxel'
local Plant = require 'zelda.obj.plant'
local Item = require 'zelda.item.item'

local ItemSeeds = Item:subclass()
ItemSeeds.classname = 'zelda.item.seeds'

ItemSeeds.name = 'seeds'
ItemSeeds.sprite = 'seededground'
ItemSeeds.seq = 'stand'

-- static method
function ItemSeeds:useInInventory(player)
	local map = player.map
	
	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()
	local topVoxelType = map:getType(x,y,z)
	if topVoxelType == Voxel.typeValues.Empty then
		local groundVoxel = map:getTile(x,y,z-1)
		if groundVoxel
		and groundVoxel.type == Voxel.typeValues.Tilled
		then
			-- TODO how about a flag for objs whether they block seeds or not?
			local half = -.5 * groundVoxel.shape
			local dx, dy, dz = x+.5, y+.5, z + half
			if not map:hasObjType(dx,dy,dz, Plant) then
				assert(player:removeSelectedItem() == self)
				-- plant seeds
				player.map:newObj{
					class = self.plantType.objClass,
					pos = vec3f(dx, dy, dz),
				}
			end
		end
	end
end

return ItemSeeds 
