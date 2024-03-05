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
local GLTex3D = require 'gl.tex3d'
local Voxel = require 'farmgame.voxel'
local sides = require 'farmgame.sides'


local typeBitSize = 10
local texBitSize = 8
local shapeBitSize = 8
-- ... and then 6 bits for the orientation

-- TODO how about bitflags for orientation ... https://thenumbernine.github.io/symmath/tests/output/Platonic%20Solids/Cube.html
-- the automorphism rotation group size is 24 ... so 5 bits for rotations.  including reflection is 48, so 6 bits.
ffi.cdef(template([[
enum { CHUNK_BITSIZE = 5 };
enum { CHUNK_SIZE = 1 << CHUNK_BITSIZE };
enum { CHUNK_BITMASK = CHUNK_SIZE - 1 };
enum { CHUNK_VOLUME = 1 << (3 * CHUNK_BITSIZE) };

typedef uint32_t voxel_basebits_t;
typedef struct {
	voxel_basebits_t type : <?=typeBitSize?>;	// map-type, this maps to farmgame.voxel 's .types, which now holds {[0]=empty, stone, grass, wood}
	voxel_basebits_t tex : <?=texBitSize?>;	// tex = atlas per-tile to use.

	// enum: cube, half, slope, halfslope, stairs, fortification, fence, ... ?
	voxel_basebits_t shape : <?=shapeBitSize?>;

	//voxel_basebits_t rotx : 2;	// Euler angles, in 90' increments
	voxel_basebits_t roty : 2;
	voxel_basebits_t rotz : 2;
} voxel_t;


// ok voxel_t was my go-to, but I want to target GLES, and idk that mobile supports compute, so ... I'm going to put these in their own data structure
typedef struct {
	uint8_t source;
	uint8_t lum;
	uint8_t lightDiminish;	//baked in from the voxel type
	uint8_t padding;
} lumvox_t;

typedef struct {
	int16_t lumAlt;		//tallest tile that is opaque
	int16_t solidAlt;	//tallest tile that is solid
	float minAngle;
	float maxAngle;
} surface_t;
]], {
	typeBitSize = typeBitSize,
	texBitSize = texBitSize,
	shapeBitSize = shapeBitSize,
}))
assert(ffi.sizeof'voxel_t' == ffi.sizeof'voxel_basebits_t')
assert(ffi.sizeof'lumvox_t' == 4)
assert(#Voxel.types <= bit.lshift(1,typeBitSize))	-- make sure our # types can fit
assert(#Voxel.shapes <= bit.lshift(1,shapeBitSize))	-- make sure our # shapes can fit
for _,tileType in ipairs(Voxel.types) do
	assert(#tileType.texrects <= bit.lshift(1, texBitSize))	-- make sure all our textures per voxel type can fit
end

local voxel_t = ffi.metatype('voxel_t', {
	__index = {
		tileClass = function(self)
			return Voxel.types[self.type]
		end,
	},
})


local CPUGPUBuf = class()

--[[
args:
	type = ctype
--]]
function CPUGPUBuf:init(args)
	local ctype = assert(args.type)
	self.vec = vector(ctype)()
	-- using reserve and heuristic of #cubes ~ #vec: brings time taken from 12 s to 0.12 s
	self.vec:reserve(args.volume)
	self.buf = GLArrayBuffer{
		size = ffi.sizeof(ctype) * self.vec:capacity(),
		data = self.vec.v,
		usage = gl.GL_DYNAMIC_DRAW,
	}:unbind()

	-- TODO Don't reallocate gl buffers each time.
	-- OpenGL growing buffers via glCopyBufferSubData:
	-- https://stackoverflow.com/a/27751186/2714073
	-- TODO TODO I dn't really need glCopyBufferSubData
	-- since the cpu side is getting copied around already
	-- and the gpu update is only at the end

	local cpugpu = self
	local oldreserve = self.vec.reserve
	local function newreserve(self, newcap)
		if newcap <= self:capacity() then return end
		local oldcap = self:capacity()
		local oldv = self.v
		oldreserve(self, newcap)	-- copies oldv to v, updates v and capacity
--print('reserving from', oldcap, 'to', newcap)

		local sizeof = ffi.sizeof(ctype)
		local oldcopysize = sizeof * oldcap
		local newcopysize = sizeof * newcap

local glreport = require 'gl.report'
glreport'here'

		--[[
		cpugpu.buf:bind(gl.GL_COPY_READ_BUFFER)
		local newbuf = GLArrayBuffer()
glreport'here'
		newbuf:unbind()
glreport'here'
		newbuf:bind(gl.GL_COPY_WRITE_BUFFER)
glreport'here'
		gl.glBufferData(gl.GL_COPY_WRITE_BUFFER, newcopysize, nil, gl.GL_DYNAMIC_DRAW)
		newbuf.size = newcopysize
		newbuf.data = self.v
		newbuf.usage = gl.GL_DYNAMIC_DRAW
glreport'here'
		gl.glCopyBufferSubData(
			gl.GL_COPY_READ_BUFFER,		--GLenum readtarget,
			gl.GL_COPY_WRITE_BUFFER,	--GLenum writetarget,
			0,							--GLintptr readoffset,
			0,							--GLintptr writeoffset,
			oldcopysize)	--GLsizeiptr size)
glreport'here'
		GLArrayBuffer:unbind(gl.GL_COPY_READ_BUFFER)
glreport'here'
		GLArrayBuffer:unbind(gl.GL_COPY_WRITE_BUFFER)
glreport'here'
		cpugpu.buf = newbuf
		--]]
		--[[
		cpugpu.buf:bind(gl.GL_COPY_READ_BUFFER)
glreport'here'
		local newbuf = GLArrayBuffer{
			size = newcopysize,
			data = self.v,
			usage = gl.GL_DYNAMIC_DRAW,
		}
glreport'here'
		gl.glCopyBufferSubData(
			gl.GL_COPY_READ_BUFFER,		--GLenum readtarget,
			newbuf.target,				--GLenum writetarget,
			0,							--GLintptr readoffset,
			0,							--GLintptr writeoffset,
			oldcopysize)				--GLsizeiptr size)
glreport'here'
		GLArrayBuffer:unbind(gl.GL_COPY_READ_BUFFER)
glreport'here'
		newbuf:unbind()
glreport'here'
		cpugpu.buf = newbuf
		--]]
		-- [[
		cpugpu.buf = GLArrayBuffer{
			size = newcopysize,
			data = self.v,
			usage = gl.GL_DYNAMIC_DRAW,
		}:unbind()
		--]]
	end
	
	-- TODO ... hmmm
	self.vec.reserve = newreserve
end


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
	-- TODO similar to CPUGPUBuf, but for textures?  just store tex.data buffer? idk ...
	self.surfaceTex = GLTex2D{
		width = self.size.x,
		height = self.size.y,
		format = gl.GL_RGBA,
		internalFormat = gl.GL_RGBA,
		type = gl.GL_UNSIGNED_BYTE,
		-- TODO ... either convert all fields to uint8, or use an intermediate ...
		-- if we convert all fields, then that means our max altitude is 256
		-- another option is convert all fields to uint16 ...
		data = self.surface,	
		minFilter = gl.GL_NEAREST,
		magFilter = gl.GL_NEAREST,
	}

	-- geometry
	local volume = self.volume
	self.vtxs = CPUGPUBuf{type='vec3f_t', volume=volume}
	self.texcoords = CPUGPUBuf{type='vec2f_t', volume=volume}
	self.colors = CPUGPUBuf{type='vec4ub_t', volume=volume}

	-- lighting on the GPU?
	-- TODO keep track of this for cpu/gpu transfers? or something? idk?
	self.lumData = ffi.new('lumvox_t[?]', self.volume)
	ffi.fill(self.lumData, ffi.sizeof'lumvox_t' * self.volume)
	-- chunk size = 32^3 <-> lumTex size = 128kb
	-- TODO ... just store voxel_t as a 32-bit texture, don't bother use this separately.
	self.lumTex = GLTex3D{
		width = self.size.x,
		height = self.size.y,
		depth = self.size.z,
		internalFormat = gl.GL_RGBA,
		format = gl.GL_RGBA,
		type = gl.GL_UNSIGNED_BYTE,
		data = self.lumData,
		magFilter = gl.GL_NEAREST,
		minFilter = gl.GL_NEAREST,
	}

	self.sceneObj = GLSceneObject{
		geometry = GLGeometry{
			mode = gl.GL_TRIANGLES,
			count = self.vtxs.vec:size(),
		},
		program = app.mapShader,
		attrs = {
			vertex = {
				buffer = self.vtxs.buf,
				type = gl.GL_FLOAT,
				size = 3,
			},
			texcoord = {
				buffer = self.texcoords.buf,
				type = gl.GL_FLOAT,
				size = 2,
			},
			color = {
				buffer = self.colors.buf,
				type = gl.GL_UNSIGNED_BYTE,
				size = 4,
				normalize = true,
			},
		},
		texs = {},
	}
end

-- Lookup functions for rotations
-- Have to see if it's faster to do this or idk what else ... 
-- ... inline if-conditions for all cases?
-- ... for-loops to repeatedly apply each rot
--[[ symmath script 
T = Matrix(
	{1,0,0,frac(1,2)},
	{0,1,0,frac(1,2)},
	{0,0,1,frac(1,2)},
	{0,0,0,1})
v = Matrix{x,y,z,1}:T()
Rs = table{
	Matrix({1,0,0,0},{0,0,-1,0},{0,1,0,0},{0,0,0,1}),
	Matrix({0,0,1,0},{0,1,0,0},{-1,0,0,0},{0,0,0,1}),
	Matrix({0,-1,0,0},{1,0,0,0},{0,0,1,0},{0,0,0,1}),
}
RTs = Rs:mapi(function(R) return (T * R * T:inv())() end)
for i,RT in ipairs(RTs) do
	print('rot axis '..i)
	print(Array{
		(RT * v)(),
		(RT * RT * v)(),
		(RT * RT * RT * v)()
	})
end
--]]
local function identity(...) return ... end
local rotx = {
	[0] = identity,
	function(x,y,z) return x, 1 - z,     y, 1 end,
	function(x,y,z) return x, 1 - y, 1 - z, 1 end,
	function(x,y,z) return x,     z, 1 - y, 1 end,
}
local roty = {
	[0] = identity,
	function(x,y,z) return     z, y, 1 - x, 1 end,
	function(x,y,z) return 1 - x, y, 1 - z, 1 end,
	function(x,y,z) return 1 - z, y,     x, 1 end,
}
local rotz = {
	[0] = identity,
	function(x,y,z) return 1 - y,     x, z, 1 end,
	function(x,y,z) return 1 - x, 1 - y, z, 1 end,
	function(x,y,z) return     y, 1 - x, z, 1 end,
}

function Chunk:buildDrawArrays()
	local map = self.map
	local app = map.game.app
	self.vtxs.vec:resize(0)
	self.texcoords.vec:resize(0)
	self.colors.vec:resize(0)
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
					local voxelType = Voxel.types[voxelTypeIndex]
					if voxelType then
						local texrect = voxelType.texrects[voxel.tex+1]
						if not texrect then
							print("voxelType "..voxelTypeIndex.." has "..#voxelType.texrects.." texrects but index was "..voxel.tex)
						else
							-- roll = rotx (apply first ... or don't)
							-- pitch = roty (apply second)
							-- yaw = rotz (apply third)
							local rotyfunc = roty[voxel.roty]
							local rotzfunc = rotz[voxel.rotz]
							
							if voxelType.isUnitCube then
								if voxel.shape == 0 then
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
										if nbhdVoxel then
											if nbhdVoxel.shape == 0 then
												local nbhdVoxelTypeIndex = nbhdVoxel.type
												-- only if the neighbor is solid ...
												if nbhdVoxelTypeIndex > 0
												then
													local nbhdVoxelType = Voxel.types[nbhdVoxelTypeIndex]
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
												local vi = Voxel.unitQuadTriIndexes[ti]
												local vtxindex = faces[vi]

												local c = self.colors.vec:emplace_back()
												-- TODO do we even need vertex colors?
												c:set(255, 255, 255, 255)

												local tc = self.texcoords.vec:emplace_back()
												tc:set(
													(texrect.pos[1] + voxelType.unitquad[vi][1] * texrect.size[1] + .5) * atlasDx,
													(texrect.pos[2] + voxelType.unitquad[vi][2] * texrect.size[2] + .5) * atlasDy
												)

												local v = voxelType.cubeVtxs[vtxindex+1]
												local vtx = self.vtxs.vec:emplace_back()
												local x,y,z = rotzfunc(rotyfunc(v:unpack()))
												vtx:set(i + x, j + y, k + z)
											end
										end
									end
								else
									local voxelShape = Voxel.shapes[voxel.shape]
									-- use a custom OBJ
									-- and rotate it accordingly
									if not voxelShape then
										print("got an unknown voxelShape "..voxel.shape)
									else
										if not voxelShape.model then
											print("voxelShap "..voxel.shape.." has no model")
										else
											local model = voxelShape.model
											for l=0,model.triIndexes.size-1 do
												local vsrc = model.vtxs.v + model.triIndexes.v[l]

												local c = self.colors.vec:emplace_back()
												c:set(255, 255, 255, 255)

												local tc = self.texcoords.vec:emplace_back()
												tc:set(
													(texrect.pos[1] + vsrc.texcoord.x * texrect.size[1] + .5) * atlasDx,
													(texrect.pos[2] + vsrc.texcoord.y * texrect.size[2] + .5) * atlasDy
												)

												local vtx = self.vtxs.vec:emplace_back()
												local x, y, z = rotzfunc(rotyfunc(vsrc.pos:unpack()))
												vtx:set(i + x, j + y, k + z)
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
	print('vtxs', self.vtxs.vec:size())
--]]

	local vtxSize = self.vtxs.vec:size() * ffi.sizeof(self.vtxs.vec.type)
	local texcoordSize = self.texcoords.vec:size() * ffi.sizeof(self.texcoords.vec.type)
	local colorSize = self.colors.vec:size() * ffi.sizeof(self.colors.vec.type)

--[[ right now i'm resizing the gl buffers with the c buffers
-- I could instead only check here after all is done for a final resize
	if vtxSize > self.vtxs.buf.size then
		print'TODO needs vtxs.buf resize'
		-- create a new buffer
		-- copy old onto new
		-- update new buffer in GLAttribute object
		-- then rebind buffer in GLSceneObject's .vao
--		return
	end
	if texcoordSize > self.texcoords.buf.size then
		print'TODO needs texcoords.buf resize'
--		return
	end
	if colorSize > self.colors.buf.size then
		print'TODO needs colors.buf resize'
--		return
	end
--]]

-- [[
	self.vtxs.buf
		:bind()
		:updateData(0, vtxSize)
	self.texcoords.buf
		:bind()
		:updateData(0, texcoordSize)
	self.colors.buf
		:bind()
		:updateData(0, colorSize)
		:unbind()

	self.sceneObj.attrs.vertex.buffer = self.vtxs.buf
	self.sceneObj.attrs.texcoord.buffer = self.texcoords.buf
	self.sceneObj.attrs.color.buffer = self.colors.buf
	-- but the vao's attrs is dif, and is indexed by ... integer?
	-- hmm should I change it to be indexed by name also?
	-- TODO ... maybe vao attrs name by key? but they don't hav name
	-- maybe just use .attrs from sceneObj? hmm ....
	select(2, self.sceneObj.vao.attrs:find(nil, function(a) return a.loc == self.sceneObj.attrs.vertex.loc end)).buffer = self.vtxs.buf
	select(2, self.sceneObj.vao.attrs:find(nil, function(a) return a.loc == self.sceneObj.attrs.texcoord.loc end)).buffer = self.texcoords.buf
	select(2, self.sceneObj.vao.attrs:find(nil, function(a) return a.loc == self.sceneObj.attrs.color.loc end)).buffer = self.colors.buf
	self.sceneObj.vao:setAttrs()
--]]

	self.sceneObj.geometry.count = self.vtxs.vec:size()
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
	--self.sceneObj.texs[3] = self.lumTex
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
					local tileClass = Voxel.types[tileInfo.type]
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
					local tileClass = Voxel.types[tileInfo.type]
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
	local lumSlice = self.lumData + self.volume - sliceSize
	for k=self.size.z-1,0,-1 do
		local surf = self.surface
		local voxel = voxelSlice
		local lumvox = lumSlice
		for j=0,self.size.y-1 do
			for i=0,self.size.x-1 do
				if k == self.size.z-1
				or k + baseAlt >= surf[0].lumAlt
				then
					lumvox.source = ffi.C.MAX_LUM
					lumvox.lum = ffi.C.MAX_LUM
				else
					-- slowly decrement?
					--voxel.lum = math.max(0, voxel[sliceSize].lum - 1)
					-- or just zero?
					lumvox.source = 0
					lumvox.lum = 0
				end
				local voxelTypeIndex = voxel.type
				local voxelType = Voxel.types[voxelTypeIndex] or Voxel.types[0]
--DEBUG:assert(voxelType.lightDiminish)
				lumvox.lightDiminish = voxelType.lightDiminish
				voxel = voxel + 1
				surf = surf + 1
			end
		end
		voxelSlice = voxelSlice - sliceSize
		lumSlice = lumSlice - sliceSize
	end
--DEBUG:assert(voxelSlice == self.v - sliceSize)
--DEBUG:assert(lumSlice == self.lumData - sliceSize)
--DEBUG:assert(self.lumTex.data == self.lumData)
	self.lumTex
		:bind()
		:subimage()
		:unbind()
end

local Map = class()

Map.Chunk = Chunk

local function ravelIndex2D(x,y,sizex)
	return x + sizex * y
end

local function ravelIndex3D(x,y,z,size)
	return x + size.x * (y + size.y * z)
end

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
				local chunkIndex = ravelIndex3D(cx, cy, cz, self.sizeInChunks)
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

function Map:updateMeshAndLight(x,y,z)
	self:buildDrawArrays(x,y,z,x,y,z)
	self:updateLight(x,y,z,x,y,z)
end

function Map:draw()
	local game = self.game
	local app = game.app
	app.spriteAtlasTex:bind(0)
	for chunkIndex=0,self.chunkVolume-1 do
		local chunk = self.chunks[chunkIndex]
		chunk.sunAngleTex:bind(1)
		chunk.lumTex:bind(2)
		chunk:draw(app, game)
	end
	GLTex3D:unbind(2)
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

	--[[
	-- now that we've set lum to full or empty ...
	-- flood-fill inwards into any places
	-- ... this will call buildDrawArrays
	self:updateLight(
		0,
		0,
		0,
		self.size.x-1,
		self.size.y-1,
		self.size.z-1)
	--]]
	-- [[ gpu-light update method doesn't rebuild the draw arrays, so only rebuild them ehre:
	-- (and wherever we're modifying the geometr)
	self:buildDrawArrays(
		0,
		0,
		0,
		self.size.x-1,
		self.size.y-1,
		self.size.z-1)
	--]]
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
	local chunkIndex = ravelIndex3D(cx, cy, cz, self.sizeInChunks)
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
	local chunkIndex = ravelIndex2D(cx, cy, self.sizeInChunks.x)
	local chunk = self.chunks[chunkIndex]
	local index = bit.bor(dx, bit.lshift(dy, Chunk.bitsize.x))
	return chunk.surface + index

end

-- i,j,k integers
function Map:getType(i,j,k)
	local tile = self:getTile(i,j,k)
	if not tile then return Voxel.typeValues.Empty end
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
		x,
		y,
		z,
		x,
		y,
		z)
end

-- assumes
-- 	size is vec3i and all positive
-- 	index is integer
--	index is within [0, size.x*size.y*size.z)
local function unravel(index, size)
	local x = index % size.x
	index = (index - x) / size.x
	local y = index % size.y
	index = (index - y) / size.y
	return x, y, index
end

local lightFlagAllVec = vector'uint8_t'()
local lightFlagPrevVec = vector'uint8_t'()
local lightFlagNextVec = vector'uint8_t'()
local lightPrevPoss = vector'vec3i_t'()
local lightNextPoss = vector'vec3i_t'()

-- update a region of light
-- uses flood fill algorithm
function Map:updateLight_floodFill(
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

	-- [[
	local lightsizex = lightmaxx - lightminx + 1
	local lightsizey = lightmaxy - lightminy + 1
	local lightsizez = lightmaxz - lightminz + 1
	local lightvolume = lightsizex * lightsizey * lightsizez
	lightFlagAllVec:resize(lightvolume)
	ffi.fill(lightFlagAllVec.v, lightFlagAllVec:size())
	lightFlagPrevVec:resize(lightvolume)
	ffi.fill(lightFlagPrevVec.v, lightFlagPrevVec:size())
	lightFlagNextVec:resize(lightvolume)
	ffi.fill(lightFlagNextVec.v, lightFlagNextVec:size())
	--]]

	-- calculate borders and sources (similar to Lagrangian multipliers...)
	lightPrevPoss:resize(0)
	for z=lightminz,lightmaxz do
		for y=lightminy,lightmaxy do
			for x=lightminx,lightmaxx do
				-- TODO handle changes in lumAlt before relighting ...
				-- 	if the block at lumAlt was removed/made transparent then search down for the next opaque one
				--	if any block above lumAlt was made opaque then set it to lumAlt
				local voxel = self:getTile(x,y,z)
				if x >= 0 and x < self.size.x
				and y >= 0 and y < self.size.y
				and z >= 0 and z < self.size.z
				then
					local lightindex = (x - lightminx) + lightsizex * ((y - lightminy) + lightsizey * (z - lightminz))
					local surf = self:getSurface(x,y)
					if z >= surf.lumAlt then
						-- on surface? treat like a boundary voxel
						lightPrevPoss:emplace_back()[0]:set(x,y,z)
						lightFlagPrevVec.v[lightindex] = 1
						lightFlagAllVec.v[lightindex] = 1
--print('seed', x,y,z)
					else
						--assert(voxel)
						-- propagate only source lights within relight region
						local lum = 0
						local index = x + self.size.x * (y + self.size.y * z)
						local objs = self.objsPerTileIndex[index]
						if objs then
							for _,obj in ipairs(objs) do
								-- TODO hmmmmmmm should this ever happen?
								if not obj.removeFlag then
									lum = lum + obj.light
								end
							end
						end
						-- clear all lum's within the relight area
						local lum = math.clamp(lum, 0, ffi.C.MAX_LUM)
						-- but only save for propagation those with lum >0
						if lum > 0 then
							voxel.lum = lum
							lightPrevPoss:emplace_back()[0]:set(x,y,z)
							lightFlagPrevVec.v[lightindex] = 1
							lightFlagAllVec.v[lightindex] = 1
--print('seed', x,y,z)
						end
					end
				end
			end
		end
	end
	-- flood-fill inwards ... could just use a poisson solver on the GPU, if I want to store the light sources in a separate buffer ...
	local propagatedany
	repeat
		propagatedany = false
		lightNextPoss:resize(0)
		ffi.fill(lightFlagNextVec.v, lightFlagNextVec:size())
		for pi=0,lightPrevPoss.size-1 do
			local pos = lightPrevPoss.v[pi]
			local x,y,z = pos:unpack()
			local i = x + self.size.x * (y + self.size.y * z)
			local lightindex = (x - lightminx) + lightsizex * ((y - lightminy) + lightsizey * (z - lightminz))
			--local lum = lightFlagPrevVec.v[lightindex]	-- ... but if we're using a dense array ... zero light wont' set the flag ...
			local lum = self:getTile(x,y,z).lum
			if lum > 0 then
				local x,y,z = unravel(i, self.size)
				for sideIndex,dir in ipairs(sides.dirs) do
					local nx = x + dir.x
					local ny = y + dir.y
					local nz = z + dir.z
					if nx >= lightminx and nx <= lightmaxx
					and ny >= lightminy and ny <= lightmaxy
					and nz >= lightminz and nz <= lightmaxz
					then
						local nbhdlightindex = (nx - lightminx) + lightsizex * ((ny - lightminy) + lightsizey * (nz - lightminz))
						if lightFlagAllVec.v[nbhdlightindex] == 0 then
							local nbhdsurf = self:getSurface(nx,ny)
							if nz >= nbhdsurf.lumAlt then
								local nbhdVoxel = self:getTile(nx, ny, nz)
							else
								local nbhdVoxel = self:getTile(nx, ny, nz)
								local nbhdVoxelTypeIndex = nbhdVoxel.type
								local nbhdVoxelType = Voxel.types[nbhdVoxelTypeIndex]
								propagatedany = true
								if lightFlagNextVec.v[nbhdlightindex] == 0 then
									nbhdVoxel.lum = math.max(0, lum - nbhdVoxelType.lightDiminish)
								else
									-- TODO for now lightDiminish must be 1 (or full at 15).
									-- If it diminishes by more than one then we need to propagate in space inverse-proportionally or else we could flood-fill into a cell, then put it on the 'already done' pile, and then not update it later correctly.
									nbhdVoxel.lum = math.max(nbhdVoxel.lum, lum - nbhdVoxelType.lightDiminish)
								end
--print('propagate', nx,ny,nz)
								lightNextPoss:emplace_back()[0]:set(nx,ny,nz)
								lightFlagNextVec.v[nbhdlightindex] = 1
							end
						end
					end
				end
			end
		end
		ffi.fill(lightFlagPrevVec.v, lightFlagPrevVec:size())
		for pi=0,lightNextPoss.size-1 do
			local x,y,z = lightNextPoss.v[pi]:unpack()
			local lightindex = (x - lightminx) + lightsizex * ((y - lightminy) + lightsizey * (z - lightminz))
			lightFlagAllVec.v[lightindex] = 1
			lightFlagPrevVec.v[lightindex] = 1
		end
		lightPrevPoss, lightNextPoss = lightNextPoss, lightPrevPoss
	until not propagatedany
	self:buildDrawArrays(
		lightminx,
		lightminy,
		lightminz,
		lightmaxx,
		lightmaxy,
		lightmaxz)
end

function Map:updateLight_brute(
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
	if lightmaxx >= 0
	and lightmaxy >= 0
	and lightmaxz >= 0
	and lightminx <= self.size.x-1
	and lightminy <= self.size.y-1
	and lightminz <= self.size.z-1
	then
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
									local nbhdVoxelType = Voxel.types[nbhdVoxelTypeIndex]
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
	end
	self:buildDrawArrays(
		lightminx,
		lightminy,
		lightminz,
		lightmaxx,
		lightmaxy,
		lightmaxz)
end

local tmpcolor = vec4ub()
function Map:updateLight_lumTex(
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
	if lightmaxx >= 0
	and lightmaxy >= 0
	and lightmaxz >= 0
	and lightminx <= self.size.x-1
	and lightminy <= self.size.y-1
	and lightminz <= self.size.z-1
	then
		local lastChunk
		
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
					local voxelTypeIndex = voxel.type
					local voxelType = Voxel.types[voxelTypeIndex] or Voxel.types[0]
					local lum = ffi.C.MAX_LUM
--print('z', z, 'lumAlt', surf[0].lumAlt)				
					-- TODO only use full-bright when above-ground *AND* in angle for the sun time
					do --if z < surf[0].lumAlt then
--print('z < lumAlt')
						local voxelIndex = ravelIndex3D(x, y, z, self.size)
						lum = 0
						local objs = self.objsPerTileIndex[voxelIndex]
						if objs then
							for _,obj in ipairs(objs) do
--print('obj.light', obj.light)								
								lum = lum + obj.light
							end
						end
--print('lum before clamp', lum)						
						lum = math.clamp(lum, 0, ffi.C.MAX_LUM)
--print('lum after clamp', lum)						
					end
--print('updateLightOnMove',x,y,z,lum)
					local cx = bit.rshift(x, Chunk.bitsize.x)
					local cy = bit.rshift(y, Chunk.bitsize.y)
					local cz = bit.rshift(z, Chunk.bitsize.z)
					local dx = bit.band(x, Chunk.bitmask.x)
					local dy = bit.band(y, Chunk.bitmask.y)
					local dz = bit.band(z, Chunk.bitmask.z)
					local chunkIndex = ravelIndex3D(cx, cy, cz, self.sizeInChunks)
					local chunk = self.chunks[chunkIndex]
					--local index = bit.bor(dx, bit.lshift(bit.bor(dy, bit.lshift(dz, Chunk.bitsize.y)), Chunk.bitsize.x))
					if chunk ~= lastChunk then
						if lastChunk then
							lastChunk.lumTex:unbind()
						end
						lastChunk = chunk
						chunk.lumTex:bind()
					end
					
					lum = lum * 255 / ffi.C.MAX_LUM
					tmpcolor:set(lum, lum, voxelType.lightDiminish, 255)
					gl.glTexSubImage3D(
						chunk.lumTex.target,
						0,
						dx, dy, dz,
						1, 1, 1,
						gl.GL_RGBA,
						gl.GL_UNSIGNED_BYTE,
						tmpcolor.s)
				end
			end
		end
		if lastChunk then
			lastChunk.lumTex:unbind()
		end
	end
end

--Map.updateLight = Map.updateLight_brute
Map.updateLight = Map.updateLight_lumTex

local function handleError(err)
	io.stderr:write(err, '\n', debug.traceback(), '\n')
end

function Map:update(dt)
	for _,obj in ipairs(self.objs) do
		-- xpcall to save the game even if something goes wrong
		if obj.update then
			xpcall(obj.update, handleError, obj, dt)
		end
	end

	-- how often to update light ...
	if math.random() < .5 then return end

	-- now do a lighting update
	-- I could do this on OpenCL if i had CL/GL interop ... do I? not on linux, because lazy intel.
	-- I could do an opencl compute ... I do have that on linux.
	-- for now, I'll just do a GPU update.
	-- bind the layers on all 6 sides from this layer
	-- then randomly push light values around
-- [=[
gl.glDisable(gl.GL_DEPTH_TEST)
gl.glDisable(gl.GL_CULL_FACE)
gl.glDisable(gl.GL_BLEND)
	local app = self.game.app
	local shader = app.lumUpdateShader
	local fbo = app.lumFBO
	fbo:bind()
	gl.glViewport(0, 0, fbo.width, fbo.height)
	shader:use()
	app.lumUpdateObj:enableAndSetAttrs()
	--gl.glUniform2f(shader.uniforms.moduloVec.loc, math.random(), math.random())
	app.randTex:bind(0)
	for cz=0,self.sizeInChunks.z-1 do
		for cy=0,self.sizeInChunks.y-1 do
			for cx=0,self.sizeInChunks.x-1 do
				local chunkIndex = ravelIndex3D(cx, cy, cz, self.sizeInChunks)
				local chunk = self.chunks[chunkIndex]
				chunk.lumTex:bind(1)
				--[[
				app.lumUpdateObj.texs[3] = self.chunks[ravelIndex3D(math.max(0,cx-1),cy,cz,self.sizeInChunks)].lumTex:bind(2)	-- xl
				app.lumUpdateObj.texs[4] = self.chunks[ravelIndex3D(cx,math.max(0,cy-1),cz,self.sizeInChunks)].lumTex:bind(3)	-- yl
				app.lumUpdateObj.texs[5] = self.chunks[ravelIndex3D(cx,cy,math.max(0,cz-1),self.sizeInChunks)].lumTex:bind(4)	-- zl
				app.lumUpdateObj.texs[6] = self.chunks[ravelIndex3D(math.min(cx+1,self.sizeInChunks.x-1),cy,cz,self.sizeInChunks)].lumTex:bind(5)	-- xr
				app.lumUpdateObj.texs[7] = self.chunks[ravelIndex3D(cx,math.min(cy+1,self.sizeInChunks.y-1),cz,self.sizeInChunks)].lumTex:bind(6)	-- yr
				app.lumUpdateObj.texs[8] = self.chunks[ravelIndex3D(cx,cy,math.min(cz+1,self.sizeInChunks.z-1),self.sizeInChunks)].lumTex:bind(7)	-- zr
				--]]
			
				-- in opengl you can't read and write to the same tex ...
				-- in opencl you can ... 
				-- bleh

				for z=0,Chunk.size.z-1 do
					local sliceZ = (z + .5) / tonumber(Chunk.size.z)
					gl.glUniform1f(shader.uniforms.sliceZ.loc, sliceZ)
					fbo:setColorAttachmentTex3D(app.lumTmpTex.id, 0, z)
					local res, err = fbo.check()
					if not res then print(err) end
					app.quadGeom:draw()
					
					--[[ copy back to the original tex3d
					chunk.lumTex:bind(0)
					gl.glCopyTexSubImage3D(gl.GL_TEXTURE_3D, 0, 0, 0, z, 0, 0, Chunk.size.x, Chunk.size.y)
					chunk.lumTex:unbind(0)
					--]]
				end
		
				-- [[
				-- just swap refs
				chunk.lumTex, app.lumTmpTex = app.lumTmpTex, chunk.lumTex
				--]]
			end
		end
	end
--	for i=7,1,-1 do
--		GLTex3D:unbind(i)
--	end
	GLTex3D:unbind(1)
	GLTex2D:unbind(0)
	app.lumUpdateObj:disableAttrs()
	shader:useNone()
	gl.glViewport(0, 0, app.width, app.height)
	fbo:unbind()
gl.glEnable(gl.GL_DEPTH_TEST)
gl.glEnable(gl.GL_CULL_FACE)
gl.glEnable(gl.GL_BLEND)
--]=]
end

-- TODO this is slow.  coroutine and progress bar?
function Map:getSaveData()
	local plantTypes = require 'farmgame.plants'
	local animalTypes = require 'farmgame.animals'
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
			-- right now they just point back to farmgame.obj.plant/animal ... bleh
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
