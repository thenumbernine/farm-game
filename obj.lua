local class = require 'ext.class'
local anim = require 'anim'
local gl = require 'gl'
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'

local Obj = class()

-- default
Obj.seq = 'stand'
Obj.frame = 1

function Obj:init(args)
	self.angle = 1.5 * math.pi
	
	if not self.drawSize then
		self.drawSize = vec2f(1,1)
	else
		self.drawSize = vec2f(self.drawSize:unpack())
	end
	if args and args.drawSize then
		self.darwSize:set(args.drawSize:unpack())
	end

	self.pos = vec3f(0,0,0)
	self.vel = vec3f(0,0,0)
	if args then
		if args.pos then
			self.pos:set(args.pos:unpack())
		end
		if args.vel then
			self.vel:set(args.vel:unpack())
		end
	end
end

local quad = {
	{0,0},
	{0,1},
	{1,1},
	{1,0},
}

-- ccw start at 0' (with 45' spread)
local dirSeqSuffixes = {'_r', '_u', '_l', '_d'}

function Obj:update(dt)
-- [[
	self.pos.x = self.pos.x + self.vel.x * dt
	self.pos.y = self.pos.y + self.vel.y * dt
	self.pos.z = self.pos.z + self.vel.z * dt
--]]
end

function Obj:draw()
	local seqname = self.seq
	if seqname and self.seqUsesDir then	-- enable this for sequences that use _u _d _l _r etc (TODO search by default?)
		local angleIndex = math.floor(self.angle / (.5 * math.pi) + .5) % 4 + 1
		seqname = seqname .. dirSeqSuffixes[angleIndex]
--print('angle', self.angle, 'index', angleIndex, 'seqname', seqname)
	end
	
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
				for _,uv in ipairs(quad) do
					gl.glTexCoord2f(uv[1], uv[2])
					gl.glVertex3f((
						app.view.angle:xAxis() * (uv[1] - .5) * self.drawSize.x
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
	self.vel:set(dx, dy, 0)

	Player.super.update(self, dt)
end


assert(not Obj.classes)
Obj.classes = {
	Player = Player,
}


return Obj
