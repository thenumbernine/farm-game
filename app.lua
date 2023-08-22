local bit = require 'bit'
local class = require 'ext.class'
local range = require 'ext.range'
local table = require 'ext.table'
local sdl = require 'ffi.req' 'sdl'
local ig = require 'imgui'
local quatd = require 'vec-ffi.quatd'
local gl = require 'gl'
local anim = require 'zelda.anim'
local Game = require 'zelda.game'
local getTime = require 'ext.timer'.getTime
local OBJLoader = require 'mesh.objloader'

require 'glapp.view'.useBuiltinMatrixMath = true

local App = require 'gameapp':subclass()

App.title = 'Zelda 4D'

App.viewDist = 7

-- override Menus
local Menu = require 'gameapp.menu.menu'
Menu.Splash = require 'zelda.menu.splash'

local PlayingMenu = require 'zelda.menu.playing'

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
		rotateLeft = {sdl.SDL_KEYDOWN, ('a'):byte()},
		rotateRight = {sdl.SDL_KEYDOWN, ('s'):byte()},
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
MainMenu.menuOptions[1].click = function(self)
	local app = self.app
	app.cfg.numPlayers = 1
	app.menu = PlayingMenu(app)

	-- temp hack for filling out default keys
	PlayerKeysEditor(app)
end

-- TODO instances should be a member of game?
local Player = class()

-- gameplay keys to record for demos (excludes pause)
Player.gameKeyNames = table{
	'up',
	'down',
	'left',
	'right',
	'jump',
	'useItem',
	'interact',
	'rotateLeft',
	'rotateRight',
}

-- all keys to capture via sdl events during gameplay
Player.keyNames = table(Player.gameKeyNames):append{
	'pause',
}

-- set of game keys (for set testing)
Player.gameKeySet = Player.gameKeyNames:mapi(function(k)
	return true, k
end):setmetatable(nil)

function Player:init(args)
	self.app = assert(args.app)
	self.index = assert(args.index)
	self.keyPress = {}
	self.keyPressLast = {}
	for _,k in ipairs(self.keyNames) do
		self.keyPress[k] = false
		self.keyPressLast[k] = false
	end

	self.money = 1000
end

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
	for _,sprite in pairs(anim) do
		for seqname,seq in pairs(sprite) do
			if seqname ~= 'useDirs' then	-- skip properties
				for _,frame in pairs(seq) do
					local fn = frame.filename
					if fn:sub(-4) == '.png' then
						frame.tex = GLTex2D{
							filename = frame.filename,
							magFilter = gl.GL_LINEAR,
							minFilter = gl.GL_NEAREST,
						}
					elseif fn:sub(-4) == '.obj' then
						frame.mesh = OBJLoader():load(fn)
					else
						print("idk how to load this file")
					end
				end
			end
		end
	end
	--]]


	-- TODO this in App:reset()

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

	self.game = Game{app=self}

	self.lastTime = getTime()
	self.updateTime = 0

	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glEnable(gl.GL_CULL_FACE)
end

App.updateDelta = 1/30

function App:updateGame()
	local thisTime = getTime()
	local deltaTime = thisTime - self.lastTime
	self.lastTime = thisTime

	self.viewYaw = self.viewYaw + .1 * (self.targetViewYaw - self.viewYaw)
	self.view.angle = quatd():fromAngleAxis(0, 0, 1, self.viewYaw)
					* quatd():fromAngleAxis(1,0,0,30)
	self.view.pos = self.view.angle:zAxis() * (self.view.pos - self.view.orbit):length() + self.view.orbit

	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))

	--[[ not in gles ... needs to be coded into the shaders.
	gl.glEnable(gl.GL_ALPHA_TEST)
	gl.glAlphaFunc(gl.GL_GEQUAL, .1)
	--]]
	gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)
	gl.glEnable(gl.GL_BLEND)

	-- TODO frameskip
	self.game:draw()

	gl.glDisable(gl.GL_BLEND)

	self.updateTime = self.updateTime + deltaTime
	if self.updateTime >= self.updateDelta then
		self.updateTime = self.updateTime - self.updateDelta

		-- TODO fixed update
		self.game:update(self.updateDelta)
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
			self.viewYaw = self.viewYaw + dx
			self.view.angle = quatd():fromAngleAxis(0, 0, 1, self.viewYaw)
							* quatd():fromAngleAxis(1,0,0,30)
			self.view.pos = self.view.angle:zAxis() * (self.view.pos - self.view.orbit):length() + self.view.orbit
		end
	end
--]]

	self.game:event(event)
end

return App
