local ffi = require 'ffi'
local bit = require 'bit'
local range = require 'ext.range'
local table = require 'ext.table'
local assert = require 'ext.assert'
local path = require 'ext.path'
local tolua = require'ext.tolua'
local sdl = require 'sdl'
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
local GLTex3D = require 'gl.tex3d'
local GLArrayBuffer = require 'gl.arraybuffer'
local glreport = require 'gl.report'
local Game = require 'farmgame.game'
local getTime = require 'ext.timer'.getTime
local OBJLoader = require 'mesh.objloader'

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

	vec3f_t drawCenter;
	vec2f_t drawSize;
	float drawAngle;
	float angle;
	vec3f_t pos;
	vec3f_t spritePosOffset;
	vec4f_t colorMatrix[4];
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

App.title = 'Farm Game'

App.viewDist = 7

App.showFPS = true


-- override Menus
local Menu = require 'gameapp.menu.menu'
Menu.Splash = require 'farmgame.menu.splash'

Menu.Main = require 'farmgame.menu.main'
Menu.Playing = require 'farmgame.menu.playing'

--[[
keyPress.s:
	- jump
	- use item (sword, hoe, watering can, etc)
	- pick up
		... (I could combine this with 'use' and make it mandatory to select to an empty inventory slot ...)
		... or I could get rid of this and have objects change to a touch-to-pick-up state like they do in minecraft and stardew valley
	- talk/interact
		... this could be same as pick-up, but for NPCs ...

TODO in gameapp put these in App.Player
and then have farmgame/player subclass them
--]]
local PlayerKeysEditor = require 'gameapp.menu.playerkeys'
PlayerKeysEditor.defaultKeys = {
	{
		up = {sdl.SDL_EVENT_KEY_DOWN, sdl.SDLK_UP},
		down = {sdl.SDL_EVENT_KEY_DOWN, sdl.SDLK_DOWN},
		left = {sdl.SDL_EVENT_KEY_DOWN, sdl.SDLK_LEFT},
		right = {sdl.SDL_EVENT_KEY_DOWN, sdl.SDLK_RIGHT},
		jump = {sdl.SDL_EVENT_KEY_DOWN, ('x'):byte()},
		useItem = {sdl.SDL_EVENT_KEY_DOWN, ('z'):byte()},
		interact = {sdl.SDL_EVENT_KEY_DOWN, ('c'):byte()},
		invLeft = {sdl.SDL_EVENT_KEY_DOWN, ('a'):byte()},
		invRight = {sdl.SDL_EVENT_KEY_DOWN, ('s'):byte()},
		openInventory = {sdl.SDL_EVENT_KEY_DOWN, ('d'):byte()},
		rotateLeft = {sdl.SDL_EVENT_KEY_DOWN, ('q'):byte()},
		rotateRight = {sdl.SDL_EVENT_KEY_DOWN, ('w'):byte()},
		pause = {sdl.SDL_EVENT_KEY_DOWN, sdl.SDLK_ESCAPE},
	},
	{
		up = {sdl.SDL_EVENT_KEY_DOWN, ('w'):byte()},
		down = {sdl.SDL_EVENT_KEY_DOWN, ('s'):byte()},
		left = {sdl.SDL_EVENT_KEY_DOWN, ('a'):byte()},
		right = {sdl.SDL_EVENT_KEY_DOWN, ('d'):byte()},
		pause = {},	-- sorry keypad player 2
	},
}

-- os.home() is HOME for linux, USERPROFILE for windows
--App.saveBaseDir = path(os.home())/'.config/FarmGame/save'
-- TODO multiple locations, ending with cwd?
do
	local diropts = table()
	if ffi.os == 'Windows' then
		diropts:insert(os.getenv'APPDATA')
	else
		local home = os.getenv'HOME'
		if home then
			diropts:insert(home..'/.config')
		end
	end
	diropts:insert'.'
	for _,dir in ipairs(diropts) do
		local p = path(dir)
		print('testing save dir '..p)
		if p:exists() then
			App.saveBaseDir = p/'FarmGame/save'
			break
		end
	end
	print('using saveBaseDir '..App.saveBaseDir)
end

App.url = 'https://github.com/thenumbernine/farm-game'

local AppPlayer = require 'farmgame.player'
App.Player = AppPlayer

function App:initGL()
	-- instead of proj * mv , imma separate into: proj view model
	-- that means view.mvMat is really the view matrix
	App.super.initGL(self)
glreport'here'

	self.mouseDir3D = vec3f(0,0,1)
	self.mousePos3D = vec3f()

	self.view.fovY = 90
	self.mvProjInvMat = self.view.mvProjMat:clone():inv4x4()

	local sampler3Dprec = [[
precision mediump sampler3D;
]]

-- [=[ load sprite texture atlas
	-- TODO rename to just 'atlasTex'
	self.spriteAtlasTex = GLTex2D{
		filename = 'sprites/atlas.png',
		magFilter = gl.GL_LINEAR,
		minFilter = gl.GL_NEAREST,
	}:unbind()
	-- key/value from filename to rect
	local spriteAtlasMap = require 'farmgame.atlas'.atlasMap
--]=]

-- [=[ load tex2ds for anim
	local anim = require 'farmgame.anim'
	for _,sprite in pairs(anim) do
		for seqname,seq in pairs(sprite) do
			if seqname ~= 'useDirs' then	-- skip properties
				for _,frame in pairs(seq) do
					local fn = frame.filename
					if fn:sub(-4) == '.png' then
						-- .pos, .size
						local texrect = assert.index(spriteAtlasMap, frame.filename, "failed to find map for sprite")
						-- atlas pos and size
						frame.atlasTcPos = vec2f(table.unpack(texrect.pos))
						frame.atlasTcSize = vec2f(table.unpack(texrect.size))
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
	}:unbind()
glreport'here'

	self.skyShader = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
in vec2 vertex;
out vec2 vtxv;
uniform mat4 mvProjMat;
void main() {
	vtxv = vertex;
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
}
]],
		fragmentCode = [[
in vec2 vtxv;
out vec4 fragColor;
uniform float timeOfDay;
uniform float inside;		// set to 1 when we're inside, or some interpolation thereof
uniform sampler2D skyTex;
void main() {
	fragColor.xyz = (1. - inside) * texture(skyTex, vec2(timeOfDay, vtxv.y)).xyz;
	fragColor.w = 1.;
}
]],
		uniforms = {
			skyTex = 0,
			inside = 0,
		},
	}:useNone()
glreport'here'

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
glreport'here'

	self.spriteShader = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
in vec2 vertex;

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
in vec3 drawCenter;

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

void main() {
	// can't just assign a mat4 varying to a mat4-of-col-vectors
	// ... can't assign the varying's individual col vectors either
	// gotta assign a temp mat4 here first
	mat4 colorMatrix = transpose(mat4(
		colorMatrixR,
		colorMatrixG,
		colorMatrixB,
		colorMatrixA));
	colorMatrixv = colorMatrix;
	useSeeThruv = flags & SPRITEFLAG_USE_SEE_THRU;

	vec2 uvscale = vec2(-1., 1.);
	if ((flags & SPRITEFLAG_HFLIP) != 0) uvscale.x *= -1.;
	if ((flags & SPRITEFLAG_VFLIP) != 0) uvscale.y *= -1.;
	texcoordv = (vertex - .5) * uvscale + .5;
	// convert from integer to texture-atlas space
	texcoordv = (texcoordv * atlasTcSize + atlasTcPos + .5) * atlasInvSize;

	vec3 c = drawCenter;
	c.xy -= vertex;
	c.xy *= drawSize;

	// hmm, faster to just store cos and sin outside and use cplx mul?
	vec2 drawAngleDir = vec2(cos(drawAngle), sin(drawAngle));
	c.xy = vec2(
		c.x * drawAngleDir.x - c.y * drawAngleDir.y,
		c.x * drawAngleDir.y + c.y * drawAngleDir.x);
	vec4 worldpos = vec4(pos + spritePosOffset, 1.);

	vec3 ex, ey, ez;
	if ((flags & SPRITEFLAG_DISABLE_BILLBOARD) != 0) {
		// same question as drawAngleDir above ...
		vec2 angleDir = vec2(cos(angle), sin(angle));
		ex = vec3(angleDir.x, angleDir.y, 0.);
		ey = vec3(-angleDir.y, angleDir.x, 0.);
		ez = vec3(0., 0., 1.);
	} else {
		ex = vec3(viewMat[0].x, viewMat[1].x, viewMat[2].x);
		ez = vec3(viewMat[0].z, viewMat[1].z, viewMat[2].z);
#if 1	//use view matrix
		ey = vec3(viewMat[0].y, viewMat[1].y, viewMat[2].y);
#else	//make sure up is world z+ aligned
		// this still only looks good at near-horizontal views, when we might as well use the first case.
		ey = vec3(0., 0., 1.);
		ex = normalize(cross(ey, ez));
		ez = normalize(cross(ex, ey));
#endif
	}
	worldpos.xyz += ex * c.x;
	worldpos.xyz += ey * c.y;
	worldpos.xyz += ez * c.z;

	vec4 viewPos = viewMat * worldpos;

	viewPosv = viewPos.xyz;

	gl_Position = projMat * viewPos;
}
]],
		fragmentCode = [[
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
		// flatten the cone = no clipping near the player
		if (viewPosv.z > playerViewPos.z
			// + .4 // hmm at what distance should I occlude sprites?
		) {
			vec3 testViewPos = playerViewPos + vec3(0., 1., -2.);
			if (normalize(viewPosv - testViewPos).z > cosClipAngle) {
				//fragColor.w = .2;
				discard;
			}
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
glreport'here'


	-- NOTICE these have a big perf hit when resizing ...
	local vector = require 'ffi.cpp.vector-lua'
	self.spritesBufCPU = vector'sprite_t'
	self.spritesBufCPU:reserve(60000)	-- TODO error on growing, like the map vectors, and TODO better vector<->GLArrayBuffer coupling + growing of GL buffers
	self.spritesBufGPU = GLArrayBuffer{
		size = ffi.sizeof'sprite_t' * self.spritesBufCPU.capacity,
		data = self.spritesBufCPU.v,
		usage = gl.GL_DYNAMIC_DRAW,
	}:unbind()
glreport'here'

	--[[ hmm no resizing for now
	-- TODO new system, this won't affect the class (and shouldn't since luajit ffi says don't touch cdata metatables...)
	self.spritesBufCPU.reserve = function(self, newcap)
		if newcap <= self.capacity then return end
		print('asked for resize to', newcap, 'when our cap was', self.capacity)
		error'here'
	end
	--]]

	self.spriteSceneObj = GLSceneObject{
		geometry = {
			mode = gl.GL_TRIANGLE_STRIP,
			count = 0,
		},
		program = self.spriteShader,
		-- TODO can I just copy the spriteShader.attrs and insert the buffer and offset?
		attrs = {
			vertex = self.quadVertexBuf,
			flags = {
				divisor = 1,
				size = 1,
				-- https://stackoverflow.com/a/67653318/2714073
				-- so looks like I need to add behavior to gl/attribute.lua to pick the right setter of glVertexAttrib*Pointer
				type = gl.GL_UNSIGNED_BYTE,
				--type = gl.GL_INT,
				--type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'flags'),
				buffer = self.spritesBufGPU,
			},
			atlasTcPos = {
				divisor = 1,
				size = 2,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'atlasTcPos'),
				buffer = self.spritesBufGPU,
			},
			atlasTcSize = {
				divisor = 1,
				size = 2,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'atlasTcSize'),
				buffer = self.spritesBufGPU,
			},
			drawCenter = {
				divisor = 1,
				size = 3,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'drawCenter'),
				buffer = self.spritesBufGPU,
			},
			drawSize = {
				divisor = 1,
				size = 2,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'drawSize'),
				buffer = self.spritesBufGPU,
			},
			drawAngle = {
				divisor = 1,
				size = 1,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'drawAngle'),
				buffer = self.spritesBufGPU,
			},
			angle = {
				divisor = 1,
				size = 1,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'angle'),
				buffer = self.spritesBufGPU,
			},
			pos = {
				divisor = 1,
				size = 3,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'pos'),
				buffer = self.spritesBufGPU,
			},
			spritePosOffset = {
				divisor = 1,
				size = 3,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'spritePosOffset'),
				buffer = self.spritesBufGPU,
			},
			-- TODO use mat4
			colorMatrixR = {
				divisor = 1,
				size = 4,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'colorMatrix'),
				buffer = self.spritesBufGPU,
			},
			colorMatrixG = {
				divisor = 1,
				size = 4,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'colorMatrix') + ffi.sizeof'float' * 4,
				buffer = self.spritesBufGPU,
			},
			colorMatrixB = {
				divisor = 1,
				size = 4,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'colorMatrix') + ffi.sizeof'float' * 8,
				buffer = self.spritesBufGPU,
			},
			colorMatrixA = {
				divisor = 1,
				size = 4,
				type = gl.GL_FLOAT,
				normalize = false,
				stride = ffi.sizeof'sprite_t',
				offset = ffi.offsetof('sprite_t', 'colorMatrix') + ffi.sizeof'float' * 12,
				buffer = self.spritesBufGPU,
			},
		},
		texs = {},
	}
glreport'here'

	self.meshShader = require 'mesh':makeShader()

	self.swordShader = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
in vec3 vertex;
in vec4 color;
out vec4 colorv;
uniform mat4 mvProjMat;
void main() {
	colorv = color;
	gl_Position = mvProjMat * vec4(vertex, 1.);
}
]],
		fragmentCode = [[
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
	local Chunk = require 'farmgame.map'.Chunk
	self.mapShader = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
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
		fragmentCode = sampler3Dprec..[[
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

//lighting on gpu
uniform sampler3D lumTex;

// map view clipping
uniform bool useSeeThru;
uniform vec3 playerViewPos;

//lol, C standard is 'const' associates left
//but GLSL requires it to associate right
const float cosClipAngle = .9;	// = cone with 25 degree from axis

void main() {
	vec3 chunkCoord = worldPosv.xyz / chunkSize.xyz;
	vec4 lumColor = texture(lumTex, chunkCoord);

	fragColor = texture(tex, texcoordv);
	//lumTex 'x' is the emissivity, 'y' is the luminance
	fragColor.xyz *= colorv.xyz * lumColor.y;

	// technically I should also subtract the chunkPos
	// but texcoords are fractional part, so the integer part is thrown away anyways ...
	vec2 sunTc = chunkCoord.xy;
	vec2 sunAngles = texture(sunAngleTex, sunTc).xy;
	const float sunWidthInRadians = .1;
	const float ambient = .5;
	float sunlight = mix(
		smoothstep(sunAngles.x - sunWidthInRadians, sunAngles.x + sunWidthInRadians, sunAngle)
		- smoothstep(sunAngles.y - sunWidthInRadians, sunAngles.y + sunWidthInRadians, sunAngle),
		1.,
		ambient);
	fragColor.xyz *= sunlight;

	// keep the dx dy outside the if block to prevent errors.
	if (useSeeThru) {
		vec3 dx = dFdx(viewPosv);
		vec3 dy = dFdy(viewPosv);
		vec3 testViewPos = playerViewPos;
			// this is the sprite playerViewPos offset
			// but I don't think it looks as good in the map
			// you get some big ellipses of clipped region above the view
			// + vec3(0., 1., -2.);
		if (normalize(viewPosv - testViewPos).z > cosClipAngle) {
			vec3 n = normalize(cross(dx, dy));
			if (dot(n, testViewPos - viewPosv) < -.01)
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
			lumTex = 2,
			chunkSize = {Chunk.size:unpack()},
		},
	}:useNone()

	--[[
	TODO also
	- make a surfaceTex.  store lumAlt, minAngle, maxAngle - normalized. (don't need solidAngle I think...)
	- for any tile over lumAlt, immediately light it via minAngle, maxAngle, and sunAngle

	- in lumTex, also store if a voxel is blocking-light
	- then when doing flood-fill, don't propagate if we're blocking light

	- in updateMeshAndLight we will have to also update the lumTex's blocking-light flag ...

	--]]
	self.lumUpdateShader = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
in vec2 vertex;
out vec3 tc;
uniform float sliceZ;
void main() {
	tc = vec3(
		(vertex.xy * 31. + .5)/32.,	//TODO necessary?  change the texwrap instead?
		sliceZ);
	gl_Position = vec4(2. * vertex.xy - 1., 0., 1.);
}
]],
		fragmentCode = sampler3Dprec
..[[
in vec3 tc;
out vec4 fragColor;
uniform sampler2D randTex;
uniform sampler3D lumTex;
#if 0
uniform sampler3D lumTexXL;
uniform sampler3D lumTexYL;
uniform sampler3D lumTexZL;
uniform sampler3D lumTexXR;
uniform sampler3D lumTexYR;
uniform sampler3D lumTexZR;
#endif
//uniform vec2 moduloVec;
void main() {
	fragColor = texture(lumTex, tc);
	const vec3 dx = vec3(1./32., 0., 0.);	// 32 = chunk size in xyz
	//.x = emissivity (light source value)
	//.y = luminance (current light state)
	//.z = diminish (change in light wrt neighbors)
	fragColor.y = max(
		max(
			max(
				fragColor.x,	// source
				fragColor.y
			),
			max(
				texture(lumTex, tc + dx.xyz).y,
				texture(lumTex, tc - dx.xyz).y
			)
		),
		max(
			max(
				texture(lumTex, tc + dx.zxy).y,
				texture(lumTex, tc - dx.zxy).y
			),
			max(
				texture(lumTex, tc + dx.yzx).y,
				texture(lumTex, tc - dx.yzx).y
			)
		)
	) - .1;	//TODO decrement based on the distance of what we picked as the max
			//TODO don't pick from light-blocking tiles (upload light-blocking flag into the lumTex as well)
	fragColor.w = 1.;
}
]],
		uniforms = {
			randTex = 0,
			lumTex = 1,
			lumTexXL = 2,
			lumTexYL = 3,
			lumTexZL = 4,
			lumTexXR = 5,
			lumTexYR = 6,
			lumTexZR = 7,
		},
	}:useNone()

	local randSize = 4 * Chunk.size.x * Chunk.size.y
	local randData = ffi.new('uint8_t[?]', randSize)
	for i=0,randSize-1 do
		randData[i] = math.random(0,255)
	end
	self.randTex = GLTex2D{
		width = Chunk.size.x,
		height = Chunk.size.y,
		format = gl.GL_RGBA,
		internalFormat = gl.GL_RGBA,
		type = gl.GL_UNSIGNED_BYTE,
		data = randData,
		minFilter = gl.GL_NEAREST,
		magFilter = gl.GL_NEAREST,
	}:unbind()

	-- temp buffer for writing into
	-- make this just like the lumTex in Chunk
	self.lumTmpTex = GLTex3D{
		width = Chunk.size.x,
		height = Chunk.size.y,
		depth = Chunk.size.z,
		internalFormat = gl.GL_RGBA,
		format = gl.GL_RGBA,
		type = gl.GL_UNSIGNED_BYTE,
		data = lumData,
		magFilter = gl.GL_NEAREST,
		minFilter = gl.GL_NEAREST,
	}:unbind()

	self.lumUpdateObj = GLSceneObject{
		geometry = self.quadGeom,
		program = self.lumUpdateShader,
		attrs = {
			vertex = self.quadVertexBuf,
		},
	}


	local GLFramebuffer = require 'gl.framebuffer'
	local Chunk = require 'farmgame.map'.Chunk
	self.lumFBO = GLFramebuffer{
		width = Chunk.size.x,
		height = Chunk.size.y,
	}:unbind()

	--[[
	TODO:
		dynamic resizing GL buffers
	like std::vector but for GL
	in fact, why not build it into thel GLBuffer class?
	--]]

	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glEnable(gl.GL_CULL_FACE)

	self:resetGame(true)

	self.lastTime = getTime()
	self.updateTime = 0
end

-- called by menu.NewGame
function App:resetGame(dontMakeGame)
	-- makes self.players
	App.super.resetGame(self)

	-- in degrees
	self.targetViewYaw = 0
	self.viewYaw = 0
	self.viewPitch = math.rad(45)

	if not dontMakeGame then
		self.game = Game{app = self}

		-- find the next available save dir name
		self.saveBaseDir:mkdir(true)
		for i=1,math.huge do
			local dirname = tostring(i)
			local thissave = self.saveBaseDir/dirname
			if not thissave:exists() then
				--thissave:mkdir()
				self.game.saveDir = dirname
				-- TODO initial save?
				break
			end
		end
--DEBUG:print('App:resetGame', self.game.saveDir)
	end
end

App.updateDelta = 1/30

App.needsResortSprites = true
function App:updateGame()
	local game = self.game

	local sysThisTime = getTime()
	local sysDeltaTime = sysThisTime - self.lastTime

	self.view.angle = quatd():fromAngleAxis(0, 0, 1, math.deg(self.viewYaw))
					* quatd():fromAngleAxis(1, 0, 0, math.deg(self.viewPitch))
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
--DEBUG:print('updating sprite z order')
		local v = self.view.angle:zAxis()
--DEBUG:print('dir', v)
		game.objs:sort(function(a,b)
			return a.pos:dot(v) < b.pos:dot(v)
		end)
	end
--]]

	-- TODO frameskip
	if game then game:draw() end

	gl.glDisable(gl.GL_BLEND)

	-- fixed-framerate update
	self.updateTime = self.updateTime + sysDeltaTime
	local needsUpdate
	while self.updateTime >= self.updateDelta do
		self.updateTime = self.updateTime - self.updateDelta
		-- don't allow frameskip <-> if theres a lag in updating then still only update once
		needsUpdate = true
	end
	if game
	and not self.paused
	and needsUpdate then
		game:update(self.updateDelta)

		-- only update if the game is running <-> fixed framerate
		self.lastViewYaw = self.viewYaw
		local dyaw = .3 * (self.targetViewYaw - self.viewYaw)
		if math.abs(dyaw) > .001 then
			self.viewYaw = self.viewYaw + dyaw
		else
			-- TODO this might fix some flickering, but there still is some more
			-- probably due to player vel being nonzero
			-- so TODO the same trick with player vel ?  only update camera follow target if it moves past some epsilon?
			self.targetViewYaw = self.targetViewYaw % (2 * math.pi)
			self.viewYaw = self.targetViewYaw
		end
	end

	self.lastTime = sysThisTime
end

App.editorVoxelTypeIndex = 0
function App:event(event)
	App.super.event(self, event)

-- [[ mouse rotate support?
	local canHandleMouse = not ig.igGetIO()[0].WantCaptureMouse
	if event[0].type == sdl.SDL_EVENT_MOUSE_MOTION then
		if canHandleMouse
		and bit.band(event[0].motion.state, 1) == 1
		then
			local dx = event[0].motion.xrel
			self.viewYaw = self.viewYaw + math.rad(dx)
			self.view.angle = quatd():fromAngleAxis(0, 0, 1, math.deg(self.viewYaw))
							* quatd():fromAngleAxis(1,0,0,30)
			self.view.pos = self.view.angle:zAxis() * (self.view.pos - self.view.orbit):length() + self.view.orbit
		end
	elseif event[0].type == sdl.SDL_EVENT_KEY_DOWN then
		if event[0].key.key == ('`'):byte() then
			self.playingMenu.consoleOpen = not self.playingMenu.consoleOpen
		end
	end
--]]

	if event.type == sdl.SDL_EVENT_MOUSE_MOTION then
		local mouse = self.mouse
		-- unproject mouse
		local mx = math.floor(mouse.pos.x * self.width)
		local my = math.floor(mouse.pos.y * self.height)
		local depthValuePtr = ffi.new('GLfloat[1]')
		gl.glReadBuffer(gl.GL_BACK)
		gl.glReadPixels(mx, my, 1, 1, gl.GL_DEPTH_COMPONENT, gl.GL_FLOAT, depthValuePtr)
		local pix = depthValuePtr[0]
		if pix ~= 1 then -- full depth means a cleared-depth value, means nothing was here
			self.mvProjInvMat:inv4x4(self.view.mvProjMat)
			local projX, projY, projZ, projW = self.mvProjInvMat:mul4x4v4(
				mouse.pos.x * 2 - 1,
				mouse.pos.y * 2 - 1,
				pix * 2 - 1,
				1)
			self.mousePos3D = vec3f(projX, projY, projZ) / projW

			local eyeX, eyeY, eyeZ, eyeW = self.mvProjInvMat:mul4x4v4(0, 0, -1, 1)
			local eye = vec3f(eyeX, eyeY, eyeZ) / eyeW
			self.mouseDir3D = (self.mousePos3D - eye):normalize()

			-- TODO offset by normal? or by view self.mouseDir3D?
			print('mouse over', self.mousePos3D, 'dir', self.mouseDir3D)
		end
	end
	--[[ TODO
	mouse click
	place voxel
	but what about plants and other object?
	need separate editor mode
	one for selecting objects
	one for placing voxels
	--]]
	if event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN then
		local map = require 'ext.op'.safeindex(self, 'players', 1, 'obj', 'map')
		if map then
			local Voxel = require 'farmgame.voxel'
			local voxelType = Voxel.types[self.editorVoxelTypeIndex]

			-- only push forward by 0.1 if we are writing empty / deleting
			-- if we are writing solid then push back by 0.1
			local i,j,k = (self.mousePos3D + (self.editorVoxelTypeIndex ~= 0 and -.02 or .02) * self.mouseDir3D):unpack()
			i, j, k = math.floor(i), math.floor(j), math.floor(k)
			local voxel = map:getTile(i,j,k)
			if not voxel then
				print('nothing there')
			end
			if voxel then
				print('setting map at', i, j, k)
				voxel.type = voxelType.index
				voxel.tex = math.random(#voxelType.texrects)-1
				map:updateMeshAndLight(i, j, k)	-- and either side of dz?
			end
		end
	end
	if event.type == sdl.SDL_EVENT_KEY_DOWN then
		local Voxel = require 'farmgame.voxel'
		if event.key.key == sdl.SDLK_LEFTBRACKET then
			self.editorVoxelTypeIndex = self.editorVoxelTypeIndex - 1
			self.editorVoxelTypeIndex = self.editorVoxelTypeIndex % #Voxel.types
		elseif event.key.key == sdl.SDLK_RIGHTBRACKET then
			self.editorVoxelTypeIndex = self.editorVoxelTypeIndex + 1
			self.editorVoxelTypeIndex = self.editorVoxelTypeIndex % #Voxel.types
		end
	end

	if self.game then
		self.game:event(event[0])
	end
end

function App:saveGame(folder)
	local game = assert.index(self, 'game')
	folder:mkdir(true)
	assert(folder:isdir(), "mkdir failed")
	local gamesavedata = tolua({
		nextObjUID = game.nextObjUID,
	}, {
		serializeForType = {
			cdata = function(state, x, ...)
				return tostring(x)
			end,
		},
	})
	local gamepath = folder/'game.lua'
	gamepath:write(gamesavedata)
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
