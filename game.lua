local sdl = require 'ffi.req' 'sdl'
local class = require 'ext.class'
local table = require 'ext.table'
local Map = require 'zelda.map'
local gl = require 'gl'
local GLTex2D = require 'gl.tex2d'
local GLProgram = require 'gl.program'
local vec3i = require 'vec-ffi.vec3i'
local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'
local ThreadManager = require 'threadmanager'

-- put this somewhere as to not give it a require loop
assert(not Obj.classes)
Obj.classes = require 'zelda.obj.all'


local Game = class()

-- 16 x 16 = 256 tiles in a typical screen
-- 8 x 8 x 8 = 512 tiles
function Game:init(args)
	self.app = assert(args.app)

	self.time = 0
	self.threads = ThreadManager()

	self.skyShader = GLProgram{
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
	}

	self.spriteShader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec3 vertex;
in vec2 texcoord;
in vec4 color;

out vec2 texcoordv;
out vec4 colorv;

uniform mat4 mvProjMat;

void main() {
	texcoordv = texcoord;
	colorv = color;
	gl_Position = mvProjMat * vec4(vertex, 1.);
}
]],
		fragmentCode = app.glslHeader..[[
in vec2 texcoordv;
in vec4 colorv;

out vec4 fragColor;

uniform sampler2D tex;

float lenSq(vec2 v) {
	return dot(v,v);
}

// gl_FragCoord is in pixel coordinates with origin at lower-left
void main() {
	fragColor = colorv * texture(tex, texcoordv);
}
]],
		uniforms = {
			tex = 0,
		},
	}

	self.texpack = GLTex2D{
		filename = 'texpack.png',
		magFilter = gl.GL_LINEAR,
		minFilter = gl.GL_NEAREST,
	}
	self.map = Map{
		app = self.app,
		size = vec3i(32, 32, 32),
	}

	self.objs = table()
	self.player = self:newObj{
		class = Obj.classes.Player,
		pos = vec3f(
			self.map.size.x*.5,
			self.map.size.y*.5,
			self.map.size.z-.5),
	}

-- [[	
	for _,dir in ipairs{{1,0},{0,1},{-1,0},{0,-1}} do
		local ux, uy = table.unpack(dir)
		local vx, vy = -uy, ux
		for i=5,7,2 do
			for j=5,7,2 do
				local g = self:newObj{
					class = Obj.classes.Goomba,
					pos = vec3f(ux * i + vx * j + 8.5, uy * i + vy * j + 8.5, self.map.size.z),
				}
			end
		end
	end
--]]
end

function Game:newObj(args)
	local cl = assert(args.class)
	args.game = self
	local obj = cl(args)
	self.objs:insert(obj)
	return obj
end

local function hexcolor(i)
	return
		bit.band(0xff, bit.rshift(i,16))/255,
		bit.band(0xff, bit.rshift(i,8))/255,
		bit.band(0xff, i)/255
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
		local shader = self.skyShader
		shader:use()

		view.mvProjMat:setOrtho(0,1,0,1,-1,1)
		gl.glUniformMatrix4fv(shader.uniforms.mvProjMat.loc, 1, gl.GL_FALSE, view.mvProjMat.ptr)

		gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		gl.glDisable(gl.GL_DEPTH_TEST)
		gl.glBegin(gl.GL_TRIANGLE_STRIP)
		gl.glVertexAttrib3f(shader.attrs.color.loc, hexcolor(0xda9134))	gl.glVertex2f(0,0)
		gl.glVertexAttrib3f(shader.attrs.color.loc, hexcolor(0xda9134))	gl.glVertex2f(1,0)
		gl.glVertexAttrib3f(shader.attrs.color.loc, hexcolor(0x313453))	gl.glVertex2f(0,1)
		gl.glVertexAttrib3f(shader.attrs.color.loc, hexcolor(0x313453))	gl.glVertex2f(1,1)
		gl.glEnd()
		gl.glEnable(gl.GL_DEPTH_TEST)
		
		shader:useNone()
		view.mvProjMat:mul4x4(view.projMat, view.mvMat)
	end
--]]

	do
		-- [[ clip by fragcoord
		-- clip pos
		local x,y,z,w = view.mvProjMat:mul4x4v4(
			viewFollow.pos.x,
			viewFollow.pos.y,
			viewFollow.pos.z + .1)
		local normalizedDeviceCoordDepth = z / w
		local dnear = 0
		local dfar = 1
		local windowZ = normalizedDeviceCoordDepth * (dfar - dnear)*.5 + (dfar + dnear)*.5
		-- clip by depth ...
		self.playerClipZ = windowZ
		--]]
		-- [[
		-- and clip by world z ...
		self.playerPosZ = viewFollow.pos.z + .1
		--]]
	end

	self.map:draw()

	local shader = self.spriteShader
	shader:use()
	gl.glUniformMatrix4fv(shader.uniforms.mvProjMat.loc, 1, gl.GL_FALSE, view.mvProjMat.ptr)
	for _,obj in ipairs(self.objs) do
		obj:draw(shader)
	end
	shader:useNone()
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

function Game:onEvent(event)
	if event.type == sdl.SDL_KEYDOWN 
	or event.type == sdl.SDL_KEYUP 
	then
		local down = event.type == sdl.SDL_KEYDOWN 
		if event.key.keysym.sym == sdl.SDLK_UP then
			self.player.buttonUp = down
		elseif event.key.keysym.sym == sdl.SDLK_DOWN then
			self.player.buttonDown = down
		elseif event.key.keysym.sym == sdl.SDLK_LEFT then
			self.player.buttonLeft = down
		elseif event.key.keysym.sym == sdl.SDLK_RIGHT then
			self.player.buttonRight = down
		elseif event.key.keysym.sym == sdl.SDLK_x then
			self.player.buttonUse = down
		elseif event.key.keysym.sym == sdl.SDLK_z then
			self.player.buttonAttack = down
		-- reset
		elseif event.key.keysym.sym == sdl.SDLK_r then
			self:init()
		
		elseif event.key.keysym.sym >= ('1'):byte()
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

local ig = require 'imgui'
function Game:updateGUI()
	local app = self.app
	local maxItems = 12
	local bw = math.floor(app.width / maxItems)
	local bh = bw
	local x = 0
	local y = app.height - bh - 4
	ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ButtonTextAlign, ig.ImVec2(.5, .5))

	for i=1,maxItems do
		local selected = self.player.selectedItem == i
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
		ig.igButton('###'..i, ig.ImVec2(bw,bh))
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
