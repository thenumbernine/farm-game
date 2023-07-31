local sdl = require 'ffi.req' 'sdl'
local class = require 'ext.class'
local table = require 'ext.table'
local Map = require 'zelda.map'
local gl = require 'gl'
local GLTex2D = require 'gl.tex2d'
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
function Game:init()
	self.time = 0
	self.threads = ThreadManager()

	self.texpack = GLTex2D{
		filename = 'texpack.png',
		magFilter = gl.GL_LINEAR,
		minFilter = gl.GL_NEAREST,
	}
	self.map = Map(vec3i(16, 16, 16))

	self.objs = table()
	self.player = self:newObj{
		class = Obj.classes.Player,
		pos = vec3f(8.5, 8.5, 1.5),
	}

-- [[	
	for _,dir in ipairs{{1,0},{0,1},{-1,0},{0,-1}} do
		local ux, uy = table.unpack(dir)
		local vx, vy = -uy, ux
		for i=1,7,2 do
			for j=5,7,2 do
				self:newObj{
					class = Obj.classes.Goomba,
					pos = vec3f(ux * i + vx * j + 8.5, uy * i + vy * j + 8.5, 3.5),
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

local function glColorHex(i)
	gl.glColor3ub(
		bit.band(0xff, bit.rshift(i,16)),
		bit.band(0xff, bit.rshift(i,8)),
		bit.band(0xff, i)
	)
end

function Game:draw()

-- [[ sky
	gl.glMatrixMode(gl.GL_PROJECTION)
	gl.glPushMatrix()
	gl.glLoadIdentity()
	gl.glOrtho(0,1,0,1,-1,1)
	gl.glMatrixMode(gl.GL_MODELVIEW)
	gl.glPushMatrix()
	gl.glLoadIdentity()

	gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
	gl.glDisable(gl.GL_DEPTH_TEST)
	gl.glBegin(gl.GL_TRIANGLE_STRIP)
	glColorHex(0xda9134)	gl.glVertex2f(0,0)
	glColorHex(0xda9134)	gl.glVertex2f(1,0)
	glColorHex(0x313453)	gl.glVertex2f(0,1)
	glColorHex(0x313453)	gl.glVertex2f(1,1)
	gl.glEnd()
	gl.glColor3f(1,1,1)
	gl.glEnable(gl.GL_DEPTH_TEST)

	gl.glMatrixMode(gl.GL_PROJECTION)
	gl.glPopMatrix()
	gl.glMatrixMode(gl.GL_MODELVIEW)
	gl.glPopMatrix()
--]]


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
		end
	end
end

return Game
