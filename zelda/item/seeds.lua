--[[
TODO merge this with obj/seededground
--]]
local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local HoedGround = require 'zelda.obj.hoedground'
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
	local groundVoxel = map:getTile(x,y,z-1)
	if groundVoxel
	and groundVoxel.type == Tile.typeValues.Grass
	and topVoxelType == Tile.typeValues.Empty
	and map:hasObjType(x,y,z, HoedGround)
	then
		local half = -.5 * groundVoxel.shape
		local dx, dy, dz = x+.5, y+.5, z + half
		-- TODO how about a flag for objs whether they block seeds or not?
		if not map:hasObjType(dx,dy,dz, Plant) then
			assert(player:removeSelectedItem() == self)
			player.map:newObj{
				class = self.plantType.objClass,
				pos = vec3f(dx, dy, dz),
			}
		end
	end
end

return ItemSeeds 
