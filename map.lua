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
local glreport = require 'gl.report'
local GLProgram = require 'gl.program'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLSceneObject = require 'gl.sceneobject'
local GLGeometry = require 'gl.geometry'
local Tile = require 'zelda.tile'
local sides = require 'zelda.sides'

-- TODO how about bitflags for orientation ... https://thenumbernine.github.io/symmath/tests/output/Platonic%20Solids/Cube.html
-- the automorphism rotation group size is 24 ... so 5 bits for rotations.  including reflection is 48, so 6 bits.
ffi.cdef[[
typedef struct {
	uint8_t type;
	uint8_t tex;
} maptype_t;
]]

local Chunk = class()

-- static member
Chunk.bitsize = vec3i(5, 5, 5)
Chunk.size = Chunk.bitsize:map(function(x) return bit.lshift(1, x) end)
Chunk.bitmask = Chunk.size - 1
Chunk.volume = Chunk.size:volume()	-- same as 1 << bitsize:sum() (if i had a :sum() function...)

function Chunk:init(args)
	local map = assert(args.map)
	self.map = map
	self.pos = vec3i(assert(args.pos))
	
	self.v = ffi.new('maptype_t[?]', self.volume)
	ffi.fill(self.v, 0, ffi.sizeof'maptype_t' * self.volume)	-- 0 = empty

	-- height of highest block that occludes light
	self.lumAlt = ffi.new('int16_t', self.size.x * self.size.y)

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
		program = map.shader,
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
	self.vtxs:resize(0)
	self.texcoords:resize(0)
	self.colors:resize(0)
	local texpackDx = 1/tonumber(map.texpackSize.x)
	local texpackDy = 1/tonumber(map.texpackSize.y)
	local index = 0
	for dk=0,self.size.z-1 do
		local k = bit.bor(dk, bit.lshift(self.pos.z, self.bitsize.z))
		for dj=0,self.size.y-1 do
			local j = bit.bor(dj, bit.lshift(self.pos.y, self.bitsize.y))
			for di=0,self.size.x-1 do
				local i = bit.bor(di, bit.lshift(self.pos.x, self.bitsize.x))
				local maptile = self.v[index]
				local tiletype = maptile.type
				if tiletype > 0 then	-- skip empty
					local tile = Tile.types[tiletype]
					if tile then
						local texIndex = tonumber(maptile.tex)
						local texIndexX = texIndex % map.texpackSize.x
						local texIndexY = (texIndex - texIndexX) / map.texpackSize.x

						if tile.isUnitCube then
							assert(tile.cubeFaces)
							-- faceIndex is 1-based but lines up with sides bitflags
							for faceIndex,faces in ipairs(tile.cubeFaces) do
								local ofsx, ofsy, ofsz = sides.dirs[faceIndex]:unpack()
								local nx = i + ofsx
								local ny = j + ofsy
								local nz = k + ofsz
								local nbhdtileIsUnitCube
								-- TODO test if it's along the sides, if not just use offset + step
								-- if so then use map:get
								local nbhdtiletype = map:get(nx, ny, nz)
								if nbhdtiletype > 0 then
									local nbhdtile = Tile.types[nbhdtiletype]
									if nbhdtile then
										nbhdtileIsUnitCube = nbhdtile.isUnitCube
									end
								end
								if not nbhdtileIsUnitCube then
									for ti=1,6 do
										local vi = Tile.unitQuadTriIndexes[ti]
										local vtx = faces[vi]
										local v = tile.cubeVtxs[vtx+1]

										local c = self.colors:emplace_back()
										local l = 255 * v[3]
										c:set(l, l, l, 255)

										local tc = self.texcoords:emplace_back()
										tc:set(
											(texIndexX + tile.unitquad[vi][1]) * texpackDx,
											(texIndexY + tile.unitquad[vi][2]) * texpackDy
										)

										local vtx = self.vtxs:emplace_back()
										vtx:set(i + v[1], j + v[2], k + v[3])
									end
								end
							end
						else
							print'TODO'
						end
					end
				end
				index = index + 1
			end
		end
	end

	-- 184816 vertexes total ...
	-- ... from 196608 cubes
-- [[	
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
	self.sceneObj.texs[1] = game.texpack
	self.sceneObj:draw()
end


local Map = class()

-- voxel-based
function Map:init(args)	-- vec3i
	self.game = assert(args.game)
	local game = self.game
	local app = game.app

	self.sizeInChunks = vec3i(assert(args.sizeInChunks))
	self.chunkVolume = self.sizeInChunks:volume()
	self.size = self.sizeInChunks:map(function(x,i) return x * Chunk.size.s[i] end)
	self.volume = self.size:volume()

	-- 0-based index, based on chunk position
	self.chunks = {}


	-- setup shader before creating chunks
	self.shader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec3 vertex;
in vec2 texcoord;
in vec4 color;

out vec3 viewPosv;
out vec2 texcoordv;
out vec4 colorv;

//model transform is ident for map
// so this is just the view mat + proj mat
uniform mat4 mvMat;
uniform mat4 projMat;

void main() {
	texcoordv = texcoord;
	colorv = color;
	
	vec4 viewPos = mvMat * vec4(vertex, 1.);
	viewPosv = viewPos.xyz;
	
	gl_Position = projMat * viewPos;
}
]],
		fragmentCode = app.glslHeader..[[
in vec3 viewPosv;
in vec2 texcoordv;
in vec4 colorv;

out vec4 fragColor;

uniform sampler2D tex;
uniform bool useSeeThru;
uniform vec3 playerViewPos;

//lol, C standard is 'const' associates left
//but GLSL requires it to associate right
const float cosClipAngle = .9;	// = cone with 25 degree from axis 

void main() {
	fragColor = texture(tex, texcoordv);
	fragColor.xyz *= colorv.xyz;

	// keep the dx dy outside the if block to prevent errors.
	if (useSeeThru) {
		vec3 dx = dFdx(viewPosv);
		vec3 dy = dFdy(viewPosv);
		vec3 testViewPos = playerViewPos + vec3(0., 0., 0.);
		if (normalize(viewPosv - testViewPos).z > cosClipAngle) {
			vec3 n = normalize(cross(dx, dy));
			//if (dot(n, testViewPos - viewPosv) < -.01) 
			{
				fragColor.w = .1;
				discard;
			}
		}
	}
}
]],
		uniforms = {
			tex = 0,
		},
	}:useNone()

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

	-- key = index in map.objsPerTileIndex = offset of the tile in the map
	-- value = list of all objects on that tile
	self.objsPerTileIndex = {}

	self.texpackSize = vec2i(2, 2)
end

function Map:buildDrawArrays()
	for chunkIndex=0,self.chunkVolume-1 do
--print('building chunk', chunkIndex)	
		self.chunks[chunkIndex]:buildDrawArrays()
	end
end

function Map:draw()
	local game = self.game
	local app = game.app

	for chunkIndex=0,self.chunkVolume-1 do
		self.chunks[chunkIndex]:draw(app, game)
	end

	glreport'here'
end

-- return the ptr to the map tile
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
-- TODO call this 'getType' ?
function Map:get(i,j,k)
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
	local tileIndex = x + self.size.x * (y + self.size.y * z)
	return self.objsPerTileIndex[tileIndex]
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

return Map
