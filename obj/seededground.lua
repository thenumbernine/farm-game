local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local SeededGround = Obj:subclass()

SeededGround.sprite = 'seededground'
SeededGround.useGravity = false
SeededGround.collidesWithTiles = false
SeededGround.collidesWithObjects = false
SeededGround.bbox = box3f{
	min = {-.3, -.3, -.001},
	max = {.3, .3, .001},
}

function SeededGround:init(args)
	SeededGround.super.init(self, args)


--[=[ I don't need custom-shader just yet ... 
	-- static-init
	if not SeededGround.shader then
		local GLProgram = require 'gl.program'
		local app = self.game.app
		SeededGround.shader = GLProgram{
			vertexCode = app.glslHeader..[[
in vec3 pos;
in vec3 texcoord;

uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat4 projectionMatrix;

out vec2 texcoordv;

void main() {
	texcoordv = texcoord.xy;
	gl_Position = projectionMatrix * (viewMatrix * (modelMatrix * vec4(pos, 1.)));
}
]],
		fragmentCode = app.glslHeader..[[
in vec2 texcoordv;
out vec4 fragColor;
uniform sampler2D tex;
void main() {
	fragColor = texture(tex, texcoordv.xy);
}
]],
	
		}
	end
--]=]
	-- TODO some kind of shader for drawing dif kinds per-seed ?
	-- maybe just dif colors for now

	-- is a class, subclass of item/seeds
	self.seedType = assert(args.seedType)
	
	self.color:set(self.seedType.plant.color:unpack())

end

return SeededGround 
