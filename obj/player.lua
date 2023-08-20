local gl = require 'gl'
local class = require 'ext.class'
local table = require 'ext.table'
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local quatd = require 'vec-ffi.quatd'
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

Player.min = vec3f(-.3, -.3, 0)
Player.max = vec3f(.3, .3, .6)

function Player:init(args, ...)
	Player.super.init(self, args, ...)

	self.player = assert(args.player)

	self.selectedItem = 1
	-- TODO array-of-stacks
	self.items = table{
		require 'zelda.obj.item.sword',
		require 'zelda.obj.item.axe',
		require 'zelda.obj.item.hoe',
		require 'zelda.obj.item.wateringcan',
		require 'zelda.obj.item.bed',
	}:mapi(function(cl)
		return {
			class = cl,
			count = 1,
		}
	end)
end

function Player:update(dt)
	local game = self.game
	local app = game.app
	local map = game.map
	local appPlayer = assert(self.player)

	-- if a prompt is open then don't handle buttons
	if not self.gamePrompt then
		local dx = 0
		local dy = 0
		if appPlayer.keyPress.right then dx = dx + 1 end
		if appPlayer.keyPress.left then dx = dx - 1 end
		if appPlayer.keyPress.up then dy = dy + 1 end
		if appPlayer.keyPress.down then dy = dy - 1 end
		local l = dx*dx + dy*dy
		if l > 0 then
			l = self.walkSpeed / math.sqrt(l)
		end
		local localAngle
		if dx ~= 0 or dy ~= 0 then
			localAngle = math.atan2(dy, dx)
		end
		dx = dx * l
		dy = dy * l

		local zDir = app.view.angle:zAxis()	-- down dir
		local xDir = app.view.angle:xAxis()	-- right dir
		
		if localAngle then
			self.angle = localAngle + math.atan2(xDir.y, xDir.x)
		end

		--local x2Dir = vec2f(1,0)
		local x2Dir = vec2f(xDir.x, xDir.y)
		x2Dir = x2Dir:normalize()

		--local y2Dir = vec2f(0,1)
		local y2Dir = vec2f(-zDir.x, -zDir.y)
		y2Dir = y2Dir:normalize()

		self.vel.x = x2Dir.x * dx + y2Dir.x * dy
		self.vel.y = x2Dir.y * dx + y2Dir.y * dy

		-- use = use currently selected inventory item
		if appPlayer.keyPress.useItem then
			self:useItem()
		end

		if appPlayer.keyPress.jump then
			-- swing?  jump?  block?  anything?
			-- self.vel.z = self.vel.z - 10
			if bit.band(self.collideFlags, sides.flags.zm) ~= 0 then
				self.vel.z = self.vel.z + self.jumpVel
			end
		end

		if appPlayer.keyPress.interact then
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

		local turnLeft = appPlayer.keyPress.rotateLeft and not appPlayer.keyPressLast.rotateLeft 
		local turnRight = appPlayer.keyPress.rotateRight and not appPlayer.keyPressLast.rotateRight 
		if turnLeft or turnRight then
			if turnLeft then
				app.targetViewYaw = app.targetViewYaw + 90
			end
			if turnRight then
				app.targetViewYaw = app.targetViewYaw - 90
			end
		end
	end

	Player.super.update(self, dt)

	-- copy current to last keypress
	-- do this here or in a separate update after object :update()'s?
	for k,v in pairs(appPlayer.keyPress) do
		appPlayer.keyPressLast[k] = v
	end
end

Player.jumpVel = 4

function Player:useItem()
	local itemInfo = self.items[self.selectedItem]
	if itemInfo then
		itemInfo.class:useInInventory(self)
	end
end

function Player:draw(...)
	local game = self.game

	-- draw sprite
	Player.super.draw(self, ...)

	if self.attackEndTime > game.time then
		local delta = (game.time - self.attackTime) / (self.attackEndTime - self.attackTime)
		local dtheta = 150*math.pi/180
		local ndivs = game.swordSwingNumDivs
		for i=1,ndivs do
			local theta = self.angle + (i/(ndivs-1)-.5)*dtheta
			local rNear = .3
			local rFar = 1.3
			local dr = rFar - rNear
			for j=0,1 do
				local r = rNear + j * dr
				game.swordSwingVtxBufCPU[j + 2 * (i-1)]:set(
					self.swingPos.x + r * math.cos(theta),
					self.swingPos.y + r * math.sin(theta),
					self.swingPos.z + .05)
			end
		end
		
		gl.glDepthMask(gl.GL_FALSE)
		local shader = game.swordShader
		shader:use()
		gl.glUniformMatrix4fv(shader.uniforms.mvProjMat.loc, 1, gl.GL_FALSE, game.app.view.mvProjMat.ptr)
		gl.glVertexAttrib4f(shader.attrs.color.loc, 1,1,.4,.7*(1-delta))
		gl.glVertexAttribPointer(shader.attrs.vertex.loc, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, game.swordSwingVtxBufCPU)
		gl.glEnableVertexAttribArray(shader.attrs.vertex.loc)
		gl.glDrawArrays(gl.GL_TRIANGLE_STRIP, 0, 2 * ndivs)
		gl.glDisableVertexAttribArray(shader.attrs.vertex.loc)
		gl.glDepthMask(gl.GL_TRUE)
		shader:useNone()
	end
end

return Player
