local vec3f = require 'vec-ffi.vec3f'
local Voxel = require 'farmgame.voxel'
local Plant = require 'farmgame.obj.plant'
local Item = require 'farmgame.item.item'

local Hoe = Item:subclass()
Hoe.classname = ...

Hoe.name = 'hoe'
Hoe.sprite = 'item'
Hoe.seq = 'hoe'

-- static method, 'self' is subclass
function Hoe:useInInventory(player)
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
		-- TODO one tool for grass->dirt
		-- and another tool for dirt->tilled?
		and voxel.type == Voxel.typeValues.Grass
		then
			-- TODO test for any kind of solid object
			--  a better classification would be only allow watered/hoedground/seededground types (which should all have a common parent class / flag)
			local half = -.5 * voxel.shape
			local dx, dy, dz = x+.5, y+.5, z + half
			if not map:hasObjType(dx,dy,dz,Plant) then
				local voxelType = Voxel.typeForName.Tilled
				voxel.type = voxelType.index
				voxel.tex = math.random(#voxelType.texrects)-1
				-- hoed ground ... once it dies, switch the tile back to dirt
				map:newObj{
					class = require 'farmgame.obj.hoedground',
					pos = vec3f(x,y,z),
				}
				--map:updateLightAtPos(x, y, z+dz)	
				map:buildDrawArrays(x, y, z, x, y, z)	
			end
		end
	end
end

return Hoe 
