local ffi = require 'ffi'
local template = require 'template'
local class = require 'ext.class'
local table = require 'ext.table'
local math = require 'ext.math'
local tolua = require 'ext.tolua'
local range = require 'ext.range'
local vector = require 'ffi.cpp.vector'
local vec2i = require 'vec-ffi.vec2i'
local vec3i = require 'vec-ffi.vec3i'
local vec3f = require 'vec-ffi.vec3f'
local vec2f = require 'vec-ffi.vec2f'
local vec4ub = require 'vec-ffi.vec4ub'
local matrix_ffi = require 'matrix.ffi'
local Image = require 'image'
local gl = require 'gl'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLSceneObject = require 'gl.sceneobject'
local GLGeometry = require 'gl.geometry'
local GLTex2D = require 'gl.tex2d'
local Tile = require 'zelda.tile'
local sides = require 'zelda.sides'


local lumBitSize = 4
-- TODO how about bitflags for orientation ... https://thenumbernine.github.io/symmath/tests/output/Platonic%20Solids/Cube.html
-- the automorphism rotation group size is 24 ... so 5 bits for rotations.  including reflection is 48, so 6 bits.
ffi.cdef(template([[
enum { CHUNK_BITSIZE = 5 };
enum { CHUNK_SIZE = 1 << CHUNK_BITSIZE };
enum { CHUNK_BITMASK = CHUNK_SIZE - 1 };
enum { CHUNK_VOLUME = 1 << (3 * CHUNK_BITSIZE) };

enum { LUM_BITSIZE = <?=lumBitSize?> };
enum { MAX_LUM = (1 << LUM_BITSIZE)-1 };

typedef uint32_t voxel_basebits_t;
typedef struct {
	voxel_basebits_t type : 10;	// map-type, this maps to zelda.tiles, which now holds {[0]=empty, stone, grass, wood}
	voxel_basebits_t tex : 10;	// tex = atlas per-tile to use
	
	// TODO change to 'shape'
	// enum: cube, half, slope, halfslope, stairs, fortification, fence, ... ?
	voxel_basebits_t half : 1;	// set this to use a half-high tile.  
	
	voxel_basebits_t rotx : 2;	// Euler angles, in 90' increments
	voxel_basebits_t roty : 2;
	voxel_basebits_t rotz : 2;
	voxel_basebits_t lumclean : 1;
	voxel_basebits_t lum : <?=lumBitSize?>;	//how much light this tile is getting
} voxel_t;

typedef struct {
	int16_t lumAlt;		//tallest tile that is opaque
	int16_t solidAlt;	//tallest tile that is solid
	float minAngle;
	float maxAngle;
} surface_t;
]], {
	lumBitSize = lumBitSize,
}))
assert(ffi.sizeof'voxel_t' == ffi.sizeof'voxel_basebits_t')

local voxel_t = ffi.metatype('voxel_t', {
	__index = {
		tileClass = function(self)
			return Tile.types[self.type]
		end,
	},
})


local Chunk = class()

-- static member
Chunk.bitsize = vec3i(5, 5, 5)
Chunk.size = Chunk.bitsize:map(function(x) return bit.lshift(1, x) end)
Chunk.bitmask = Chunk.size - 1
Chunk.volume = Chunk.size:volume()	-- same as 1 << bitsize:sum() (if i had a :sum() function...)

function Chunk:init(args)
	local map = assert(args.map)
	local app = map.game.app
	self.map = map
	self.pos = vec3i(assert(args.pos))
	
	self.v = ffi.new('voxel_t[?]', self.volume)
	ffi.fill(self.v, 0, ffi.sizeof'voxel_t' * self.volume)	-- 0 = empty

	self.surface = ffi.new('surface_t[?]', self.size.x * self.size.y)

	-- geometry
	self.vtxs = vector'vec3f_t'
	self.texcoords = vector'vec2f_t'
	self.colors = vector'vec4ub_t'

	local volume = self.volume

	-- [[ using reserve and heuristic of #cubes ~ #vtxs: brings time taken from 12 s to 0.12 s
	self.vtxs:reserve(3*volume)
	self.texcoords:reserve(3*volume)
	self.colors:reserve(3*volume)
	--]]

	-- TODO Don't reallocate gl buffers each time.
	-- OpenGL growing buffers via glCopyBufferSubData:
	-- https://stackoverflow.com/a/27751186/2714073

	self.vtxBuf = GLArrayBuffer{
		size = ffi.sizeof(self.vtxs.type) * self.vtxs.capacity,
		data = self.vtxs.v,
		usage = gl.GL_DYNAMIC_DRAW,
	}:unbind()

	self.texcoordBuf = GLArrayBuffer{
		size = ffi.sizeof(self.texcoords.type) * self.texcoords.capacity,
		data = self.texcoords.v,
		usage = gl.GL_DYNAMIC_DRAW,
	}:unbind()

	self.colorBuf = GLArrayBuffer{
		size = ffi.sizeof(self.colors.type) * self.colors.capacity,
		data = self.colors.v,
		usage = gl.GL_DYNAMIC_DRAW,
	}:unbind()

	-- TODO put this in a GLSceneObject object instead
	-- and give that its own set of attrs, uniforms, shader, geometry
	self.sceneObj = GLSceneObject{
		geometry = GLGeometry{
			mode = gl.GL_TRIANGLES,
			count = self.vtxs.size,
		},
		program = app.mapShader,
		attrs = {
			vertex = {
				buffer = self.vtxBuf,
				type = gl.GL_FLOAT,
				size = 3,
			},
			texcoord = {
				buffer = self.texcoordBuf,
				type = gl.GL_FLOAT,
				size = 2,
			},
			color = {
				buffer = self.colorBuf,
				type = gl.GL_UNSIGNED_BYTE,
				size = 4,
				normalize = true,
			},
		},
		texs = {},
	}

	local function newreserve(self, newcap)
		if newcap <= self.capacity then return end
		print('asked for resize to', newcap, 'when our cap was', self.capacity)
		error'here'
	end
	self.vtxs.reserve = newreserve
	self.texcoords.reserve = newreserve
	self.colors.reserve = newreserve
end

-- TODO 
-- 1) divide map into chunks 
-- 2) grow-gl-buffers functionality 
function Chunk:buildDrawArrays()
	local map = self.map
	local app = map.game.app
	self.vtxs:resize(0)
	self.texcoords:resize(0)
	self.colors:resize(0)
	local atlasDx = 1/tonumber(app.spriteAtlasTex.width)
	local atlasDy = 1/tonumber(app.spriteAtlasTex.height)
	local index = 0
	for dk=0,self.size.z-1 do
		local k = bit.bor(dk, bit.lshift(self.pos.z, self.bitsize.z))
		for dj=0,self.size.y-1 do
			local j = bit.bor(dj, bit.lshift(self.pos.y, self.bitsize.y))
			for di=0,self.size.x-1 do
				local i = bit.bor(di, bit.lshift(self.pos.x, self.bitsize.x))
				local voxel = self.v[index]
				local voxelTypeIndex = voxel.type
				if voxelTypeIndex > 0 then	-- skip empty
					local voxelType = Tile.types[voxelTypeIndex]
					if voxelType then
						local texrect = voxelType.texrects[voxel.tex+1]
						if not texrect then
							print("voxelType "..voxelTypeIndex.." has "..#voxelType.texrects.." texrects but index was "..voxel.tex)
						else
							if voxelType.isUnitCube then
								if voxel.half == 0 then
									-- full cube
									assert(voxelType.cubeFaces)
									-- faceIndex is 1-based but lines up with sides bitflags
									for faceIndex,faces in ipairs(voxelType.cubeFaces) do
										local ofsx, ofsy, ofsz = sides.dirs[faceIndex]:unpack()
										local nx = i + ofsx
										local ny = j + ofsy
										local nz = k + ofsz
										local drawFace = true
										-- TODO test if it's along the sides, if not just use offset + step
										-- if so then use map:getType
										local nbhdVoxel = map:getTile(nx, ny, nz)
										local lum = 0
										if nbhdVoxel then
											lum = nbhdVoxel.lum
											if nbhdVoxel.half == 0 then
												local nbhdVoxelTypeIndex = nbhdVoxel.type
												-- only if the neighbor is solid ...
												if nbhdVoxelTypeIndex > 0
												then
													local nbhdVoxelType = Tile.types[nbhdVoxelTypeIndex]
													if nbhdVoxelType then
														-- if we're a cube but our neighbor isn't then build our surface
														if nbhdVoxelType.isUnitCube
														-- or if we're a cube and our neighbor is also ... but one of us is transparent, and our types are different
														and not (
															(voxelType.transparent or nbhdVoxelType.transparent)
															and voxelType ~= nbhdVoxelType
														)
														then
															drawFace = false
														end
													end
												end
											end
										end
										if drawFace then
											-- 2 triangles x 3 vtxs per triangle
											for ti=1,6 do
												local vi = Tile.unitQuadTriIndexes[ti]
												local vtxindex = faces[vi]
												local v = voxelType.cubeVtxs[vtxindex+1]

												local c = self.colors:emplace_back()
												--local l = 255 * v[3]
												local l = lum * (255/ffi.C.MAX_LUM)
												c:set(l, l, l, 255)

												local tc = self.texcoords:emplace_back()
												tc:set(
													(texrect.pos[1] + voxelType.unitquad[vi][1] * texrect.size[1] + .5) * atlasDx,
													(texrect.pos[2] + voxelType.unitquad[vi][2] * texrect.size[2] + .5) * atlasDy
												)

												local vtx = self.vtxs:emplace_back()
												vtx:set(i + v[1], j + v[2], k + v[3])
											end
										end
									end
								else
									-- half cube
									-- TODO generalize all this by having side bigflags for this voxel blocks
									-- vs side bitflags for what our neighbor blocks
									-- and then if the neighbors flag's opposite matches this flag then skip this side.
									assert(voxelType.cubeFaces)
									-- faceIndex is 1-based but lines up with sides bitflags
									for faceIndex,faces in ipairs(voxelType.cubeFaces) do
										
										local ofsx, ofsy, ofsz = sides.dirs[faceIndex]:unpack()
										local nx = i + ofsx
										local ny = j + ofsy
										local nz = k + ofsz
										
										local nbhdVoxelIsUnitCube
										-- for half-tile we can only block the bottom
										-- so TODO only do this test when faceIndex is the bottom
										local lum = voxel.lum
										if faceIndex == sides.indexes.zm then
											local nbhdVoxel = map:getTile(nx, ny, nz)
											if nbhdVoxel then
												lum = nbhdVoxel.lum
												local nbhdVoxelTypeIndex = nbhdVoxel.type
												-- only if the neighbor is solid ...
												if nbhdVoxelTypeIndex > 0
												and nbhdVoxel.half == 0
												then
													local nbhdVoxelType = Tile.types[nbhdVoxelTypeIndex]
													if nbhdVoxelType then
														nbhdVoxelIsUnitCube = nbhdVoxelType.isUnitCube
													end
												end
											end
										end
										--]]
										if not nbhdVoxelIsUnitCube then
											-- 2 triangles x 3 vtxs per triangle
											for ti=1,6 do
												local vi = Tile.unitQuadTriIndexes[ti]
												local vtxindex = faces[vi]
												local v = voxelType.cubeVtxs[vtxindex+1]

												local c = self.colors:emplace_back()
												--local l = 255 * v[3]
												local l = lum * (255/ffi.C.MAX_LUM)
												c:set(l, l, l, 255)

												local tc = self.texcoords:emplace_back()
												tc:set(
													(texrect.pos[1] + voxelType.unitquad[vi][1] * texrect.size[1] + .5) * atlasDx,
													(texrect.pos[2] + voxelType.unitquad[vi][2] * texrect.size[2] + .5) * atlasDy
												)

												local vtx = self.vtxs:emplace_back()
												vtx:set(i + v[1], j + v[2], k + v[3] * .5)
											end
										end
									end						

								end
							else
								-- arbitrary geometry
								print'TODO'
							end
						end
					end
				end
				index = index + 1
			end
		end
	end

	-- 184816 vertexes total ...
	-- ... from 196608 cubes
--[[	
	local volume = self.volume
	print('volume', volume)
	print('vtxs', self.vtxs.size)
--]]

	local vtxSize = self.vtxs.size * ffi.sizeof(self.vtxs.type)
	local texcoordSize = self.texcoords.size * ffi.sizeof(self.texcoords.type)
	local colorSize = self.colors.size * ffi.sizeof(self.colors.type)	

	if vtxSize > self.vtxBuf.size then
		print'TODO needs vtxBuf resize'
		-- create a new buffer
		-- copy old onto new
		-- update new buffer in GLAttribute object
		-- then rebind buffer in GLSceneObject's .vao
		return
	end
	if texcoordSize > self.texcoordBuf.size then
		print'TODO needs texcoordBuf resize'
		return
	end
	if colorSize > self.colorBuf.size then
		print'TODO needs colorBuf resize'
		return
	end

	self.vtxBuf:bind():updateData(0, vtxSize)
	self.texcoordBuf:bind():updateData(0, texcoordSize)
	self.colorBuf:bind():updateData(0, colorSize)
		:unbind()

	self.sceneObj.geometry.count = self.vtxs.size
end

function Chunk:draw(app, game)
	self.sceneObj.uniforms.playerViewPos = game.playerViewPos.s
	self.sceneObj.uniforms.mvMat = app.view.mvMat.ptr
	self.sceneObj.uniforms.projMat = app.view.projMat.ptr
	self.sceneObj.uniforms.useSeeThru = 1
	-- angle 0 = midnight
	local timeOfDay = (game.time / game.secondsPerDay) % 1
	self.sceneObj.uniforms.sunAngle = 2 * math.pi * timeOfDay
	-- just bind as we go, not in sceneObj
	--self.sceneObj.texs[1] = app.spriteAtlasTex
	--self.sceneObj.texs[2] = self.sunAngleTex
	self.sceneObj:draw()
end

function Chunk:buildAlts()
	local baseAlt = self.pos.z * self.size.z
	for j=0,self.size.y-1 do
		for i=0,self.size.x-1 do
			local surface = self.surface + (i + self.size.x * j)
			
			local k=self.size.z-1
			while k > 0 do
				local tileInfo = self.v + (i + self.size.x * (j + self.size.y * k))
				if tileInfo.type > 0 then
					local tileClass = Tile.types[tileInfo.type]
					if tileClass.solid then
						surface.solidAlt = k + baseAlt
						break
					end
				end
				k = k - 1
			end
		
			local k=self.size.z-1
			while k > 0 do
				local tileInfo = self.v + (i + self.size.x * (j + self.size.y * k))
				if tileInfo.type > 0 then
					local tileClass = Tile.types[tileInfo.type]
					if not tileClass.transparent then
						surface.lumAlt = k + baseAlt 
						break
					end
				end
				k = k - 1
			end
		end
	end
end

function Chunk:calcSunAngles()
	local map = self.map

	-- now that we have all altitudes, check sun light
	-- TODO a better lighting model, but meh lazy
	for j=0,self.size.y-1 do
		local y = j + bit.lshift(self.pos.y, self.bitsize.y)
		for i=0,self.size.x-1 do
			local x = i + bit.lshift(self.pos.x, self.bitsize.x)
			local surface = self.surface + (i + self.size.x * j)
--print(i,j ,surface.lumAlt)
			local alt = surface.lumAlt
			surface.minAngle = 0
			surface.maxAngle = 2 *math.pi
			for x2=0,map.size.x-1 do
				if x2 ~= x then
					local dx = x2 - x
					local ci2 = bit.rshift(x2, self.bitsize.x)
					local di2 = bit.band(x2, self.bitmask.x)
					local chunk2 = map.chunks[ci2 + map.sizeInChunks.x * (self.pos.y + map.sizeInChunks.y * (map.sizeInChunks.z-1))]
					assert(chunk2)
					local alt2 = chunk2.surface[di2 + self.size.x * j].lumAlt
					local dz = alt2 - alt
					local angle = (math.atan2(dx, -dz) + 2 * math.pi) % (2 * math.pi)
--print('x2', x2, 'alt2', alt2, 'dx', dx, 'dz', dz, 'angle', angle)
					if x2 < x then
						-- west = setting sun, pick the minimum maxAngle
						surface.maxAngle = math.min(surface.maxAngle, angle)
					else
						-- east = rising sun, pick the maximum minAngle
						surface.minAngle = math.max(surface.minAngle, angle)
					end
				end
			end
--print('result minAngle', surface.minAngle, 'maxAngle', surface.maxAngle)
		end
	end

	-- now turn it into a texture because i'm really lazy and sloppy
	print("building sun angle tex. don't do this too often.")
	self.sunAngleTex = GLTex2D{
		image = Image(self.size.x, self.size.y, 4, 'float', function(i,j)
			local minAngle = self.surface[i + self.size.x * j].minAngle
			local maxAngle = self.surface[i + self.size.x * j].maxAngle
			return
				minAngle,
				maxAngle,
				0, 1
		end),
		internalFormat = assert(gl.GL_RGBA32F),
		format = gl.GL_RGBA,
		type = gl.GL_FLOAT,
		minFilter = gl.GL_NEAREST,
		magFilter = gl.GL_NEAREST,
		--magFilter = gl.GL_LINEAR,	-- looks nice but bad at edges ... unless i manually add a border and copy ghost cells between chunks ... maybe ...
		wrap = {
			s = gl.GL_REPEAT,
			t = gl.GL_REPEAT,
		},
	}:unbind()
end

--[[
Make sure you run buildAlts first
This sets the light level of every block above the lumalt to be full.
And diminishes beneath.
And then something about dynamic lights and flood fill.
--]]
function Chunk:initLight()
	local baseAlt = self.pos.z * self.size.z
	local sliceSize = self.size.x * self.size.y
	local voxelSlice = self.v + self.volume - sliceSize
	for k=self.size.z-1,0,-1 do
		local surf = self.surface
		local voxel = voxelSlice
		for j=0,self.size.y-1 do
			for i=0,self.size.x-1 do
				if k == self.size.z-1
				or k >= surf[0].lumAlt - baseAlt 
				then
					voxel.lum = ffi.C.MAX_LUM
					voxel.lumclean = 1
				else
					-- slowly decrement?
					--voxel.lum = math.max(0, voxel[sliceSize].lum - 1)
					-- or just zero?
					voxel.lum = 0
					voxel.lumclean = 0
				end
				voxel = voxel + 1
				surf = surf + 1
			end
		end
		voxelSlice = voxelSlice - sliceSize
	end
	assert(voxelSlice == self.v - sliceSize)
end

local Map = class()

Map.Chunk = Chunk

-- voxel-based
--[[
args =
	game = game
	sizeInChunks = vec3i
	chunkData = (optional) xyz major order, per-chunk
--]]
function Map:init(args)
	self.game = assert(args.game)
	local game = self.game
	local app = game.app

	self.objs = table()
	-- use this when iterating to not double up on objs linked to multiple tiles
	self.objIterUID = ffi.cast('uint64_t', 0)

	-- key = index in map.objsPerTileIndex = offset of the tile in the map
	-- value = list of all objects on that tile
	self.objsPerTileIndex = {}

	self.sizeInChunks = vec3i(assert(args.sizeInChunks))
	self.chunkVolume = self.sizeInChunks:volume()
	self.size = self.sizeInChunks:map(function(x,i) return x * Chunk.size.s[i] end)
	self.volume = self.size:volume()

	-- 0-based index, based on chunk position
	self.chunks = {}

	-- create the chunks
	do
		local chunkIndex = 0
		for k=0,self.sizeInChunks.z-1 do
			for j=0,self.sizeInChunks.y-1 do
				for i=0,self.sizeInChunks.x-1 do
					self.chunks[chunkIndex] = Chunk{
						map = self,
						pos = vec3i(i,j,k),
					}
					chunkIndex = chunkIndex + 1
				end
			end
		end
	end

	if args.chunkData then
		assert(#args.chunkData == self.volume * ffi.sizeof'voxel_t')
		local p = ffi.cast('voxel_t*', ffi.cast('char*', args.chunkData))
		for chunkIndex=0,self.chunkVolume-1 do
			local chunk = self.chunks[chunkIndex]
			ffi.copy(chunk.v, p + chunkIndex * Chunk.volume, Chunk.volume * ffi.sizeof'voxel_t')
		end
	end
end

function Map:getNextObjIterUID()
	self.objIterUID = self.objIterUID + 1
	return self.objIterUID
end

function Map:buildDrawArrays(
	minx, miny, minz,
	maxx, maxy, maxz
)
	minx = bit.rshift(minx, Chunk.bitsize.x)
	miny = bit.rshift(miny, Chunk.bitsize.y)
	minz = bit.rshift(minz, Chunk.bitsize.z)
	maxx = bit.rshift(maxx, Chunk.bitsize.x)
	maxy = bit.rshift(maxy, Chunk.bitsize.y)
	maxz = bit.rshift(maxz, Chunk.bitsize.z)
	
	for cz=minz,maxz do
		for cy=miny,maxy do
			for cx=minx,maxx do
				local chunkIndex = cx + self.sizeInChunks.x * (cy + self.sizeInChunks.y * cz)
				-- [[
				self.chunks[chunkIndex]:buildDrawArrays()
				--]]
				--[[
				local chunk = self.chunks[chunkIndex]
				-- 0.04 to 0.08 seconds ... 1/25 to 1/12.5
				local timer = require 'ext.timer'
				timer('chunk', chunk.buildDrawArrays, chunk)
				--]]
			end
		end
	end
end

function Map:draw()
	local game = self.game
	local app = game.app
	app.spriteAtlasTex:bind(0)
	for chunkIndex=0,self.chunkVolume-1 do
		local chunk = self.chunks[chunkIndex]
		chunk.sunAngleTex:bind(1)
		chunk:draw(app, game)
	end
	GLTex2D:unbind(1)
	GLTex2D:unbind(0)
end

function Map:drawObjs()
	-- accumulate draw lists
	for _,obj in ipairs(self.objs) do
		obj:draw()
	end
end

function Map:buildAlts()
	for chunkIndex=0,self.chunkVolume-1 do
		self.chunks[chunkIndex]:buildAlts()
	end
	for chunkIndex=0,self.chunkVolume-1 do
		self.chunks[chunkIndex]:calcSunAngles()
	end
end

function Map:initLight()
	for chunkIndex=0,self.chunkVolume-1 do
		self.chunks[chunkIndex]:initLight()
	end
	for chunkIndex=0,self.chunkVolume-1 do
		self.chunks[chunkIndex]:initLight()
	end
end


-- i,j,k integers
-- return the ptr to the map tile
-- TODO rename to 'getPtr' or 'getVoxel' or something
function Map:getTile(i,j,k)
	if i < 0 or i >= self.size.x
	or j < 0 or j >= self.size.y
	or k < 0 or k >= self.size.z
	then
		return
	end
	local cx = bit.rshift(i, Chunk.bitsize.x)
	local cy = bit.rshift(j, Chunk.bitsize.y)
	local cz = bit.rshift(k, Chunk.bitsize.z)
	local dx = bit.band(i, Chunk.bitmask.x)
	local dy = bit.band(j, Chunk.bitmask.y)
	local dz = bit.band(k, Chunk.bitmask.z)
	local chunkIndex = cx + self.sizeInChunks.x * (cy + self.sizeInChunks.y * cz)
	local chunk = self.chunks[chunkIndex]
	local index = bit.bor(dx, bit.lshift(bit.bor(dy, bit.lshift(dz, Chunk.bitsize.y)), Chunk.bitsize.x))
	return chunk.v + index
end

function Map:getSurface(i,j)
	if i < 0 or i >= self.size.x
	or j < 0 or j >= self.size.y
	then
		return
	end
	local cx = bit.rshift(i, Chunk.bitsize.x)
	local cy = bit.rshift(j, Chunk.bitsize.y)
	local dx = bit.band(i, Chunk.bitmask.x)
	local dy = bit.band(j, Chunk.bitmask.y)
	local chunkIndex = cx + self.sizeInChunks.x * cy
	local chunk = self.chunks[chunkIndex]
	local index = bit.bor(dx, bit.lshift(dy, Chunk.bitsize.x))
	return chunk.surface + index

end

-- i,j,k integers
function Map:getType(i,j,k)
	local tile = self:getTile(i,j,k)
	if not tile then return Tile.typeValues.Empty end
	return tile.type
end


function Map:getTileObjs(x,y,z)
	local game = self.game	-- TODO map should get .game
	x = math.floor(x)
	y = math.floor(y)
	z = math.floor(z)
	if x < 0 or x >= self.size.x
	or y < 0 or y >= self.size.y
	or z < 0 or z >= self.size.z
	then
		return nil
	end
	local voxelIndex = x + self.size.x * (y + self.size.y * z)
	return self.objsPerTileIndex[voxelIndex]
end

-- i,j,k integers
-- cl = object class
-- returns true if an object of the class 'cl' is on this tile
-- TODO right now this is position-based testing
-- instead TODO link objs to tiles
-- and have this just cycle the linkse of the tile
function Map:hasObjType(x,y,z,cl)
	local game = self.game	-- TODO map should get .game
	x = math.floor(x)
	y = math.floor(y)
	z = math.floor(z)
	local tileObjs = self:getTileObjs(x,y,z)
	if not tileObjs then
		return false
	end
	for _,obj in ipairs(tileObjs) do
		if cl:isa(obj)
		and math.floor(obj.pos.x) == x
		and math.floor(obj.pos.y) == y
		and math.floor(obj.pos.z) == z
		then
			return true
		end
	end
	return false
end

function Map:newObj(args)
--print('new', args.class.name, 'at', args.pos)
	local cl = assert(args.class)
	
	args.game = self.game
	args.map = self
	
	if not args.uid then
		args.uid = self.game.nextObjUID
		self.game.nextObjUID = self.game.nextObjUID + 1
	end

	local obj = cl(args)
	self.objs:insert(obj)
	return obj
end

function Map:updateLightAtPos(x,y,z)
	return self:updateLight(
		x - ffi.C.MAX_LUM,
		y - ffi.C.MAX_LUM,
		z - ffi.C.MAX_LUM,
		x + ffi.C.MAX_LUM,
		y + ffi.C.MAX_LUM,
		z + ffi.C.MAX_LUM)
end

-- update a region of light
function Map:updateLight(
	lightminx,
	lightminy,
	lightminz,
	lightmaxx,
	lightmaxy,
	lightmaxz
)
	-- update lights in this region
	-- TODO better update,
	-- like queue all the boundary tiles and all light sources
	-- then flood fill through all the remaining tiles within the region
	if lightmaxx < 0
	or lightmaxy < 0
	or lightmaxz < 0
	or lightminx >= self.size.x
	or lightminy >= self.size.y
	or lightminz >= self.size.z
	then
		return
	end
	lightminx = math.max(0, lightminx)
	lightminy = math.max(0, lightminy)
	lightminz = math.max(0, lightminz)
	lightmaxx = math.min(self.size.x-1, lightmaxx)
	lightmaxy = math.min(self.size.y-1, lightmaxy)
	lightmaxz = math.min(self.size.z-1, lightmaxz)
	-- flood fill from borders
	for z=lightminz,lightmaxz do
		for y=lightminy,lightmaxy do
			for x=lightminx,lightmaxx do
				local surf = self:getSurface(x,y)
				local voxel = self:getTile(x,y,z)
				if z >= surf[0].lumAlt then
					voxel.lum = ffi.C.MAX_LUM
					-- TOOD store this flag separtely / only use it for smaller regions when light settling 
					voxel.lumclean = 1
				else
					local voxelIndex = x + self.size.x * (y + self.size.y * z)
					local lum = 0
					voxel.lumclean = 0
					local objs = self.objsPerTileIndex[voxelIndex]
					if objs then
						for _,obj in ipairs(objs) do
							lum = lum + obj.light
						end
					end
					voxel.lum = math.clamp(lum, 0, ffi.C.MAX_LUM)
				end
			end
		end
	end
	-- update
	local modified
	repeat
		modified = false
		for z=lightminz,lightmaxz do
			for y=lightminy,lightmaxy do
				for x=lightminx,lightmaxx do
					local voxel = self:getTile(x,y,z)
					if voxel.lumclean == 0 then
						for sideIndex,dir in ipairs(sides.dirs) do
							local nx = x + dir.x
							local ny = y + dir.y
							local nz = z + dir.z
							local nbhdVoxel = self:getTile(nx, ny, nz)
							if nbhdVoxel then
								local nbhdVoxelTypeIndex = nbhdVoxel.type
								local nbhdVoxelType = Tile.types[nbhdVoxelTypeIndex]
								local newLum = math.max(voxel.lum, nbhdVoxel.lum - nbhdVoxelType.lightDiminish)
								if newLum > voxel.lum then
									voxel.lum = newLum
									modified = true
								end
							end
						end
					end
				end
			end
		end
	until not modified
	self:buildDrawArrays(
		lightminx,
		lightminy,
		lightminz,
		lightmaxx,
		lightmaxy,
		lightmaxz)
end

function Map:update(dt)
	for _,obj in ipairs(self.objs) do
		if obj.update then obj:update(dt) end
	end

	--[[ experimental light update
	local chunkIndex = 0
	for cz=0,self.sizeInChunks.z-1 do
		for cy=0,self.sizeInChunks.y-1 do
			for cx=0,self.sizeInChunks.x-1 do
				local chunk = assert(self.chunks[chunkIndex])
				local voxelIndex = 0
				local meshDirty
				for dz=0,Chunk.size.z-1 do
					local k = bit.bor(dz, bit.lshift(chunk.pos.z, chunk.bitsize.z))
					for dy=0,Chunk.size.y-1 do
						local j = bit.bor(dy, bit.lshift(chunk.pos.y, chunk.bitsize.y))
						for dx=0,Chunk.size.x-1 do
							local i = bit.bor(dx, bit.lshift(chunk.pos.x, chunk.bitsize.x))
							local voxel = chunk.v[voxelIndex]
							if voxel.lumclean == 0 then
								local found
								local lum = 0
								for sideIndex,dir in ipairs(sides.dirs) do
									local nx = i + dir.x
									local ny = j + dir.y
									local nz = k + dir.z
									local nbhdVoxel = self:getTile(nx, ny, nz)
									if nbhdVoxel
									--and nbhdVoxel.lumclean == 1
									then
										local nbhdVoxelTypeIndex = nbhdVoxel.type
										local nbhdVoxelType = Tile.types[nbhdVoxelTypeIndex]
										found = true
										lum = math.max(lum, nbhdVoxel.lum - nbhdVoxelType.lightDiminish)
									end
								end
								if found then
									if lum > voxel.lum then
										voxel.lum = lum
										meshDirty = true
									else
										voxel.lumclean = 1
									end
								end
							end
							voxelIndex = voxelIndex + 1
						end
					end
				end
				chunkIndex = chunkIndex + 1
				if meshDirty then
					chunk:buildDrawArrays()
				end
			end
		end
	end
	--]]
end

-- TODO this is slow.  coroutine and progress bar?
function Map:getSaveData()
	local plantTypes = require 'zelda.plants'
	local animalTypes = require 'zelda.animals'
	local game = self.game
	local app = game.app
	return tolua({
		sizeInChunks = self.sizeInChunks,
		data = range(0,self.chunkVolume-1):mapi(function(j)
			local chunk = self.chunks[j]
			return ffi.string(chunk.v, chunk.volume)
		end):concat(),
		objs = self.objs:mapi(function(obj)
			local dstobjinfo = table(obj)
			for k,v in pairs(obj) do
				if v == obj.class[k] then
					dstobjinfo[k] = nil
				end
			end
			dstobjinfo.class = obj.class	-- 'require '..tolua(assert(obj.classname))	-- copy from class to obj
			dstobjinfo.game = nil		
			dstobjinfo.map = nil
			dstobjinfo.tiles = nil
			dstobjinfo.voxel = nil
			dstobjinfo.shakeThread = nil
			-- do I need any of these?
			--dstobjinfo.linkpos = nil
			--dstobjinfo.oldpos = nil
			--dstobjinfo.oldvel = nil
			-- TODO plants need their plantType saved somehow
			-- same with animals
			-- right now they just point back to zelda.obj.plant/animal ... bleh
			-- opposite here: these are in classes but need to be copied onto the obj ...
			dstobjinfo.plantType = obj.plantType
			dstobjinfo.animalType = obj.animalType
			
			dstobjinfo:setmetatable(nil)
			return dstobjinfo
		end),
	}, {
		skipRecursiveReferences = true,
		serializeForType = {
			table = function(state, x, ...)
				if rawequal(x, game) then
					return 'error "can\'t serialize game"'
				end
				if rawequal(x, app) then
					return 'error "can\'t serialize app"'
				end
				if rawequal(x, x.class) then
					return 'require '..tolua(x.classname)
				end
				for i,appPlayer in ipairs(app.players) do
					if rawequal(x, appPlayer) then
						return 'app.players['..i..']'
					end			
				end

				for _,plantType in ipairs(plantTypes) do
					if rawequal(x, plantType) then
						return 'plantTypeForName('..tolua(x.name)..')'
					end
				end
				for _,animalType in ipairs(animalTypes) do
					if rawequal(x, animalType) then
						return 'animalTypeForName('..tolua(x.name)..')'
					end
				end

				for i,map in ipairs(game.maps) do
					if rawequal(map, x) then
						return 'getMap('..i..')'
					end
					if map.objs:find(x) then
						return 'getObjByUID('..tostring(x.uid)..')'
					end
				end

				local mt = getmetatable(x)
				-- matrix.ffi
				if mt == matrix_ffi then
					return 'matrix_ffi('
						..tostring(x)
							:gsub('%[', '{')
							:gsub('%]', '}')
							:gsub('\n', '')
						..', '
						..tolua(x.ctype)..')'
				end			
				return tolua.defaultSerializeForType.table(state, x, ...)
			end,
			cdata = function(state, x, ...)
				local ft = ffi.typeof(x)
				if ft == ffi.typeof'uint64_t' then
					-- using tostring() will give it a ULL suffix
					-- which makes the .lua file incompatible with non-luajit versions
					return tostring(x)
					-- how else?
					-- I could split it into a "bit.bor(lo, bit.lshift(hi,32))"
					-- or I could just serialize it as string ...
				end
				-- vec*
				for _,s in ipairs{
					'2b', '2d', '2f', '2i', '2s',        '2ub',
					'3b', '3d', '3f', '3i', '3s', '3sz', '3ub',
					'4b', '4d', '4f', '4i',              '4ub',
				} do
					local name = 'vec'..s
					if ft == require('vec-ffi.'..name) then
						return name..'('
							..table{x:unpack()}:concat', '
							..')'
					end
				end
				-- box*
				for _,s in ipairs{
					'2f', '3f',
				} do
					local name = 'box'..s
					if ft == require('vec-ffi.'..name) then
						return name..'({'
							..table{x.min:unpack()}:concat', '
							..'}, {'
							..table{x.max:unpack()}:concat', '
							..'})'
					end
				end
				return "error'got unknown metatype'"
			end,
		},
	})
end

return Map
