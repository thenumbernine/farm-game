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
local GLVertexArray = require 'gl.vertexarray'
local simplexnoise = require 'simplexnoise.3d'
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

local Map = class()

-- voxel-based
function Map:init(args)	-- vec3i
	self.game = assert(args.game)
	local game = self.game
	local app = game.app

	self.size = vec3i(args.size:unpack())
	self.map = ffi.new('maptype_t[?]', self.size:volume())
	ffi.fill(self.map, 0, ffi.sizeof'maptype_t' * self.size:volume())	-- 0 = empty
	local blockSize = 8
	local half = bit.rshift(self.size.z, 1)
	local step = vec3i(1, self.size.x, self.size.x * self.size.y)
	local ijk = vec3i()
	local xyz = vec3f()
	for k=0,self.size.z-1 do
		ijk.z = k
		xyz.z = k / blockSize
		for j=0,self.size.y-1 do
			ijk.y = j
			xyz.y = j / blockSize
			for i=0,self.size.x-1 do
				ijk.x = i
				xyz.x = i / blockSize
				local c = simplexnoise(xyz:unpack())
				local maptype = Tile.typeValues.Empty
				local maptex = k >= half-1 and 0 or 1
				if k >= half then
					c = c + (k - half) * .5
				end
				if c < .5
				then
					maptype = 
						maptex == 1
						and Tile.typeValues.Stone
						or Tile.typeValues.Grass
				end
				local index = ijk:dot(step)
				self.map[index].type = maptype
				self.map[index].tex = maptex
			end
		end
	end

	-- key = index in map.objsPerTileIndex = offset of the tile in the map
	-- value = list of all objects on that tile
	self.objsPerTileIndex = {}

	self.texpackSize = vec2i(2, 2)

	self.shader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec3 vertex;
in vec2 texcoord;
in vec4 color;

out vec3 posv;
out vec2 texcoordv;
out vec4 colorv;

uniform mat4 mvProjMat;

void main() {
	texcoordv = texcoord;
	colorv = color;
	posv = vertex;
	gl_Position = mvProjMat * vec4(vertex, 1.);
}
]],
		fragmentCode = app.glslHeader..[[
in vec3 posv;
in vec2 texcoordv;
in vec4 colorv;

out vec4 fragColor;

uniform sampler2D tex;
uniform vec4 viewport;
uniform bool useSeeThru;
uniform float playerPosZ;
uniform float playerClipZ;

void main() {
	fragColor = texture(tex, texcoordv);
	fragColor.xyz *= colorv.xyz;
	if (useSeeThru &&
		length(
			gl_FragCoord.xy - .5 * viewport.zw
		) < .15 * viewport.w &&
		gl_FragCoord.z < playerClipZ &&
		posv.z > playerPosZ
	) {
		fragColor.w = .1;
		discard;
	}
}
]],
		uniforms = {
			tex = 0,
		},
	}:useNone()

	-- geometry
	self.vtxs = vector'vec3f_t'
	self.texcoords = vector'vec2f_t'
	self.colors = vector'vec4ub_t'

	self:buildDrawArrays()
end

function Map:buildDrawArrays()
	local volume = self.size:volume()
	-- [[ using reserve and heuristic of #cubes ~ #vtxs: brings time taken from 12 s to 0.12 s
	self.vtxs:resize(0)
	self.vtxs:reserve(2*volume)
	self.texcoords:resize(0)
	self.texcoords:reserve(2*volume)
	self.colors:resize(0)
	self.colors:reserve(2*volume)
	--]]
	local texpackDx = 1/tonumber(self.texpackSize.x)
	local texpackDy = 1/tonumber(self.texpackSize.y)
	local index = 0
	for k=0,self.size.z-1 do
		for j=0,self.size.y-1 do
			for i=0,self.size.x-1 do
				local maptile = self.map[index]
				local tiletype = maptile.type
				if tiletype > 0 then	-- skip empty
					local tile = Tile.types[tiletype]
					if tile then
						local texIndex = tonumber(maptile.tex)
						local texIndexX = texIndex % self.texpackSize.x
						local texIndexY = (texIndex - texIndexX) / self.texpackSize.x
						
						if tile.isUnitCube then
							assert(tile.cubeFaces)
							-- faceIndex is 1-based but lines up with sides bitflags
							for faceIndex,faces in ipairs(tile.cubeFaces) do
								local ofsx, ofsy, ofsz = sides.dirs[faceIndex]:unpack()
								local nx = i + ofsx
								local ny = j + ofsy
								local nz = k + ofsz
								local nbhdtileIsUnitCube
								if nx >= 0 and nx < self.size.x
								and ny >= 0 and ny < self.size.y
								and nz >= 0 and nz < self.size.z
								then
									local nbhdtiletype = self.map[nx + self.size.x * (ny + self.size.y * nz)].type
									if nbhdtiletype > 0 then
										local nbhdtile = Tile.types[nbhdtiletype]
										if nbhdtile then
											nbhdtileIsUnitCube = nbhdtile.isUnitCube
										end
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
	print('volume', volume)
	print('vtxs', self.vtxs.size)

	-- TODO Don't reallocate gl buffers each time.
	-- OpenGL growing buffers via glCopyBufferSubData:
	-- https://stackoverflow.com/a/27751186/2714073

	self.vtxBuf = GLArrayBuffer{
		size = ffi.sizeof(self.vtxs.type) * self.vtxs.size,
		data = self.vtxs.v,
		-- TDOO why does dynamic draw make it black?
		--usage = gl.GL_DYNAMIC_DRAW,
	}:unbind()

	self.texcoordBuf = GLArrayBuffer{
		size = ffi.sizeof(self.texcoords.type) * self.texcoords.size,
		data = self.texcoords.v,
		--usage = gl.GL_DYNAMIC_DRAW,
	}:unbind()
	
	self.colorBuf = GLArrayBuffer{
		size = ffi.sizeof(self.colors.type) * self.colors.size,
		data = self.colors.v,
		--usage = gl.GL_DYNAMIC_DRAW,
	}:unbind()

	-- TODO put this in a GLSceneObject object instead
	-- and give that its own set of attrs, uniforms, shader, geometry
	self.shader.vao = GLVertexArray{
		program = self.shader,
		attrs = {
			vertex = {
				loc = self.shader.attrs.vertex.loc, 
				buffer = self.vtxBuf,
				type = gl.GL_FLOAT,
				size = 3,
				stride = 0,
			},
			texcoord = {
				loc = self.shader.attrs.texcoord.loc,
				buffer = self.texcoordBuf,
				type = gl.GL_FLOAT,
				size = 2,
				stride = 0,
			},
			color = {
				loc = self.shader.attrs.color.loc,
				buffer = self.colordBuf,
				type = gl.GL_UNSIGNED_BYTE,
				size = 4,
				normalize = true,
				stride = 0,
			},
		},
	}:useNone()
end

function Map:draw()
	local game = self.game
	local app = game.app
	local view = app.view
	local shader = self.shader
	local texpack = game.texpack
	
	shader:use()

	gl.glUniformMatrix4fv(shader.uniforms.mvProjMat.loc, 1, gl.GL_FALSE, view.mvProjMat.ptr)
	gl.glUniform4f(shader.uniforms.viewport.loc, 0, 0, app.width, app.height)
	gl.glUniform1i(shader.uniforms.useSeeThru.loc, 1)
	if shader.uniforms.playerPosZ then
		gl.glUniform1f(shader.uniforms.playerPosZ.loc, game.playerPosZ)
	end
	if shader.uniforms.playerClipZ then
		gl.glUniform1f(shader.uniforms.playerClipZ.loc, game.playerClipZ)
	end

	texpack:bind()

	-- TODO why do i have to set this twice?
	--[[ cpu bind ... works
	gl.glVertexAttribPointer(shader.attrs.vertex.loc, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, self.vtxs.v)
	gl.glVertexAttribPointer(shader.attrs.texcoord.loc, 2, gl.GL_FLOAT, gl.GL_FALSE, 0, self.texcoords.v)
	gl.glVertexAttribPointer(shader.attrs.color.loc, 4, gl.GL_UNSIGNED_BYTE, gl.GL_TRUE, 0, self.colors.v)
	--]]
	-- [[ gpu bind ... works
	self.vtxBuf:bind()
	gl.glVertexAttribPointer(shader.attrs.vertex.loc, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, nil)
	self.texcoordBuf:bind()
	gl.glVertexAttribPointer(shader.attrs.texcoord.loc, 2, gl.GL_FLOAT, gl.GL_FALSE, 0, nil)
	self.colorBuf:bind()
	gl.glVertexAttribPointer(shader.attrs.color.loc, 4, gl.GL_UNSIGNED_BYTE, gl.GL_TRUE, 0, nil)
	GLArrayBuffer:unbind()
	--]]
	--[[ vao ... doesn't work?
	-- redundant call to vao attr:enable?
	--shader:enableAttrs()
	--so instead?
	shader.vao:bind()
	--]]
	gl.glEnableVertexAttribArray(shader.attrs.vertex.loc)
	gl.glEnableVertexAttribArray(shader.attrs.texcoord.loc)
	gl.glEnableVertexAttribArray(shader.attrs.color.loc)

	gl.glDrawArrays(gl.GL_TRIANGLES, 0, self.vtxs.size)

	--[[ vao?
	-- enable/disble saved in vao state?
	--shader:disableAttrs()
	-- so instead?
	shader.vao:unbind()
	--]]
	-- [[ enable/disble
	gl.glDisableVertexAttribArray(shader.attrs.vertex.loc)
	gl.glDisableVertexAttribArray(shader.attrs.texcoord.loc)
	gl.glDisableVertexAttribArray(shader.attrs.color.loc)
	--]]

	texpack:unbind()

	shader:useNone()
	glreport'here'
end

-- i,j,k integers
function Map:get(i,j,k)
	if i < 0 or i >= self.size.x
	or j < 0 or j >= self.size.y
	or k < 0 or k >= self.size.z
	then
		return Tile.typeValues.Empty
	end
	return self.map[i + self.size.x * (j + self.size.y * k)].type
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
