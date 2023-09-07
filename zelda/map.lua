local class = require 'ext.class'
local table = require 'ext.table'
local ffi = require 'ffi'
local template = require 'template'
local vector = require 'ffi.cpp.vector'
local vec2i = require 'vec-ffi.vec2i'
local vec3i = require 'vec-ffi.vec3i'
local vec3f = require 'vec-ffi.vec3f'
local vec2f = require 'vec-ffi.vec2f'
local vec4ub = require 'vec-ffi.vec4ub'
local gl = require 'gl'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLSceneObject = require 'gl.sceneobject'
local GLGeometry = require 'gl.geometry'
local GLTex2D = require 'gl.tex2d'
local Tile = require 'zelda.tile'
local sides = require 'zelda.sides'


-- TODO how about bitflags for orientation ... https://thenumbernine.github.io/symmath/tests/output/Platonic%20Solids/Cube.html
-- the automorphism rotation group size is 24 ... so 5 bits for rotations.  including reflection is 48, so 6 bits.
ffi.cdef[[
typedef uint16_t voxel_basebits_t;
typedef struct {
	voxel_basebits_t type : 5;	// map-type, this maps to zelda.tiles, which now holds {[0]=empty, stone, grass, wood}
	voxel_basebits_t tex : 4;	// tex = atlas per-tile to use
	voxel_basebits_t half : 1;	// set this to use a half-high tile.  TODO eventually slopes, and make this the 'shape' field. also add 45' and 90' slopes.
	voxel_basebits_t rotx : 2;	// Euler angles, in 90' increments
	voxel_basebits_t roty : 2;
	voxel_basebits_t rotz : 2;
} voxel_t;

typedef struct {
	int16_t lumAlt;		//tallest tile that is opaque
	int16_t solidAlt;	//tallest tile that is solid
	float minAngle;
	float maxAngle;
} surface_t;
]]
assert(ffi.sizeof'voxel_t' == ffi.sizeof'voxel_basebits_t')


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
										if nbhdVoxel 
										and nbhdVoxel.half == 0
										then
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
										if drawFace then
											-- 2 triangles x 3 vtxs per triangle
											for ti=1,6 do
												local vi = Tile.unitQuadTriIndexes[ti]
												local vtxindex = faces[vi]
												local v = voxelType.cubeVtxs[vtxindex+1]

												local c = self.colors:emplace_back()
												local l = 255 * v[3]
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
										if faceIndex == sides.indexes.zm then
											local nbhdVoxel = map:getTile(nx, ny, nz)
											if nbhdVoxel then
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
												local l = 255 * v[3]
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
						surface.solidAlt = k
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
	local Image = require 'image'
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

local timer = require 'ext.timer'
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
	local obj = cl(args)
	self.objs:insert(obj)
	return obj
end

function Map:update(dt)
	for _,obj in ipairs(self.objs) do
		if obj.update then obj:update(dt) end
	end
end

-- TODO this is slow.  coroutine and progress bar?
local tolua = require 'ext.tolua'
local range = require 'ext.range'
function Map:getSaveData()
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

				local mt = getmetatable(x)
				-- matrix.ffi
				if mt == require 'matrix.ffi' then
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
