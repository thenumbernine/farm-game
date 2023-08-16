local gl = require 'gl'
local class = require 'ext.class'
local table = require 'ext.table'
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'
local sides = require 'zelda.sides'
local Tile = require 'zelda.tile'

-- I bet soon 'Item' will be subclass of 'Object' ...
local Item = class()


local ItemSword = Item:subclass()

ItemSword.name = 'sword'

function ItemSword:use(player)
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


local ItemHoe = Item:subclass()

ItemHoe.name = 'hoe'

function ItemHoe:use(player)
	local game = player.game
	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()
	print(x,y,z)
	local topTile = game.map:get(x,y,z)
	local groundTile = game.map:get(x,y,z-1)
	if groundTile == Tile.typeValues.Grass
	and topTile == Tile.typeValues.Empty
	then
		local Hoed = require 'obj.hoed'
		-- TODO link objects by voxels touched
		local found
		for _,obj in ipairs(game.objs) do
			if Hoed:isa(obj)
			and math.floor(obj.pos.x) == x
			and math.floor(obj.pos.y) == y
			and math.floor(obj.pos.z) == z
			then
				found = true
				break
			end
		end
		if not found then
			game:newObj{
				class = Hoed,
				pos = vec3f(x+.5, y+.5, z),
			}
			print(#game.objs)
		end
	end
end


local ItemSeeds = Item:subclass()

ItemSeeds.name = 'seeds'

function ItemSeeds:use(player)
	local game = player.game
	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()
	print(x,y,z)
	local topTile = game.map:get(x,y,z)
	local groundTile = game.map:get(x,y,z-1)
	if groundTile == Tile.typeValues.Grass
	and topTile == Tile.typeValues.Empty
	then
		-- TODO dif kinds of seeds ... hmm ...
		local Hoed = require 'obj.hoed'
		local SeededGround = require 'obj.seededground'
		-- TODO link objects by voxels touched
		local foundSeededGround
		local foundHoed
		for _,obj in ipairs(game.objs) do
			if SeededGround:isa(obj)
			and math.floor(obj.pos.x) == x
			and math.floor(obj.pos.y) == y
			and math.floor(obj.pos.z) == z
			then
				foundSeededGround = true
				--break
			end
			if Hoed:isa(obj)
			and math.floor(obj.pos.x) == x
			and math.floor(obj.pos.y) == y
			and math.floor(obj.pos.z) == z
			then
				foundHoed = true
				--break
			end
	
		end
		if foundHoed 
		and not foundSeededGround 
		then
			game:newObj{
				class = SeededGround,
				pos = vec3f(x+.5, y+.5, z),
			}
			print(#game.objs)
		end
	end
end




local Player = Obj:subclass()

Player.sprite = 'link'
Player.drawSize = vec2f(1,1.5)
Player.walkSpeed = 6

Player.attackTime = -1
Player.attackEndTime = -1
Player.attackDuration = .35

function Player:init(...)
	Player.super.init(self, ...)

	self.selectedItem = 1
	self.items = table{
		ItemSword(),
		ItemHoe(),
		ItemSeeds(),
	}
end

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

	if self.buttonUse then
		self:use()
	end
	
	if self.buttonJump then
		-- swing?  jump?  block?  anything?
		-- self.vel.z = self.vel.z - 10
		if bit.band(self.collideFlags, sides.flags.zm) ~= 0 then
			self.vel.z = self.vel.z + self.jumpVel
		end
	end

	Player.super.update(self, dt)
end

Player.jumpVel = 4

function Player:use()
	local item = self.items[self.selectedItem]
	if item then item:use(self) end
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
