local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local Obj = require 'farmgame.obj.obj'
local Game = require 'farmgame.game'

local WateredGround = Obj:subclass()
WateredGround.classname = ...
WateredGround.name = 'WateredGround' 

WateredGround.sprite = ''
WateredGround.seq = ''

WateredGround.useGravity = false
WateredGround.collidesWithTiles = false
WateredGround.collidesWithObjects = false
WateredGround.bbox = box3f{
	min = {0,0,0},
	max = {0,0,0},
}

-- TODO how to grow plants
WateredGround.removeDuration = Game.secondsPerDay - Game.secondsPerHour

WateredGround.onremove = function(self)
	local x, y, z = self.pos:unpack()
	local voxel = map:getTile(x, y, z)
	-- if someone's already changed it then don't switch
	-- TODO if someone changes a hoed tile (i.e. callback in the TilledVoxel class)
	--  then make sure to remove this
	if voxel.type == Voxel.typeValues.Watered
	-- TODO *AND* if there's no plants on this tile / growing on it
	then
		local voxelType = Voxel.typeForName.Tilled
		voxel.type = voxelType.index
		voxel.tex = math.random(#voxelType.texrects)-1
		self.map:buildDrawArrays(x, y, z, x, y, z)	
	end
end

return WateredGround 
