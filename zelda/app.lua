local ffi = require 'ffi'
local bit = require 'bit'
local range = require 'ext.range'
local table = require 'ext.table'
local fromlua = require 'ext.fromlua'
local path = require 'ext.path'
local sdl = require 'ffi.req' 'sdl'
local ig = require 'imgui'
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local vec4f = require 'vec-ffi.vec4f'
local quatd = require 'vec-ffi.quatd'
local Image = require 'image'
local matrix_ffi = require 'matrix.ffi'
local gl = require 'gl'
local GLProgram = require 'gl.program'
local GLGeometry = require 'gl.geometry'
local GLSceneObject = require 'gl.sceneobject'
local GLTex2D = require 'gl.tex2d'
local GLArrayBuffer = require 'gl.arraybuffer'
local Game = require 'zelda.game'
local getTime = require 'ext.timer'.getTime
local OBJLoader = require 'mesh.objloader'

require 'glapp.view'.useBuiltinMatrixMath = true

--[[
so dilemma
1) put each attr in a separate buffer
	then we get SoA which is supposed to be fastest
	but upon resize we have to resize per attribute
	so resize is slowest
2) put all in a struct
	then we get AoS which is slower
	but resize is faster
	but what about vertexes?  those need to be in 4's
	I can use gl_VertexID's lower 4 bits for that.
--]]
ffi.cdef[[
typedef struct {
	// attributes with divisor = 4
	union {
		struct {
			uint8_t hflip : 1;
			uint8_t vflip : 1;
			uint8_t disableBillboard : 1;
			uint8_t useSeeThru : 1;
		};
		uint8_t flags;
	};
	
	// ... or store these in an array, indexed by sprite frame, and just put the sprite frame here ...
	vec2f_t atlasTcPos;
	vec2f_t atlasTcSize;
	
	vec2f_t drawCenter;
	vec2f_t drawSize;
	float drawAngle;
	float angle;
	vec3f_t pos;
	vec3f_t spritePosOffset;
	// TODO:
	//vec4f_t colorMatrix[4];
	// until then:
	vec4f_t colorMatrixR;
	vec4f_t colorMatrixG;
	vec4f_t colorMatrixB;
	vec4f_t colorMatrixA;
} sprite_t;
]]

-- matches spriteShader
ffi.cdef[[
enum {
	SPRITEFLAG_HFLIP				= 1,
	SPRITEFLAG_VFLIP				= 2,
	SPRITEFLAG_DISABLE_BILLBOARD	= 4,
	SPRITEFLAG_USE_SEE_THRU			= 8,
};
]]

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

-- [=[ load sprite texture atlas
	self.spriteAtlasTex = GLTex2D{
		filename = 'sprites/atlas.png',
		magFilter = gl.GL_LINEAR,
		minFilter = gl.GL_NEAREST,
	}
	-- key/value from filename to rect
	self.spriteAtlasMap = assert(fromlua(assert(path'sprites/atlas.lua':read())))
--]=]

-- [=[ load tex2ds for anim
	local GLTex2D = require 'gl.tex2d'
	local anim = require 'zelda.anim'
	for _,sprite in pairs(anim) do
		for seqname,seq in pairs(sprite) do
			if seqname ~= 'useDirs' then	-- skip properties
				for _,frame in pairs(seq) do
					local fn = frame.filename
					if fn:sub(-4) == '.png' then
						--[[
						frame.tex = GLTex2D{
							filename = frame.filename,
							magFilter = gl.GL_LINEAR,
							minFilter = gl.GL_NEAREST,
						}
						--]]
						-- .pos, .size
						local rectsrc = assert(self.spriteAtlasMap[frame.filename])
						-- atlas pos and size
						frame.atlasTcPos = vec2f(table.unpack(rectsrc.pos))
						frame.atlasTcSize = vec2f(table.unpack(rectsrc.size))
					elseif fn:sub(-4) == '.obj' then
error("you're using .obj")
						frame.mesh = OBJLoader():load(fn)
					else
						print("idk how to load this file")
					end
				end
			end
		end
	end
--]=]
	
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
//in vec2 vertex; // just use 1st 2 bits of gl_VertexID

// this sprite's texcoord pos and size in the atlas
in vec2 atlasTcPos;
in vec2 atlasTcSize;

// matches ffi.cdef above
#define SPRITEFLAG_HFLIP				1
#define SPRITEFLAG_VFLIP				2
#define SPRITEFLAG_DISABLE_BILLBOARD	4
#define SPRITEFLAG_USE_SEE_THRU			8
/*
	default uvscale = (-1, 1)
flip = flip uvscale.x
mirror = flip uvscale.y
disableBillboard = use world basis (rotated by 'angle') instead of view basis (rotated by 'drawAngle')
*/
in int flags;

//what uv coordinates to center the sprite at (y=1 is bottom)
in vec2 drawCenter;

in vec2 drawSize;
in float drawAngle;
in float angle;
in vec3 pos;
in vec3 spritePosOffset;
//I think the 4th row is always {0,0,0,alpha}
in vec4 colorMatrixR;	
in vec4 colorMatrixG;	
in vec4 colorMatrixB;	
in vec4 colorMatrixA;	

out vec2 texcoordv;
out vec3 viewPosv;
flat out mat4 colorMatrixv;
flat out int useSeeThruv;

uniform mat4 viewMat;
uniform mat4 projMat;
uniform vec2 atlasInvSize;

const vec2 vertexes[6] = vec2[6](
	vec2(0,0),
	vec2(1,0),
	vec2(0,1),
	vec2(0,1),
	vec2(1,0),
	vec2(1,1)
);

void main() {
	// can't just assign a mat4 varying to a mat4-of-col-vectors 
	// ... can't assign the varying's individual col vectors either
	// gotta assign a temp mat4 here first
	mat4 colorMatrix = mat4(
		colorMatrixR,
		colorMatrixG,
		colorMatrixB,
		colorMatrixA);
	colorMatrixv = colorMatrix;
	useSeeThruv = ((flags & SPRITEFLAG_USE_SEE_THRU) != 0) ? 1 : 0;

#if 0
	// welp, quads is deprecated / not in ES
	// so I have to draw quads in batches of 6 instead of 4
	// so I can't just use bit operations ...
	vec2 vertex = vec2(
		float(gl_VertexID & 1),
		float((gl_VertexID >> 1) & 1)
	);
#elif 0
	/*
	quad <-> tri uses indexes 
	gl_VertexID%6	u	v
	0 = 000b		{0,0}
	1 = 001b		{1,0}
	2 = 010b		{0,1}
	3 = 011b		{0,1}
	4 = 100b		{1,0}
	5 = 101b		{1,1}
	so 
	u = (id>>2)&1 | (id==1)
	v = (id>>1)&1 | (id==5)
	*/
	int idmod6 = gl_VertexID % 6;
	vec2 vertex = vec2(
		float(((idmod6 >> 2) & 1) | int(idmod6 == 1)),
		float(((idmod6 >> 1) & 1) | int(idmod6 == 5))
	);
#else
	vec2 vertex = vertexes[gl_VertexID % 6];
#endif

	vec2 uvscale = vec2(-1., 1.);
	if ((flags & SPRITEFLAG_HFLIP) != 0) uvscale.x *= -1.;
	if ((flags & SPRITEFLAG_VFLIP) != 0) uvscale.y *= -1.;
	texcoordv = (vertex - .5) * uvscale + .5;
	// convert from integer to texture-atlas space
	texcoordv = (texcoordv * atlasTcSize + atlasTcPos) * atlasInvSize;

	vec2 c = (drawCenter - vertex) * drawSize;

	// hmm, faster to just store cos and sin outside and use cplx mul?
	vec2 drawAngleDir = vec2(cos(drawAngle), sin(drawAngle));
	c = vec2(
		c.x * drawAngleDir.x - c.y * drawAngleDir.y,
		c.x * drawAngleDir.y + c.y * drawAngleDir.x
	);
	vec4 worldpos = vec4(pos + spritePosOffset, 1.);

	vec3 ex, ey;
	if ((flags & SPRITEFLAG_DISABLE_BILLBOARD) != 0) {
		// same question as drawAngleDir above ...
		vec2 angleDir = vec2(cos(angle), sin(angle));
		ex = vec3(angleDir.x, angleDir.y, 0.);
		ey = vec3(-angleDir.y, angleDir.x, 0.);
	} else {
		ex = vec3(viewMat[0].x, viewMat[1].x, viewMat[2].x);
		ey = vec3(viewMat[0].y, viewMat[1].y, viewMat[2].y);
	}
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
flat in mat4 colorMatrixv;
flat in int useSeeThruv;

out vec4 fragColor;

uniform sampler2D tex;

uniform vec3 playerViewPos;

const float cosClipAngle = .9;	// = cone with 25 degree from axis

// gl_FragCoord is in pixel coordinates with origin at lower-left
void main() {
	fragColor = colorMatrixv * texture(tex, texcoordv);

	// alpha-testing
	if (fragColor.a < .1) discard;

	if (useSeeThruv != 0) {
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
			atlasInvSize = {
				1 / self.spriteAtlasTex.width,
				1 / self.spriteAtlasTex.height,
			},
		},
	}:useNone()


	-- NOTICE these have a big perf hit when resizing ...
	local vector = require 'ffi.cpp.vector'
	self.spritesBufCPU = vector'sprite_t'
	self.spritesBufCPU:reserve(60000)	-- TODO error on growing, like the map vectors, and TODO better vector<->GLArrayBuffer coupling + growing of GL buffers 
	self.spritesBufGPU = GLArrayBuffer{
		size = ffi.sizeof'sprite_t' * self.spritesBufCPU.capacity,
		data = self.spritesBufCPU.v,
		usage = gl.GL_DYNAMIC_DRAW,
	}

	-- hmm no resizing for now
	self.spritesBufCPU.reserve = function(self, newcap)
		if newcap <= self.capacity then return end
		print('asked for resize to', newcap, 'when our cap was', self.capacity)
		error'here'
	end

	self.spriteSceneObj = GLSceneObject{
		geometry = GLGeometry{
			mode = gl.GL_TRIANGLES,
			count = 0,
		},
		program = self.spriteShader,
		-- TODO can I just copy the spriteShader.attrs and insert the buffer and offset?
		attrs = {
			flags = {
--				divisor = 6,	-- 6 vtxs per 2 tris <-> 1 quad
				size = 1,
				type = gl.GL_INT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'flags'),
				buffer = self.spritesBufGPU,
			},
			atlasTcPos = {
--				divisor = 6,
				size = 2,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'atlasTcPos'),
				buffer = self.spritesBufGPU,
			},
			atlasTcSize = {
--				divisor = 6,
				size = 2,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'atlasTcSize'),
				buffer = self.spritesBufGPU,
			},
			drawCenter = {
--				divisor = 6,
				size = 2,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'drawCenter'),
				buffer = self.spritesBufGPU,
			},	
			drawSize = {
--				divisor = 6,
				size = 2,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'drawSize'),
				buffer = self.spritesBufGPU,
			},
			drawAngle = {
--				divisor = 6,
				size = 1,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'drawAngle'),
				buffer = self.spritesBufGPU,
			},
			angle = {
--				divisor = 6,
				size = 1,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'angle'),
				buffer = self.spritesBufGPU,
			},
			pos = {
--				divisor = 6,
				size = 3,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'pos'),
				buffer = self.spritesBufGPU,
			},	
			spritePosOffset = {
--				divisor = 6,
				size = 3,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'spritePosOffset'),
				buffer = self.spritesBufGPU,
			},
			-- TODO use mat4
			colorMatrixR = {
--				divisor = 6,
				size = 4,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'colorMatrixR'),
				buffer = self.spritesBufGPU,
			},
			colorMatrixG = {
--				divisor = 6,
				size = 4,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'colorMatrixG'),
				buffer = self.spritesBufGPU,
			},	
			colorMatrixB = {
--				divisor = 6,
				size = 4,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'colorMatrixB'),
				buffer = self.spritesBufGPU,
			},	
			colorMatrixA = {
--				divisor = 6,
				size = 4,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'colorMatrixA'),
				buffer = self.spritesBufGPU,
			},	
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
	local cpuBuf = ffi.new('vec3f_t[?]', 2 * self.swordSwingNumDivs)
	self.swordSwingVtxBuf = GLArrayBuffer{
		size = ffi.sizeof(cpuBuf),
		data = cpuBuf,
		usage = gl.GL_DYNAMIC_DRAW,
	}:unbind()


	-- setup shader before creating chunks
	local Chunk = require 'zelda.map'.Chunk
	self.mapShader = GLProgram{
		vertexCode = self.glslHeader..[[
in vec3 vertex;
in vec2 texcoord;
in vec4 color;

out vec3 worldPosv;
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
	
	worldPosv = vertex;
	vec4 viewPos = mvMat * vec4(vertex, 1.);
	viewPosv = viewPos.xyz;
	
	gl_Position = projMat * viewPos;
}
]],
		fragmentCode = self.glslHeader..[[
in vec3 worldPosv;
in vec3 viewPosv;
in vec2 texcoordv;
in vec4 colorv;

out vec4 fragColor;

//tile texture
uniform sampler2D tex;

//cheap sunlighting
uniform float sunAngle;
uniform sampler2D sunAngleTex;
uniform vec3 chunkSize;

// map view clipping
uniform bool useSeeThru;
uniform vec3 playerViewPos;

//lol, C standard is 'const' associates left
//but GLSL requires it to associate right
const float cosClipAngle = .9;	// = cone with 25 degree from axis 

void main() {
	fragColor = texture(tex, texcoordv);
	fragColor.xyz *= colorv.xyz;

	// technically I should also subtract the chunkPos
	// but texcoords are fraational part, so the integer part is thrown away anyways ...
	vec2 sunTc = worldPosv.xy / chunkSize.xy;
	vec2 sunAngles = texture(sunAngleTex, sunTc).xy;
	const float sunWidthInRadians = .1;
	float sunlight = (
		smoothstep(sunAngles.x - sunWidthInRadians, sunAngles.x + sunWidthInRadians, sunAngle)
		- smoothstep(sunAngles.y - sunWidthInRadians, sunAngles.y + sunWidthInRadians, sunAngle)
	) * .9 + .1;
	fragColor.xyz *= sunlight;

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
			sunAngleTex = 1,
			chunkSize = {Chunk.size:unpack()},
		},
	}:useNone()


	--[[
	TODO here sprite uniform buffer
	and/or attribute buffers

	attributes: unit quad

	uniforms:
		vec2f uvscale - derived from bool hflip, bool vflip (unused) flags
		bool disableBillboard
		vec2f drawCenter
		vec2f drawSize
		vec2f drawAngleDir - derived from float drawAngle
		vec2f angleDir - derived from float angle
		vec3f pos - derived from vec3f pos + vec3f spritePosOffset
		mat4x4f colorMatrix

	another TODO:
		dynamic resizing GL buffers
	like std::vector but for GL
	in fact, why not build it into thel GLBuffer class?
	--]]

	-- tex pack for the map
	-- TODO merge with sprite texpack?
	self.mapTexAtlas = GLTex2D{
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
