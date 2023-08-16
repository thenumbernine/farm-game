local class = require 'ext.class'
local ffi = require 'ffi'
local template = require 'template'
local vector = require 'ffi.cpp.vector'
local vec2i = require 'vec-ffi.vec2i'
local vec3i = require 'vec-ffi.vec3i'
local vec3f = require 'vec-ffi.vec3f'
local vec2f = require 'vec-ffi.vec2f'
local vec4ub = require 'vec-ffi.vec4ub'
local gl = require 'gl'
local GLProgram = require 'gl.program'
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
	self.app = assert(args.app)
	local app = self.app
	self.size = vec3i(args.size:unpack())
	self.map = ffi.new('maptype_t[?]', self.size:volume())
	ffi.fill(self.map, 0, ffi.sizeof'maptype_t' * self.size:volume())	-- 0 = empty
	local blockSize = 8
	local half = bit.rshift(self.size.z, 1)
	for k=0,self.size.z-1 do
		for j=0,self.size.y-1 do
			for i=0,self.size.x-1 do
				local c = simplexnoise(i/blockSize,j/blockSize,k/blockSize)
				local maptype = Tile.typeValues.Empty
				local maptex = k >= half-1 and 0 or 1
				if k >= half then
					c = c + (k - half) * .5
				end
				if c < .5
				then
					maptype = Tile.typeValues.Solid
				end
				local index = i + self.size.x * (j + self.size.y * k)
				self.map[index].type = maptype
				self.map[index].tex = maptex
			end
		end
	end

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
	}

	-- geometry
	self.vtxs = vector'vec3f_t'
	self.texcoords = vector'vec2f_t'
	self.colors = vector'vec4ub_t'

	self:buildDrawArrays()
end

function Map:buildDrawArrays()
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
									for vi,vtx in ipairs(faces) do
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
end

function Map:draw()
	local app = self.app
	local game = app.game
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
	
	gl.glVertexAttribPointer(shader.attrs.vertex.loc, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, self.vtxs.v)
	gl.glVertexAttribPointer(shader.attrs.texcoord.loc, 2, gl.GL_FLOAT, gl.GL_FALSE, 0, self.texcoords.v)
	gl.glVertexAttribPointer(shader.attrs.color.loc, 4, gl.GL_UNSIGNED_BYTE, gl.GL_TRUE, 0, self.colors.v)
	gl.glEnableVertexAttribArray(shader.attrs.vertex.loc)
	gl.glEnableVertexAttribArray(shader.attrs.texcoord.loc)
	gl.glEnableVertexAttribArray(shader.attrs.color.loc)
	
	gl.glDrawArrays(gl.GL_QUADS, 0, self.vtxs.size)
	
	gl.glDisableVertexAttribArray(shader.attrs.vertex.loc)
	gl.glDisableVertexAttribArray(shader.attrs.texcoord.loc)
	gl.glDisableVertexAttribArray(shader.attrs.color.loc)

	texpack:unbind()
	shader:useNone()
end

-- i,j,k integers
function Map:get(i,j,k)
	if i < 0 or i >= self.size.x
	or j < 0 or j >= self.size.y
	or k < 0 or k >= self.size.z
	then
		return Tile.typeValues.Empty
		--return Tile.typeValues.Solid
	end
	return self.map[i + self.size.x * (j + self.size.y * k)].type
end

return Map
