local gl = require 'gl'
local class = require 'ext.class'
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local Player = class(Obj)

Player.sprite = 'link'
Player.drawSize = vec2f(1,1.5)
Player.seqUsesDir = true
Player.walkSpeed = 6

Player.attackTime = -1
Player.attackEndTime = -1
Player.attackDuration = .35

function Player:update(dt)
	local game = self.game
	
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

	if self.buttonAttack then
		self:attack()
	end
	
	if self.buttonUse then
		-- swing?  jump?  block?  anything?
		-- self.vel.z = self.vel.z - 10
	end

	Player.super.update(self, dt)
end

function Player:attack()
	local game = self.game

	if self.attackEndTime >= game.time then return end
	
	self.swingPos = vec3f(self.pos:unpack())
	self.attackTime = game.time
	self.attackEndTime = game.time + self.attackDuration

	-- see if we hit anyone
	for _,obj in ipairs(game.objs) do
		if obj ~= self 
		and obj.takesDamage
		and not obj.dead
		then
			local attackDist = 2	-- should match rFar in the draw code.  TODO as well consider object bbox / bounding radius.
			if (self.pos - obj.pos):lenSq() < attackDist*attackDist then
				obj:damage(1)
			end
		end
	end
end

function Player:draw(...)
	local game = self.game

	-- draw sprite
	Player.super.draw(self, ...)

	if self.attackEndTime > game.time then
		local delta = (game.time - self.attackTime) / (self.attackEndTime - self.attackTime)
		gl.glColor4f(1,1,.4,.7*(1-delta))
		gl.glDepthMask(gl.GL_FALSE)
		gl.glBegin(gl.GL_TRIANGLE_STRIP)
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
		gl.glColor4f(1,1,1,1)
	end
end

return Player
