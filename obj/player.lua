local gl = require 'gl'
local class = require 'ext.class'
local table = require 'ext.table'
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'
local sides = require 'zelda.sides'


local Player = Obj:subclass()
Player.name = 'Player'	-- TODO require name?

Player.sprite = 'link'
Player.drawSize = vec2f(1,1.5)
Player.walkSpeed = 6

Player.attackTime = -1
Player.attackEndTime = -1
Player.attackDuration = .35

Player.min = vec3f(-.3, -.3, -.3)
Player.max = vec3f(.3, .3, .3)

function Player:init(...)
	Player.super.init(self, ...)

	self.selectedItem = 1
	-- TODO array-of-stacks 
	self.items = table{
		require 'zelda.obj.item.sword',
		require 'zelda.obj.item.hoe',
		require 'zelda.obj.item.wateringcan',
		require 'zelda.obj.item.seeds',
	}:mapi(function(cl)
		return cl{game=self.game}
	end)

	local bedItem = self.game:newObj{
		class = require 'zelda.obj.item.bed',
		pos = vec3f(math.huge, math.huge, math.huge),
	}
	self.items:insert(bedItem)
end

function Player:update(dt)
	local game = self.game
	local map = game.map

	local dx = 0
	local dy = 0
	if self.buttonRight then dx = dx + 1 end
	if self.buttonLeft then dx = dx - 1 end
	if self.buttonUp then dy = dy + 1 end
	if self.buttonDown then dy = dy - 1 end
	local l = dx*dx + dy*dy
	if l > 0 then
		l = self.walkSpeed / math.sqrt(l)
	end
	if dx ~= 0 or dy ~= 0 then
		self.angle = math.atan2(dy,dx)
	end
	dx = dx * l
	dy = dy * l

	local zDir = app.view.angle:zAxis()	-- down dir
	local xDir = app.view.angle:xAxis()	-- right dir
		
	local x2Dir = vec2f(1,0)--vec2f(xDir.x, xDir.y)
	x2Dir = x2Dir:normalize() 
	
	local y2Dir = vec2f(0,1)	--vec2f(-zDir.x, -zDir.y)
	y2Dir = y2Dir:normalize() 
	
	self.vel.x = (
		x2Dir.x * dx
		+ y2Dir.x * dy
	)
	self.vel.y = (
		x2Dir.y * dx
		+ y2Dir.y * dy
	)

	-- use = use currently selected inventory item
	if self.buttonUseItem then
		self:useItem()
	end
	
	if self.buttonJump then
		-- swing?  jump?  block?  anything?
		-- self.vel.z = self.vel.z - 10
		if bit.band(self.collideFlags, sides.flags.zm) ~= 0 then
			self.vel.z = self.vel.z + self.jumpVel
		end
	end

	if self.buttonInteract then
		do 
			-- TODO
			-- traceline ...
			-- see if it hits an obj or a map block
			-- run a 'onPickUp' function on it
		
			local x,y,z = (self.pos + vec3f(
				math.cos(self.angle),
				math.sin(self.angle),
				0
			)):map(math.floor):unpack()

			local found
			local tileObjs = map:getTileObjs(x,y,z)
			if tileObjs then
				for _,obj in ipairs(tileObjs) do
					if obj.interactInWorld then
						obj:interactInWorld(self)
						found = true
						break
					end
				end
			end
			if not found then
				-- TODO check map for pick up based on tile type
			end
		end
	end

	Player.super.update(self, dt)
end

Player.jumpVel = 4

function Player:useItem()
	local item = self.items[self.selectedItem]
	if item then item:useInInventory(self) end
end

function Player:draw(...)
	local game = self.game

	-- draw sprite
	Player.super.draw(self, ...)

	if self.attackEndTime > game.time then
		local delta = (game.time - self.attackTime) / (self.attackEndTime - self.attackTime)
		gl.glDepthMask(gl.GL_FALSE)
		local shader = game.swordShader
		shader:use()
		gl.glUniformMatrix4fv(shader.uniforms.mvProjMat.loc, 1, gl.GL_FALSE, game.app.view.mvProjMat.ptr)
		gl.glBegin(gl.GL_TRIANGLE_STRIP)
		gl.glVertexAttrib4f(shader.attrs.color.loc, 1,1,.4,.7*(1-delta))
		local dtheta = 150*math.pi/180
		local ndivs = 20
		for i=1,ndivs do
			local theta = self.angle + (i/(ndivs-1)-.5)*dtheta
			local rNear = .3
			local rFar = 1.3
			local dr = rFar - rNear
			for r=rNear,rNear + 1.5*dr,dr do
				gl.glVertex3f(
					self.swingPos.x + r * math.cos(theta),
					self.swingPos.y + r * math.sin(theta),
					self.swingPos.z + .05)
			end
		end
		gl.glEnd()
		gl.glDepthMask(gl.GL_TRUE)
		shader:useNone()
	end
end

return Player
