local sdl = require 'ffi.sdl'
local class = require 'ext.class'
local table = require 'ext.table'
local Map = require 'zelda.map'
local gl = require 'gl'
local GLTex2D = require 'gl.tex2d'
local vec3i = require 'vec-ffi.vec3i'
local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj'

local Game = class()

-- 16 x 16 = 256 tiles in a typical screen
-- 8 x 8 x 8 = 512 tiles
function Game:init()
	self.texpack = GLTex2D{
		filename = 'texpack.png',
		magFilter = gl.GL_LINEAR,
		minFilter = gl.GL_NEAREST,
	}
	self.map = Map(vec3i(16, 16, 16))

	self.objs = table()
	self.player = self:newObj{
		class = Obj.classes.Player,
		pos = vec3f(.5, .5, 1),
	}
end

function Game:newObj(args)
	local cl = args.class
	args.game = self
	local obj = cl(args)
	self.objs:insert(obj)
	return obj
end

function Game:draw()
	self.map:draw()
	for _,obj in ipairs(self.objs) do
		obj:draw()
	end
end

function Game:update(dt)
	for _,obj in ipairs(self.objs) do
		if obj.update then obj:update(dt) end
	end
end

function Game:onEvent(event)
	if event.type == sdl.SDL_KEYDOWN 
	or event.type == sdl.SDL_KEYUP 
	then
		local down = event.type == sdl.SDL_KEYDOWN 
		if event.key.keysym.sym == sdl.SDLK_w then--sdl.SDLK_UP then
			self.player.buttonUp = down
		elseif event.key.keysym.sym == sdl.SDLK_s then--sdl.SDLK_DOWN then
			self.player.buttonDown = down
		elseif event.key.keysym.sym == sdl.SDLK_a then--sdl.SDLK_LEFT then
			self.player.buttonLeft = down
		elseif event.key.keysym.sym == sdl.SDLK_d then--sdl.SDLK_RIGHT then
			self.player.buttonRight = down
		end
	end
end

return Game
