local bit = require 'bit'
local range = require 'ext.range'
local table = require 'ext.table'
local sdl = require 'ffi.req' 'sdl'
local ig = require 'imgui'
local quatd = require 'vec-ffi.quatd'
local gl = require 'gl'
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

return App
