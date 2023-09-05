local ffi = require 'ffi'
local bit = require 'bit'
local range = require 'ext.range'
local table = require 'ext.table'
local path = require 'ext.path'
local sdl = require 'ffi.req' 'sdl'
local ig = require 'imgui'
local quatd = require 'vec-ffi.quatd'
local Image = require 'image'
local matrix_ffi = require 'matrix.ffi'
local gl = require 'gl'
local GLProgram = require 'gl.program'
local GLSceneObject = require 'gl.sceneobject'
local GLTex2D = require 'gl.tex2d'
local GLArrayBuffer = require 'gl.arraybuffer'
local Game = require 'zelda.game'
local getTime = require 'ext.timer'.getTime
local OBJLoader = require 'mesh.objloader'

require 'glapp.view'.useBuiltinMatrixMath = true

local App = require 'gameapp':subclass()

App.title = 'Zelda 4D'

App.viewDist = 7

App.showFPS = true


-- override Menus
local Menu = require 'gameapp.menu.menu'
Menu.Splash = require 'zelda.menu.splash'

Menu.Playing = require 'zelda.menu.playing'

--[[
keyPress.s:
	- jump
	- use item (sword, hoe, watering can, etc)
	- pick up
		... (I could combine this with 'use' and make it mandatory to select to an empty inventory slot ...)
		... or I could get rid of this and have objects change to a touch-to-pick-up state like they do in minecraft and stardew valley
	- talk/interact
		... this could be same as pick-up, but for NPCs ...

TODO in gameapp put these in Player
and then have zelda/player subclass them
--]]
local PlayerKeysEditor = require 'gameapp.menu.playerkeys'
PlayerKeysEditor.defaultKeys = {
	{
		up = {sdl.SDL_KEYDOWN, sdl.SDLK_UP},
		down = {sdl.SDL_KEYDOWN, sdl.SDLK_DOWN},
		left = {sdl.SDL_KEYDOWN, sdl.SDLK_LEFT},
		right = {sdl.SDL_KEYDOWN, sdl.SDLK_RIGHT},
		jump = {sdl.SDL_KEYDOWN, ('x'):byte()},
		useItem = {sdl.SDL_KEYDOWN, ('z'):byte()},
		interact = {sdl.SDL_KEYDOWN, ('c'):byte()},
		invLeft = {sdl.SDL_KEYDOWN, ('a'):byte()},
		invRight = {sdl.SDL_KEYDOWN, ('s'):byte()},
		openInventory = {sdl.SDL_KEYDOWN, ('d'):byte()},
		rotateLeft = {sdl.SDL_KEYDOWN, ('q'):byte()},
		rotateRight = {sdl.SDL_KEYDOWN, ('w'):byte()},
		pause = {sdl.SDL_KEYDOWN, sdl.SDLK_ESCAPE},
	},
	{
		up = {sdl.SDL_KEYDOWN, ('w'):byte()},
		down = {sdl.SDL_KEYDOWN, ('s'):byte()},
		left = {sdl.SDL_KEYDOWN, ('a'):byte()},
		right = {sdl.SDL_KEYDOWN, ('d'):byte()},
		pause = {},	-- sorry keypad player 2
	},
}

App.saveBaseDir = path'save'

-- just hack the main menu class instead of subclassing it.
local MainMenu = require 'gameapp.menu.main'
function MainMenu:update()
-- why does this hide the gui?
--	self.app.splashMenu:update()
end
MainMenu.menuOptions:removeObject(nil, function(o)
	return o.name == 'New Game Co-op'
end)
MainMenu.menuOptions:removeObject(nil, function(o)
	return o.name == 'High Scores'
end)
MainMenu.menuOptions:insert(3, {
	name = 'Save Game',
	click = function(self)
		-- TODO save menu?
		-- or TODO pick a filename upon 'new game' and just save there?
		local app = self.app
		local game = app.game
		if not game then return end
		app:saveGame(app.saveBaseDir/game.saveDir)
		-- TODO print upon fail or something
	end,
	visible = function(self)
		return not not (self.app and self.app.game)
	end,
})

MainMenu.menuOptions:insert(4, {
	name = 'Load Game',
	click = function(self)
		local app = self.app
		app.menu = require 'zelda.menu.loadgame'(app)
	end,
	visible = function(self)
		local app = self.app
		-- TODO detect upon construction and upon save?
		local num = 0
		if app.saveBaseDir:exists()
		and app.saveBaseDir:isdir() then
			for fn in app.saveBaseDir:dir() do
				if (app.saveBaseDir/fn):isdir() then
					num = num + 1
				end
			end
		end
		return num > 0
	end,
})

App.url = 'https://github.com/thenumbernine/zelda3d-lua'

local Player = require 'zelda.player'
App.Player = Player

function App:initGL()
	-- instead of proj * mv , imma separate into: proj view model
	-- that means view.mvMat is really the view matrix
	App.super.initGL(self)

	self.view.fovY = 90

	self.glslHeader = [[
#version 300 es
precision highp float;
]]

	-- [[ load tex2ds for anim
	local GLTex2D = require 'gl.tex2d'
	local anim = require 'zelda.anim'
	local totalPixels  = 0
	for _,sprite in pairs(anim) do
		for seqname,seq in pairs(sprite) do
			if seqname ~= 'useDirs' then	-- skip properties
				for _,frame in pairs(seq) do
					local fn = frame.filename
					if fn:sub(-4) == '.png' then
						-- [[
						frame.tex = GLTex2D{
							filename = frame.filename,
							magFilter = gl.GL_LINEAR,
							minFilter = gl.GL_NEAREST,
						}
						--]]
						-- [[
						local image = require 'image'(frame.filename)
						local thisPixels = image.width * image.height
--print(frame.filename, 'has', thisPixels , 'pixels')
						totalPixels = totalPixels + thisPixels
						--]]
					elseif fn:sub(-4) == '.obj' then
print("WARNING - you're using .objs")						
						frame.mesh = OBJLoader():load(fn)
					else
						print("idk how to load this file")
					end
				end
			end
		end
	end
--print('total pixels', totalPixels)
--print('sqrt', math.sqrt(totalPixels))
	--]]


	-- TODO would be nice per-hour-of-the-day ...
	-- why am I not putting this in a texture?
	-- because I also want a gradient for at-ground vs undergournd
	-- but maybe I still should ..
	local skyTexData = {
		{{10, 10, 20}, {50, 50, 85}},
		{{80, 80, 120}, {70, 80, 110}},
		{{80, 120, 140}, {140, 170, 200}},
		{{0, 100, 170}, {255, 100, 0}},
		{{10, 10, 20}, {50, 50, 85}},
	}

	self.skyTex = GLTex2D{
		image = Image(#skyTexData, #skyTexData[1], 4, 'unsigned char', function(u,v)
			local t = skyTexData[u+1][v+1]
			return t[1], t[2], t[3], 255
		end),
		minFilter = gl.GL_NEAREST,
		magFilter = gl.GL_LINEAR,
		wrap = {
			s = gl.GL_CLAMP_TO_EDGE,
			t = gl.GL_CLAMP_TO_EDGE,
		},
	}

	self.skyShader = GLProgram{
		vertexCode = self.glslHeader..[[
in vec2 vertex;
out vec2 vtxv;
uniform mat4 mvProjMat;
void main() {
	vtxv = vertex;
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
}
]],
		fragmentCode = self.glslHeader..[[
in vec2 vtxv;
out vec4 fragColor;
uniform float timeOfDay;
uniform sampler2D skyTex;
void main() {
	fragColor = texture(skyTex, vec2(timeOfDay, vtxv.y));
}
]],
		uniforms = {
			skyTex = 0,
		},
	}:useNone()

	self.skySceneObj = GLSceneObject{
		geometry = self.quadGeom,
		program = self.skyShader,
		attrs = {
			vertex = self.quadVertexBuf,
		},
		texs = {
			self.skyTex,
		},
	}

	self.spriteShader = GLProgram{
		vertexCode = self.glslHeader..[[
in vec2 vertex;
out vec2 texcoordv;
out vec3 viewPosv;

uniform vec2 uvscale;

//what uv coordinates to center the sprite at (y=1 is bottom)
uniform vec2 drawCenter;

uniform vec2 drawSize;
uniform vec2 drawAngleDir;
uniform vec2 angleDir;
uniform vec3 pos;

// 0 = use world xy axis
// 1 = use view xy axis
uniform float disableBillboard;

uniform mat4 viewMat;
uniform mat4 projMat;

void main() {
	texcoordv = (vertex - .5) * uvscale + .5;

	vec2 c = (drawCenter - vertex) * drawSize;
	c = vec2(
		c.x * drawAngleDir.x - c.y * drawAngleDir.y,
		c.x * drawAngleDir.y + c.y * drawAngleDir.x
	);
	vec4 worldpos = vec4(pos, 1.);

	vec3 ex = mix(vec3(viewMat[0].x, viewMat[1].x, viewMat[2].x), vec3(angleDir.x, angleDir.y, 0.), disableBillboard);
	vec3 ey = mix(vec3(viewMat[0].y, viewMat[1].y, viewMat[2].y), vec3(-angleDir.y, angleDir.x, 0.), disableBillboard);
	worldpos.xyz += ex * c.x;
	worldpos.xyz += ey * c.y;

	vec4 viewPos = viewMat * worldpos;

	viewPosv = viewPos.xyz;

	gl_Position = projMat * viewPos;
}
]],
		fragmentCode = self.glslHeader..[[
in vec2 texcoordv;
in vec3 viewPosv;

out vec4 fragColor;

uniform sampler2D tex;
uniform mat4 colorMatrix;

uniform bool useSeeThru;
uniform vec3 playerViewPos;

const float cosClipAngle = .9;	// = cone with 25 degree from axis

// gl_FragCoord is in pixel coordinates with origin at lower-left
void main() {
	fragColor = colorMatrix * texture(tex, texcoordv);

	// alpha-testing
	if (fragColor.a < .1) discard;

	if (useSeeThru) {
		vec3 testViewPos = playerViewPos + vec3(0., 1., -2.);
		if (normalize(viewPosv - testViewPos).z > cosClipAngle) {
			//fragColor.w = .2;
			discard;
		}
	}
}
]],
		uniforms = {
			tex = 0,
			colorMatrix = matrix_ffi({{1,0,0,0}, {0,1,0,0}, {0,0,1,0}, {0,0,0,1}}, 'float').ptr,
		},
	}:useNone()

	self.spriteSceneObj = GLSceneObject{
		geometry = self.quadGeom,
		program = self.spriteShader,
		attrs = {
			vertex = self.quadVertexBuf,
		},
		texs = {},
	}

	self.meshShader = require 'mesh':makeShader{
		glslHeader = self.glslHeader,
	}

	self.swordShader = GLProgram{
		vertexCode = self.glslHeader..[[
in vec3 vertex;
in vec4 color;
out vec4 colorv;
uniform mat4 mvProjMat;
void main() {
	colorv = color;
	gl_Position = mvProjMat * vec4(vertex, 1.);
}
]],
		fragmentCode = self.glslHeader..[[
in vec4 colorv;
out vec4 fragColor;
void main() {
	fragColor = colorv;
}
]],
	}:useNone()

	self.swordSwingNumDivs = 20
	self.swordSwingVtxBufCPU = ffi.new('vec3f_t[?]', 2 * self.swordSwingNumDivs)
	self.swordSwingVtxBufGPU = GLArrayBuffer{
		size = ffi.sizeof(self.swordSwingVtxBufCPU),
		data = self.swordSwingVtxBufCPU,
		usage = gl.GL_DYNAMIC_DRAW,
	}:unbind()

	-- build the map

	self.texpack = GLTex2D{
		filename = 'texpack.png',
		magFilter = gl.GL_LINEAR,
		minFilter = gl.GL_NEAREST,
	}



	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glEnable(gl.GL_CULL_FACE)

	self:resetGame(true)

	self.lastTime = getTime()
	self.updateTime = 0
end

-- called by menu.NewGame
function App:resetGame(dontMakeGame)
	-- in degrees
	self.targetViewYaw = 0
	self.viewYaw = 0

	-- NOTICE THIS IS A SHALLOW COPY
	-- that means subtables (player keys, custom colors) won't be copied
	-- not sure if i should bother since neither of those things are used by playcfg but ....
	self.playcfg = table(self.cfg):setmetatable(nil)

	self.players = range(self.playcfg.numPlayers):mapi(function(i)
		return Player{index=i, app=self}
	end)

	-- TODO put this in parent class
	self.rng = self.RNG(self.playcfg.randseed)

	if not dontMakeGame then
		self.game = Game{app = self}

		-- find the next available save dir name
		self.saveBaseDir:mkdir()
		for i=1,math.huge do
			local dirname = tostring(i)
			local thissave = self.saveBaseDir/dirname
			if not thissave:exists() then
				thissave:mkdir()
				self.game.saveDir = dirname
				-- TODO initial save?
				break
			end
		end
print('App:resetGame', self.game.saveDir)
	end
end

App.updateDelta = 1/30

App.needsResortSprites = true
function App:updateGame()
	local game = self.game

	local sysThisTime = getTime()
	local sysDeltaTime = sysThisTime - self.lastTime
	self.lastTime = sysThisTime

	-- in degrees:
	self.lastViewYaw = self.viewYaw
	local dyaw = .1 * (self.targetViewYaw - self.viewYaw)
	if math.abs(dyaw) > .001 then
		self.viewYaw = self.viewYaw + dyaw
	else
		-- TODO this might fix some flickering, but there still is some more
		-- probably due to player vel being nonzero
		-- so TODO the same trick with player vel ?  only update camera follow target if it moves past some epsilon?
		self.targetViewYaw = self.targetViewYaw % (2 * math.pi)
		self.viewYaw = self.targetViewYaw
	end

	self.view.angle = quatd():fromAngleAxis(0, 0, 1, math.deg(self.viewYaw))
					* quatd():fromAngleAxis(1,0,0,30)
	self.view.pos = self.view.angle:zAxis() * (self.view.pos - self.view.orbit):length() + self.view.orbit

	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))

	--[[ not in gles ... needs to be coded into the shaders.
	gl.glEnable(gl.GL_ALPHA_TEST)
	gl.glAlphaFunc(gl.GL_GEQUAL, .1)
	--]]
	gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)
	gl.glEnable(gl.GL_BLEND)

--[[
	if math.abs(self.lastViewYaw - self.viewYaw) > .02 then
		self.needsResortSprites = true
	end
	if game and self.needsResortSprites then
		self.needsResortSprites = false
print('updating sprite z order')
		local v = self.view.angle:zAxis()
print('dir', v)
		game.objs:sort(function(a,b)
			return a.pos:dot(v) < b.pos:dot(v)
		end)
	end
--]]

	-- TODO frameskip
	if game then game:draw() end

	gl.glDisable(gl.GL_BLEND)

	self.updateTime = self.updateTime + sysDeltaTime
	if self.updateTime >= self.updateDelta then
		self.updateTime = self.updateTime - self.updateDelta
		-- fixed-framerate update
		if game and not self.paused then
			game:update(self.updateDelta)
		end
	end
end

function App:event(event, ...)
	App.super.event(self, event, ...)

-- [[ mouse rotate support?
	local canHandleMouse = not ig.igGetIO()[0].WantCaptureMouse
	if event.type == sdl.SDL_MOUSEMOTION then
		if canHandleMouse
		and bit.band(event.motion.state, 1) == 1
		then
			local dx = event.motion.xrel
			self.viewYaw = self.viewYaw + math.rad(dx)
			self.view.angle = quatd():fromAngleAxis(0, 0, 1, math.deg(self.viewYaw))
							* quatd():fromAngleAxis(1,0,0,30)
			self.view.pos = self.view.angle:zAxis() * (self.view.pos - self.view.orbit):length() + self.view.orbit
		end
	end
--]]

	if self.game then
		self.game:event(event)
	end
end

function App:saveGame(folder)
	local game = assert(self.game)
	folder:mkdir(true)
	assert(folder:isdir(), "mkdir failed")
	for i,map in ipairs(game.maps) do
		(folder/(i..'.map')):write(map:getSaveData())
	end
end

function App:loadGame(folder)
	assert(folder:isdir())
	self.game = Game{
		app = self, 
		srcdir = folder,
	}
end

return App
