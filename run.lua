#!/usr/bin/env luajit

local class = require 'ext.class'
local bit = require 'bit'
local gl = require 'gl'
local anim = require 'anim'
local ImGuiApp = require 'imguiapp'
local Game = require 'zelda.game'
local gettimeofday = require 'zelda.gettimeofday'

local App = class(require 'glapp.orbit'(ImGuiApp))
App.title = 'Zelda 4D'

App.viewDist = 7

function App:initGL()
	app = self	-- global

	App.super.initGL(self)

	self.view.angle:fromAngleAxis(1,0,0,20)

	-- [[ load tex2ds for anim
	local GLTex2D = require 'gl.tex2d'
	for _,sprite in pairs(anim) do
		for _,seq in pairs(sprite) do
			for _,frame in pairs(seq) do
				frame.tex = GLTex2D{
					filename = frame.filename,
					magFilter = gl.GL_LINEAR,
					minFilter = gl.GL_NEAREST,
				}
			end
		end
	end
	--]]

	self.game = Game()
	
	self.view.pos:set((self.view.angle:zAxis() * self.viewDist):unpack())
	
	self.lastTime = gettimeofday()
	self.updateTime = 0
	
	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glEnable(gl.GL_CULL_FACE)
end

App.updateDelta = 1/30

function App:update()
	local thisTime = gettimeofday()
	local deltaTime = thisTime - self.lastTime
	self.lastTime = thisTime
	
	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))

	gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)
	gl.glEnable(gl.GL_BLEND)
	gl.glEnable(gl.GL_TEXTURE_2D)
	
	-- TODO frameskip
	self.game:draw()
	
	gl.glDisable(gl.GL_TEXTURE_2D)
	gl.glDisable(gl.GL_BLEND)

	self.updateTime = self.updateTime + deltaTime
	if self.updateTime >= self.updateDelta then
		self.updateTime = self.updateTime - self.updateDelta

		-- TODO fixed update
		self.game:update(self.updateDelta)
	end

	App.super.update(self)
end

function App:event(event, ...)
	App.super.event(self, event, ...)
	self.game:onEvent(event)
end

App():run()
