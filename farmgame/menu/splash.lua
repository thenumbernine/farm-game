local getTime = require 'ext.timer'.getTime
local gl = require 'gl'
local GLTex2D = require 'gl.tex2d'
local GLProgram = require 'gl.program'
local GLSceneObject = require 'gl.sceneobject'
local GameAppSplashMenu = require 'gameapp.menu.splash'

local SplashMenu = GameAppSplashMenu:subclass()

function SplashMenu:init(app, ...)
	GameAppSplashMenu.super.init(self, app, ...)
	
	self.startTime = getTime()
	app.paused = true

	self.splashShader = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
in vec2 vertex;
out vec2 texcoordv;
uniform mat4 mvProjMat;
void main() {
	texcoordv = vec2(vertex.x, 1. - vertex.y);
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
}
]],
		fragmentCode = [[
in vec2 texcoordv;
out vec4 fragColor;

uniform sampler2D tex;

void main() {
	fragColor = texture(tex, texcoordv);
}
]],
	}:useNone()

	self.splashSceneObj = GLSceneObject{
		geometry = app.quadGeom,
		program = self.splashShader,
		attrs = {
			vertex = app.quadVertexBuf,
		},
		texs = {
			GLTex2D{
				filename = 'splash.png',
				minFilter = gl.GL_NEAREST,
			}
		},
	}
end

return SplashMenu
