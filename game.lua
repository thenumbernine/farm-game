local ffi = require 'ffi'
local sdl = require 'ffi.req' 'sdl'
local class = require 'ext.class'
local table = require 'ext.table'
local Map = require 'zelda.map'
local Tile = require 'zelda.tile'
local gl = require 'gl'
local GLTex2D = require 'gl.tex2d'
local GLProgram = require 'gl.program'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLGeometry = require 'gl.geometry'
local GLSceneObject = require 'gl.sceneobject'
local vec2f = require 'vec-ffi.vec2f'
local vec3i = require 'vec-ffi.vec3i'
local vec3f = require 'vec-ffi.vec3f'
local vec4f = require 'vec-ffi.vec4f'
local Obj = require 'zelda.obj.obj'
local ThreadManager = require 'threadmanager'

-- put this somewhere as to not give it a require loop
assert(not Obj.classes)
Obj.classes = require 'zelda.obj.all'

local function hexcolor(i)
	return
		bit.band(0xff, bit.rshift(i,16))/255,
		bit.band(0xff, bit.rshift(i,8))/255,
		bit.band(0xff, i)/255,
		1
end

local Game = class()

-- 16 x 16 = 256 tiles in a typical screen
-- 8 x 8 x 8 = 512 tiles
function Game:init(args)
	self.app = assert(args.app)
	local app = self.app

	self.time = 0
	self.threads = ThreadManager()


	self.quadVtxBufCPU = ffi.new('vec2f_t[4]', {
		vec2f(0,0),
		vec2f(1,0),
		vec2f(0,1),
		vec2f(1,1),
	})
	self.quadVtxBuf = GLArrayBuffer{
		size = ffi.sizeof(self.quadVtxBufCPU),
		data = self.quadVtxBufCPU,
	}:unbind()

	self.quadGeom = GLGeometry{
		mode = gl.GL_TRIANGLE_STRIP,
		count = 4,
	}


	self.skyColorBufCPU = ffi.new('vec4f_t[4]', {
		vec4f(hexcolor(0xda9134)),
		vec4f(hexcolor(0xda9134)),
		vec4f(hexcolor(0x313453)),
		vec4f(hexcolor(0x313453)),
	})
	self.skyColorBuf = GLArrayBuffer{
		size = ffi.sizeof(self.skyColorBufCPU),
		data = self.skyColorBufCPU,
	}:unbind()

	self.skyShader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec2 vertex;
in vec4 color;
out vec4 colorv;
uniform mat4 mvProjMat;
void main() {
	colorv = color;
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
}
]],
		fragmentCode = app.glslHeader..[[
in vec4 colorv;
out vec4 fragColor;
void main() {
	fragColor = colorv;
}
]],
	}:useNone()

	self.swordShader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec3 vertex;
in vec4 color;
out vec4 colorv;
uniform mat4 mvProjMat;
void main() {
	colorv = color;
	gl_Position = mvProjMat * vec4(vertex, 1.);
}
]],
		fragmentCode = app.glslHeader..[[
in vec4 colorv;
out vec4 fragColor;
void main() {
	fragColor = colorv;
}
]],
	}:useNone()


	self.skySceneObj = GLSceneObject{
		geometry = self.quadGeom,
		program = self.skyShader,
		attrs = {
			vertex = self.quadVtxBuf,
			color = self.skyColorBuf,
		}
	}

	self.spriteShader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec2 vertex;
out vec2 texcoordv;
out vec3 posv;

uniform vec2 uvscale;
uniform vec2 drawCenter;
uniform vec2 drawSize;
uniform vec3 pos;

uniform mat4 viewMat;
uniform mat4 projMat;

void main() {
	vec4 worldpos = vec4(pos, 1.);
	worldpos.xyz += vec3(viewMat[0].x, viewMat[1].x, viewMat[2].x) * (drawCenter.x - vertex.x) * drawSize.x;
	worldpos.xyz += vec3(viewMat[0].y, viewMat[1].y, viewMat[2].y) * (drawCenter.y - vertex.y) * drawSize.y;
	worldpos = viewMat * worldpos;
	
	posv = worldpos.xyz;

	texcoordv = (vertex - .5) * uvscale + .5;

	gl_Position = projMat * worldpos;
}
]],
		fragmentCode = app.glslHeader..[[
in vec2 texcoordv;
in vec3 posv;

out vec4 fragColor;

uniform sampler2D tex;
uniform vec4 color;

uniform vec4 viewport;
uniform vec4 playerViewPos;

// gl_FragCoord is in pixel coordinates with origin at lower-left
void main() {
	fragColor = color * texture(tex, texcoordv);

	// alpha-testing
	if (fragColor.a < .1) discard;

	// keep the dx dy outside the if block to prevent errors.
	//vec3 dx = dFdx(posv);
	//vec3 dy = dFdy(posv);
	if (length(
			gl_FragCoord.xy - .5 * viewport.zw
		) < .35 * viewport.w
	) {
		//vec3 n = normalize(cross(dx, dy));
		//if (dot(n, playerPos - posv) < -.01) 
		
		//if (gl_FragCoord.z / gl_FragCoord.w < playerClipPos.z / playerClipPos.w)
		//if (gl_FragCoord.z < playerClipPos.z)
		//if (gl_FragCoord.w < playerClipPos.w)
		
		if (posv.z > playerViewPos.z + 1.)
		{
			fragColor.w = .5;
			//discard;
		}
	}
}
]],
		uniforms = {
			tex = 0,
			drawCenter = {.5, 1},
			viewport = {0,0,1,1},
		},
	}:useNone()

	self.spriteSceneObj = GLSceneObject{
		geometry = self.quadGeom,
		program = self.spriteShader,
		attrs = {
			vertex = self.quadVtxBuf,
		},
		texs = {},
	}

	self.meshShader = require 'mesh':makeShader{
		glslHeader = app.glslHeader,
	}

	self.texpack = GLTex2D{
		filename = 'texpack.png',
		magFilter = gl.GL_LINEAR,
		minFilter = gl.GL_NEAREST,
	}
	self.map = Map{
		game = self,
		size = vec3i(96, 64, 32),
	}

	self.objs = table()
	self.player = self:newObj{
		class = Obj.classes.Player,
		pos = vec3f(
			self.map.size.x*.5,
			self.map.size.y*.5,
			self.map.size.z-.5),
	}

	self:newObj{
		class = Obj.classes.NPC,
		pos = vec3f(
			self.map.size.x*.95,
			self.map.size.y*.5,
			self.map.size.z-.5),
	}

	for j=0,self.map.size.y-1 do
		for i=0,self.map.size.x-1 do
			local k = self.map.size.z-1
			while k >= 0 do
				local tile = self.map:getTile(i,j,k)
				if tile.type ~= Tile.typeValues.Empty
				and tile.tex == 0	-- grass tex
				then
					break
				end
				k = k - 1
			end
			if k >= 0 then
				if math.random() < .2 then
					local anim = require 'zelda.anim'
					local sprite = table{
						'tree1',
						'tree2',
						'bush1',
						'bush2',
						'bush3',
						'plant1',
						'plant2',
						'plant3',
					}:pickRandom()
					local tex = anim[sprite].stand[1].tex
					self:newObj{
						class = require 'zelda.obj.plant',
						sprite = sprite,
						drawSize = vec2f(tex.width, tex.height) / 16,
						pos = vec3f(i + .5, j + .5, k + 1),
					}
				end
			end
		end
	end

-- [[
	for k=1,5 do
		local i = math.random(tonumber(self.map.size.x))-1
		local j = math.random(tonumber(self.map.size.y))-1
		for _,dir in ipairs{{1,0},{0,1},{-1,0},{0,-1}} do
			local ux, uy = table.unpack(dir)
			local g = self:newObj{
				class = Obj.classes.Goomba,
				pos = vec3f(ux + i, uy + j, self.map.size.z-1),
			}
		end
	end
--]]
end

function Game:newObj(args)
print('new', args.class.name, 'at', args.pos)
	local cl = assert(args.class)
	args.game = self
	local obj = cl(args)
	self.objs:insert(obj)
	return obj
end

function Game:draw()
	local app = self.app
	local view = app.view

	local viewFollow = self.player
	--local viewFollow = self.goomba

	-- before calling super.update and redoing the gl matrices, update view...
	--self.view.angle:fromAngleAxis(1,0,0,20)
	view.pos:set((viewFollow.pos + view.angle:zAxis() * app.viewDist):unpack())

	view:setup(app.width / app.height)
	--app.orbit.pos:set((app.view.angle:zAxis() * app.viewDist):unpack())

-- [[ sky
	do
		GLTex2D:unbind()
		gl.glDisable(gl.GL_DEPTH_TEST)


		view.mvProjMat:setOrtho(0,1,0,1,-1,1)

		self.skySceneObj.uniforms.mvProjMat = view.mvProjMat.ptr
		self.skySceneObj:draw()

		gl.glEnable(gl.GL_DEPTH_TEST)

		view.mvProjMat:mul4x4(view.projMat, view.mvMat)
	end
--]]


	do
		-- [[ clip by fragcoord
		-- clip pos
		local x,y,z,w = view.mvMat:mul4x4v4(
			viewFollow.pos.x,
			viewFollow.pos.y,
			viewFollow.pos.z + .1)
		self.playerViewPos = vec4f(x,y,z,w)
		local x,y,z,w = view.mvProjMat:mul4x4v4(
			viewFollow.pos.x,
			viewFollow.pos.y,
			viewFollow.pos.z + .1)
		local normalizedDeviceCoordDepth = z / w
		local dnear = 0
		local dfar = 1
		local windowZ = normalizedDeviceCoordDepth * (dfar - dnear)*.5 + (dfar + dnear)*.5
		-- clip by depth ...
		self.playerClipPos = vec4f(x,y,z,w)
		--]]
		-- [[
		-- and clip by world z ...
		self.playerPos = vec3f(viewFollow.pos:unpack()) + .1
		--]]
	end

	self.map:draw()

	for _,obj in ipairs(self.objs) do
		obj:draw()
	end
end

function Game:update(dt)
	for _,obj in ipairs(self.objs) do
		if obj.update then obj:update(dt) end
	end

	-- now threads
	self.threads:update()

	-- only after update do the removals
	for i=#self.objs,1,-1 do
		if self.objs[i].removeFlag then
			table.remove(self.objs, i)
		end
	end

	self.time = self.time + dt
end

-- TODO only call this from a
function Game:sleep(seconds)
	assert(coroutine.isyieldable(coroutine.running()))
	local endTime = self.time + seconds
	while self.time < endTime do
		coroutine.yield()
	end
end

function Game:fade(seconds, callback)
	assert(coroutine.isyieldable(coroutine.running()))
	local startTime = self.time
	local endTime = startTime + seconds
	while self.time < endTime do
		local alpha = (self.time - startTime) / (endTime - startTime)
		callback(alpha)
		coroutine.yield()
	end
end

function Game:event(event)
	if event.type == sdl.SDL_KEYDOWN
	or event.type == sdl.SDL_KEYUP
	then
		local down = event.type == sdl.SDL_KEYDOWN
		if event.key.keysym.sym == sdl.SDLK_UP then
			self.player.keyPress.up = down
		elseif event.key.keysym.sym == sdl.SDLK_DOWN then
			self.player.keyPress.down = down
		elseif event.key.keysym.sym == sdl.SDLK_LEFT then
			self.player.keyPress.left = down
		elseif event.key.keysym.sym == sdl.SDLK_RIGHT then
			self.player.keyPress.right = down

		--[[
		keyPress.s:
			- jump
			- use item (sword, hoe, watering can, etc)
			- pick up
				... (I could combine this with 'use' and make it mandatory to select to an empty inventory slot ...)
				... or I could get rid of this and have objects change to a touch-to-pick-up state like they do in minecraft and stardew valley
			- talk/interact
				... this could be same as pick-up, but for NPCs ...
		--]]
		elseif event.key.keysym.sym == ('x'):byte() then
			self.player.keyPress.jump = down
		elseif event.key.keysym.sym == ('z'):byte() then
			self.player.keyPress.useItem = down
		elseif event.key.keysym.sym == ('c'):byte() then
			self.player.keyPress.interact = down

		elseif event.key.keysym.sym == ('a'):byte() then
			self.player.keyPress.rotateLeft = down
		elseif event.key.keysym.sym == ('s'):byte() then
			self.player.keyPress.rotateRight = down

		-- reset
		elseif event.key.keysym.sym == ('r'):byte() then
			self.app.game = Game{app=self.app}
		end

		if down then
			if event.key.keysym.sym >= ('1'):byte()
			and event.key.keysym.sym <= ('9'):byte()
			then
				self.player.selectedItem = event.key.keysym.sym - ('1'):byte() + 1
			elseif event.key.keysym.sym == ('0'):byte() then
				self.player.selectedItem = 10
			elseif event.key.keysym.sym == ('-'):byte() then
				self.player.selectedItem = 11
			elseif event.key.keysym.sym == ('='):byte() then
				self.player.selectedItem = 12
			end
		end
	end
end

local ig = require 'imgui'
function Game:updateGUI()
	local player = self.player
	local app = self.app
	local maxItems = 12
	local bw = math.floor(app.width / maxItems)
	local bh = bw
	local x = 0
	local y = app.height - bh - 4
	ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ButtonTextAlign, ig.ImVec2(.5, .5))

	for i=1,maxItems do
		local item = player.items[i]

		local selected = player.selectedItem == i
		if selected then
			local selectColor = ig.ImVec4(0,0,1,.5)
			ig.igPushStyleColor_Vec4(ig.ImGuiCol_Button, selectColor)
		end

		ig.igSetNextWindowPos(ig.ImVec2(x,y), 0, ig.ImVec2())
		ig.igSetNextWindowSize(ig.ImVec2(bw, bh), 0)
		ig.igBegin('inventory '..i, nil, bit.bor(
			ig.ImGuiWindowFlags_NoTitleBar,
			ig.ImGuiWindowFlags_NoResize,
			ig.ImGuiWindowFlags_NoScrollbar,
			ig.ImGuiWindowFlags_NoCollapse,

			ig.ImGuiWindowFlags_NoBackground,
			ig.ImGuiWindowFlags_Tooltip
		))
		--[[
		if selected then
			ig.igPushStyleVar_Float(ig.ImGuiStyleVar_FrameBorderSize, 1)
		end
		--]]
		local name = '###'..i
		if item then name = item.name..name end
		ig.igButton(name, ig.ImVec2(bw,bh))
		--[[
		if selected then
			ig.igPopStyleVar(1)
		end
		--]]
		ig.igEnd()

		if selected then
			ig.igPopStyleColor(1)
		end

		x = x + bw
	end

	ig.igPopStyleVar(1)
end

return Game
