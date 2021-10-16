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
	for k=0,self.size.z-1 do
		for j=0,self.size.y-1 do
			for i=0,self.size.x-1 do
				local value = Tile.typeValues.Empty
				if k % 8 == 0 then
					value = Tile.typeValues.Solid
				elseif k % 8 == 1 then
					if (i % 8 == 3 or i % 8 == 4)
					and (j % 8 == 3 or j % 8 == 4)
					then
						value = Tile.typeValues.Solid
					elseif i % 8 >= 2 and i % 8 <= 5
					and j % 8 >= 2 and j % 8 <= 5
					then
						value = Tile.typeValues.SolidBottomHalf
					end
				end
				self.map[i + self.size.x * (j + self.size.y * k)] = value
			end
		end
	end

	-- stairway
	for k=0,self.size.z-1 do
		local i = 3 + math.floor(math.sqrt(.5) * math.cos(.5 * math.pi * (k + .5)))
		local j = 3 + math.floor(math.sqrt(.5) * math.sin(.5 * math.pi * (k + .5)))
		self.map[i + self.size.x * (j + self.size.y * k)] = Tile.typeValues.Solid
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
				if tiletype > 0 then	-- skip empty
					local tile = Tile.types[tiletype]
					if tile then
						tile:render(i,j,k)
					end
				end
				index = index + 1
			end
		end
	end
	texpack:unbind()
end

-- i,j,k integers
function Map:get(i,j,k)
	if i < 0 or i >= self.size.x
	or j < 0 or j >= self.size.y
	or k < 0 or k >= self.size.z
	then
		--return Tile.typeValues.Empty
		return Tile.typeValues.Solid
	end
	return self.map[i + self.size.x * (j + self.size.y * k)]
end

return Map
