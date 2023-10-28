--[[
this is a placeholder for switching from hoed back to dirt after a day
--]]
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local Obj = require 'farmgame.obj.obj'
local Game = require 'farmgame.game'

local HoedGround = Obj:subclass()
HoedGround.classname = 'farmgame.obj.hoedground'
HoedGround.name = 'HoedGround'

HoedGround.sprite = ''	-- empty sprite
HoedGround.seq = ''		-- empty seq

HoedGround.useGravity = false
HoedGround.collidesWithTiles = false
HoedGround.collidesWithObjects = false
-- TODO disable collision <-> don't even link to tile?
HoedGround.bbox = box3f{
	min = {0,0,0},
	max = {0,0,0},
}

-- TODO how to gauge plant growth / hoed ground / watered ground ...
HoedGround.removeDuration = Game.secondsPerDay - Game.secondsPerHour

HoedGround.onremove = function(self)
	local x, y, z = self.pos:unpack()
	local voxel = map:getTile(x, y, z)
	-- if someone's already changed it then don't switch
	-- TODO if someone changes a hoed tile (i.e. callback in the TilledVoxel class)
	--  then make sure to remove this
	if voxel.type == Voxel.typeValues.Tilled
	-- TODO *AND* if there's no plants on this tile / growing on it
	then
		local voxelType = Voxel.typeForName.Dirt
		voxel.type = voxelType.index
		voxel.tex = math.random(#voxelType.texrects)-1
		self.map:buildDrawArrays(x, y, z, x, y, z)	
	end
end

return HoedGround 
