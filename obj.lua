local gl = require 'gl'
local class = require 'ext.class'
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local anim = require 'zelda.anim'
local Tile = require 'zelda.tile'

local Obj = class()

-- default
Obj.seq = 'stand'
Obj.frame = 1

function Obj:init(args)
	assert(args)

	self.angle = 1.5 * math.pi
	
	if not self.drawSize then
		self.drawSize = vec2f(1,1)
	else
		self.drawSize = vec2f(self.drawSize:unpack())
	end
	if args.drawSize then self.darwSize:set(args.drawSize:unpack()) end

	self.pos = vec3f(0,0,0)
	if args.pos then self.pos:set(args.pos:unpack()) end
	self.oldpos = vec3f(self.pos:unpack())

	self.vel = vec3f(0,0,0)
	if args.vel then self.vel:set(args.vel:unpack()) end

	self.min = vec3f(-.4, -.4, 0)
	if args.min then self.min:set(args.min:unpack()) end
	
	self.max = vec3f(.4, .4, .8)
	if args.max then self.max:set(args.max:unpack()) end
end

-- how to handle collision?
-- go back to start of trace?
-- find intersection and then redo collision over remaining timestep?
-- or just push? how about just push
local epsilon = 1e-5
local function push(pos, min, max, bmin, bmax, vel)
	-- TODO cache these as 'worldmin'/max? 
	local amin = pos + min
	local amax = pos + max
	--[[
	how to detect convex simplex collison?
	check all sides, find closest vtx on obj A to side on B
	if it separates (plane dist > 0) then we have no collision
	if no planes separate (all dists are positive) then we have collision somewhere
	and in that case, use the *most shallow* (greatest negative #) penetration to push back ... not the deepest?  because deepest plane dist could be out the other side?  hmm ...
	but what about rects resting on one another? edge/edge collision?
	
	what's an aabb way to do collision?
	for each side, for each +-,
		find the subset rect of each side
		if it is non-null ...
		look at the side of obj A's pos along the axis, whether it is in bounds of obj B
		if so
			then we have a collision
	--]]
	-- do the boxes intersect on the plane of axis j & k ?
	if amin.x <= bmax.x
	and amax.x >= bmin.x
	and amin.y <= bmax.y
	and amax.y >= bmin.y
	and amin.z <= bmax.z
	and amax.z >= bmin.z
	then
		-- find the center of the intersecting region
		-- find the largest axis of the center
		-- use that as the collision axis
		local iminx = math.max(amin.x, bmin.x)
		local iminy = math.max(amin.y, bmin.y)
		local iminz = math.max(amin.z, bmin.z)
		
		local imaxx = math.min(amax.x, bmax.x)
		local imaxy = math.min(amax.y, bmax.y)
		local imaxz = math.min(amax.z, bmax.z)
		
		local midx = (iminx + imaxx) * .5
		local midy = (iminy + imaxy) * .5
		local midz = (iminz + imaxz) * .5
				
		local dx = imaxx - iminx
		local dy = imaxy - iminy
		local dz = imaxz - iminz
		
		local side, pm
		if dx < dy then
			if dx < dz then
				side, pm = 0, .5 * (amin.x + amax.x) < midx and 1 or -1
			else
				side, pm = 2, .5 * (amin.z + amax.z) < midz and 1 or -1
			end
		else
			if dy < dz then
				side, pm = 1, .5 * (amin.y + amax.y) < midy and 1 or -1
			else
				side, pm = 2, .5 * (amin.z + amax.z) < midz and 1 or -1
			end
		end
		
		if side == 0 then 
			vel.x = 0
			if pm == 1 then
				pos.x = bmin.x - max.x - epsilon
			else
				pos.x = bmax.x - min.x + epsilon
			end
		elseif side == 1 then 
			vel.y = 0 
			if pm == 1 then
				pos.y = bmin.y - max.y - epsilon
			else
				pos.y = bmax.y - min.y + epsilon
			end
		elseif side == 2 then 
			vel.z = 0
			if pm == 1 then
				pos.z = bmin.z - max.z - epsilon
			else
				pos.z = bmax.z - min.z + epsilon
			end
		end
	end
end

Obj.gravity = -9.8
Obj.hitsides = 0
local epsilon = 1e-5
function Obj:update(dt)
	self.oldpos:set(self.pos:unpack())
-- [[
	self.pos.x = self.pos.x + self.vel.x * dt
	self.pos.y = self.pos.y + self.vel.y * dt
	self.pos.z = self.pos.z + self.vel.z * dt
--]]
	self.vel.z = self.vel.z + self.gravity * dt

	for i=math.floor(math.min(self.pos.x, self.oldpos.x) + self.min.x - 1.5),math.floor(math.max(self.pos.x, self.oldpos.x) + self.max.x + .5) do
		for j=math.floor(math.min(self.pos.y, self.oldpos.y) + self.min.y - 1.5),math.floor(math.max(self.pos.y, self.oldpos.y) + self.max.y + .5) do
			for k=math.floor(math.min(self.pos.z, self.oldpos.z) + self.min.z - 1.5),math.floor(math.max(self.pos.z, self.oldpos.z) + self.max.z + .5) do
				if app.game.map:get(i,j,k) == Tile.typeValues.SOLID then
					local omin = vec3f(i,j,k)
					local omax = vec3f(i+1,j+1,k+1)
					push(self.pos, self.min, self.max, omin, omax, self.vel)
				end
			end
		end
	end
end

-- ccw start at 0' (with 45' spread)
local dirSeqSuffixes = {'_r', '_u', '_l', '_d'}

function Obj:draw()
	local seqname = self.seq
	if seqname and self.seqUsesDir then	-- enable this for sequences that use _u _d _l _r etc (TODO search by default?)
		local angleIndex = math.floor(self.angle / (.5 * math.pi) + .5) % 4 + 1
		seqname = seqname .. dirSeqSuffixes[angleIndex]
--print('angle', self.angle, 'index', angleIndex, 'seqname', seqname)
	end

--[[
	for faceIndex,faces in ipairs(Tile.cubeFaces) do
		if bit.band(self.hitsides, bit.lshift(1, faceIndex-1)) ~= 0 then
			gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
			gl.glColor3f(1,0,0)
		else
			gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
			gl.glColor3f(1,1,1)
		end
		gl.glBegin(gl.GL_QUADS)
		for f,face in ipairs(faces) do
			local v = Tile.cubeVtxs[face+1]
			gl.glVertex3f(
				self.pos.x + (1 - v[1]) * self.min.x + v[1] * self.max.x,
				self.pos.y + (1 - v[2]) * self.min.y + v[2] * self.max.y,
				self.pos.z + (1 - v[3]) * self.min.z + v[3] * self.max.z)
		end
		gl.glEnd()
	end
	gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
	gl.glColor3f(1,1,1)
--]]

	if self.sprite then
		local sprite = anim[self.sprite]
		if sprite and seqname then
			local seq = sprite[seqname]
--print('seqname', seqname, 'seq', seq)
			if seq and self.frame then
				local frame = seq[self.frame]
				local uscale = 1
				if frame.hflip then uscale = uscale * -1 end
				frame.tex:bind()
				gl.glBegin(gl.GL_QUADS)
				for _,uv in ipairs(Tile.unitquad) do
					gl.glTexCoord2f(uv[1], uv[2])
					gl.glVertex3f((
						app.view.angle:xAxis() * (.5 - uv[1]) * self.drawSize.x
						+ app.view.angle:yAxis() * (1 - uv[2]) * self.drawSize.y
						+ self.pos
					):unpack())
				end
				gl.glEnd()
				frame.tex:unbind()
			end
		end
	end
end


local Player = class(Obj)

Player.sprite = 'link'
Player.drawSize = vec2f(1,1.5)
Player.seqUsesDir = true
Player.walkSpeed = 5

function Player:update(dt)
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

	Player.super.update(self, dt)
end


assert(not Obj.classes)
Obj.classes = {
	Player = Player,
}


return Obj
