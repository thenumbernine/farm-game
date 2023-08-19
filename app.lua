local bit = require 'bit'
local sdl = require 'ffi.req' 'sdl'
local ig = require 'imgui'
local quatd = require 'vec-ffi.quatd'
local gl = require 'gl'
local anim = require 'zelda.anim'
local Game = require 'zelda.game'
local getTime = require 'ext.timer'.getTime
local ImGuiApp = require 'imguiapp'
local OBJLoader = require 'mesh.objloader'

require 'glapp.view'.useBuiltinMatrixMath = true

local App =
	--require 'glapp.orbit'(
		require 'glapp.view'.apply(ImGuiApp)
	--)
	:subclass()

App.title = 'Zelda 4D'

App.viewDist = 7

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

	-- in degrees
	self.targetViewYaw = 0
	self.viewYaw = 0

	self.game = Game{app=self}

	self.lastTime = getTime()
	self.updateTime = 0

	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glEnable(gl.GL_CULL_FACE)
end

App.updateDelta = 1/30

function App:update()
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

	App.super.update(self)
end

function App:updateGUI(...)
	self.game:updateGUI()
	return App.super.updateGUI(self, ...)
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
