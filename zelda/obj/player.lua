local gl = require 'gl'
local class = require 'ext.class'
local table = require 'ext.table'
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local quatd = require 'vec-ffi.quatd'
local Obj = require 'zelda.obj.obj'
local sides = require 'zelda.sides'


local Player = require 'zelda.obj.takesdamage'(Obj):subclass()
Player.name = 'Player'	-- TODO require name?

Player.sprite = 'link'
Player.drawSize = vec2f(1, 1.5)
Player.drawCenter = vec2f(.5, 1)

Player.angle = 1.5 * math.pi

Player.bbox = box3f{
	min = {-.3, -.3, 0},
	max = {.3, .3, 1.5},
}

Player.hpMax = 10
Player.foodMax = 10

Player.walkSpeed = 6

Player.attackTime = -1
Player.attackEndTime = -1
Player.attackDuration = .35

Player.jumpVel = 5

-- how many items?
-- minecraft inventory: 9x4 = 36
-- stardew valley: 12x3 = 36
-- D2: 4x10 = 40
Player.numSelectableItems = 12
Player.numInvItems = 48	-- including the selectable row

-- how much to turn the view when you press the rotate-view left/right buttons
-- 90°:
--Player.rotateViewAmount = .5 * math.pi
-- 45°:
Player.rotateViewAmount = .25 * math.pi

function Player:init(args, ...)
	Player.super.init(self, args, ...)

	self.player = assert(args.player)

	self.food = self.foodMax

	--[[
	how should inventory work?
	for key based
	--]]
	self.selectedItem = 1
	self.items = table{
		require 'zelda.item.sword',
		require 'zelda.item.shovel',
		require 'zelda.item.axe',
		require 'zelda.item.hoe',
		require 'zelda.item.wateringcan',
		require 'zelda.obj.chest',
	}:mapi(function(cl)
		return {
			class = cl,
			count = 1,
		}
	end):setmetatable(nil)
end

function Player:update(dt)
	local map = self.map
	local game = self.game
	local app = game.app
	local appPlayer = assert(self.player)

	-- TODO dif activities use dif energy
	self.food = math.max(0, self.food - dt * .1)
	if self.food <= 0 then
		self:damage(dt * .1, self, self)
		if self.dead then return end
	end

	if self.sleeping then return end
	-- use for animations ... and sleeping?
	if self.cantMove then return end

	-- if a prompt is open then don't handle buttons
	if not appPlayer.gamePrompt then

		if appPlayer.invOpen then
			
			local chestOpen = appPlayer.chestOpen
			local maxItems = self.numInvItems
			if chestOpen then
				maxItems = maxItems + chestOpen.numInvItems
			end

			if appPlayer.keyPress.right and not appPlayer.keyPressLast.right then
				self.selectedItem = self.selectedItem + 1
				self.selectedItem = (self.selectedItem - 1) % maxItems + 1
			end
			if appPlayer.keyPress.left and not appPlayer.keyPressLast.left then
				self.selectedItem = self.selectedItem - 1 
				self.selectedItem = (self.selectedItem - 1) % maxItems + 1
			end
			if appPlayer.keyPress.up and not appPlayer.keyPressLast.up then
				self.selectedItem = self.selectedItem + self.numSelectableItems
				self.selectedItem = (self.selectedItem - 1) % maxItems + 1
			end
			if appPlayer.keyPress.down and not appPlayer.keyPressLast.down then
				self.selectedItem = self.selectedItem - self.numSelectableItems
				self.selectedItem = (self.selectedItem - 1) % maxItems + 1
			end	
			-- drop item
			if appPlayer.keyPress.interact and not appPlayer.keyPressLast.interact then
				local cl = self:removeSelectedItem()
				if cl then
					self.map:newObj{
						class = require 'zelda.obj.item',
						itemClass = cl,
						itemCount = 1,	-- TODO or should I be like minecraft and just have all item-objects == 1 ...
						pos = (self.pos + vec3f(
							math.cos(self.angle) + (math.random() - .5) * .1,
							math.sin(self.angle) + (math.random() - .5) * .1,
							.5 + (math.random() - .5) * .1
						)),
					}
				end
			end
		else
			self.selectedItem = (self.selectedItem-1) % self.numSelectableItems + 1
			
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
		end

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

		if appPlayer.keyPress.interact
		and not appPlayer.keyPressLast.interact
		then
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
				-- TODO custom iterator for only the non-removed objects
				for _,obj in ipairs(tileObjs) do
					if not obj.removeFlag then
						if obj.interactInWorld then
							obj:interactInWorld(self)
							found = true
							break
						end
					end
				end
			end
			if not found then
				-- TODO check map for pick up based on tile type
			end
		end

		local turnLeft = appPlayer.keyPress.rotateLeft and not appPlayer.keyPressLast.rotateLeft 
		local turnRight = appPlayer.keyPress.rotateRight and not appPlayer.keyPressLast.rotateRight 
		if turnLeft or turnRight then
			if turnLeft then
				app.targetViewYaw = app.targetViewYaw + self.rotateViewAmount
			end
			if turnRight then
				app.targetViewYaw = app.targetViewYaw - self.rotateViewAmount 
			end
		end
		if appPlayer.keyPress.invLeft and not appPlayer.keyPressLast.invLeft then
			self.selectedItem = ((self.selectedItem-1 - 1)%self.numSelectableItems)+1
		end
		if appPlayer.keyPress.invRight and not appPlayer.keyPressLast.invRight then
			self.selectedItem = ((self.selectedItem-1 + 1)%self.numSelectableItems)+1
		end
		if appPlayer.keyPress.openInventory and not appPlayer.keyPressLast.openInventory then
			-- TODO put all clientside stuff in appPlayer
			appPlayer.invOpen = not appPlayer.invOpen
			-- if we closed inventory and a chest was open then disconnect it too
			if not appPlayer.invOpen then
				appPlayer.chestOpen = nil
			end
		end
	end

	Player.super.update(self, dt)

	-- shake plants when you are near them
	do
		local x,y,z = self.pos:unpack()
		x = math.floor(x)
		y = math.floor(y)
		z = math.floor(z)
		for k=z-1,z+1 do
			for j=y-1,y+1 do
				for i=x-1,x+1 do
					local objs = map:getTileObjs(i,j,k)
					if objs then
						for _,obj in ipairs(objs) do
							if obj.shakeWhenNear then
								obj:shake()
							end
						end
					end
				end
			end
		end
	end

	-- copy current to last keypress
	-- do this here or in a separate update after object :update()'s?
	for k,v in pairs(appPlayer.keyPress) do
		appPlayer.keyPressLast[k] = v
	end
end

function Player:useItem()
	local itemInfo = self.items[self.selectedItem]
	if itemInfo then
		local cl = itemInfo.class
		if cl.useInInventory then
			cl:useInInventory(self)
		end
	end
end

function Player:addItem(cl, count)
	assert(cl)
	count = count or 1
	for i=1,self.numInvItems do
		local itemInfo = self.items[i]
		if itemInfo 
		and itemInfo.class == cl 
		then
			itemInfo.count = itemInfo.count + count
			return true
		end
	end
	for i=1,self.numInvItems do
		if not self.items[i] then
			self.items[i] = {
				class = assert(cl),
				count = count,
			}
			return true
		end
	end
	return false
end

function Player:removeSelectedItem()
	local itemInfo = self.items[self.selectedItem]
	if not itemInfo then return end
	itemInfo.count = itemInfo.count - 1
	if itemInfo.count <= 0 then
		self.items[self.selectedItem] = nil
	end
	return itemInfo.class
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
