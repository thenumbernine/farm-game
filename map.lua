local class = require 'ext.class'
local ffi = require 'ffi'
local vec3i = require 'vec-ffi.vec3i'
local Tile = require 'zelda.tile'

ffi.cdef[[
typedef uint8_t maptype_t;
]]

local Map = class()

-- voxel-based
function Map:init(size)	-- vec3i
	self.size = vec3i(size:unpack())
	self.map = ffi.new('maptype_t[?]', self.size:volume())
	ffi.fill(self.map, 0, self.size:volume())	-- 0 = empty
	for j=0,self.size.y-1 do
		for i=0,self.size.x-1 do
			self.map[i + self.size.x * j] = Tile.typeValues.SOLID
		end
	end
end

function Map:draw()
	local texpack = app.game.texpack
	texpack:bind()
	local index = 0
	for k=0,self.size.z-1 do
		for j=0,self.size.y-1 do
			for i=0,self.size.x-1 do
				local tiletype = self.map[index]
				local tile = Tile.types[tiletype]
				if tile then
					tile:render(i,j,k)
				end
				index = index + 1
			end
		end
	end
	texpack:unbind()
end

return Map
