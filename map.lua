local class = require 'ext.class'
local ffi = require 'ffi'
local template = require 'template'
local vec2i = require 'vec-ffi.vec2i'
local vec3i = require 'vec-ffi.vec3i'
local Tile = require 'zelda.tile'
local gl = require 'gl'
local GLProgram = require 'gl.program'

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
	for k=0,self.size.z-1 do
		for j=0,self.size.y-1 do
			for i=0,self.size.x-1 do
				local maptype = Tile.typeValues.Empty
				local maptex = 0
				if k % 8 == 0 then
					maptype = Tile.typeValues.Solid
					maptex = 1
				elseif k % 8 == 1 then
					if (i % 8 == 3 or i % 8 == 4)
					and (j % 8 == 3 or j % 8 == 4)
					then
						maptype = Tile.typeValues.Solid
					elseif i % 8 >= 2 and i % 8 <= 5
					and j % 8 >= 2 and j % 8 <= 5
					then
						maptype = Tile.typeValues.SolidBottomHalf
					end
				end
				local index = i + self.size.x * (j + self.size.y * k)
				self.map[index].type = maptype
				self.map[index].tex = maptex
			end
		end
	end

	-- stairway
	for k=0,self.size.z-1 do
		local i = 3 + math.floor(math.sqrt(.5) * math.cos(.5 * math.pi * (k + .5)))
		local j = 3 + math.floor(math.sqrt(.5) * math.sin(.5 * math.pi * (k + .5)))
		self.map[i + self.size.x * (j + self.size.y * k)].type = Tile.typeValues.Solid
	end

	self.texpackSize = vec2i(2, 2)

	self.shader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec3 vertex;
in vec2 texcoord;

out vec2 texcoordv;

uniform mat4 mvProjMat;

void main() {
	texcoordv = texcoord;
	gl_Position = mvProjMat * vec4(vertex, 1.);
}
]],
		fragmentCode = app.glslHeader..template([[
#define texpackDx 	<?=clnumber(1/tonumber(texpackSize.x))?>
#define texpackDy	<?=clnumber(1/tonumber(texpackSize.y))?>
#define texpackDelta	vec2(texpackDx, texpackDy)

in vec2 texcoordv;
out vec4 fragColor;

uniform vec2 texindex;
uniform sampler2D tex;
uniform vec4 viewport;
uniform bool useSeeThru;
uniform float playerProjZ;

void main() {
	fragColor = texture(tex, (texindex + texcoordv) * texpackDelta);

	if (useSeeThru &&
		length(
			gl_FragCoord.xy - .5 * viewport.zw
		) < .35 * viewport.w &&
		gl_FragCoord.z < playerProjZ
	) {
		fragColor.a = .1;
	}
}
]], 	{
			clnumber = require 'cl.obj.number',
			texpackSize = self.texpackSize,
		}),
		uniforms = {
			texindex = {0, 0},
			tex = 0,
		},
	}
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
	gl.glUniform1f(shader.uniforms.playerProjZ.loc, game.playerProjZ)

	texpack:bind()
	local index = 0
	for k=0,self.size.z-1 do
		for j=0,self.size.y-1 do
			for i=0,self.size.x-1 do
				local maptile = self.map[index]
				local tiletype = maptile.type
				if tiletype > 0 then	-- skip empty
					local tile = Tile.types[tiletype]
					if tile then
						local texindex = tonumber(maptile.tex)
						local texindexX = texindex % self.texpackSize.x
						local texindexY = (texindex - texindexX) / self.texpackSize.x
						gl.glUniform2f(shader.uniforms.texindex.loc, texindexX, texindexY)
						tile:render(i,j,k, shader)
					end
				end
				index = index + 1
			end
		end
	end
	texpack:unbind()
	shader:useNone()
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
	return self.map[i + self.size.x * (j + self.size.y * k)].type
end

return Map
