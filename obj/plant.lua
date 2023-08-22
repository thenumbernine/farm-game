--[[
ok plants ...

trees
	- start as saplings
	- grow up - gives you 2 logs 
	- once they're full - gives you 5 logs
		- also you can periodically pick stuff from them
			- ex: fruit?
			- ex: flowers?
			- ex: seeds?
	- then loses leafs + branches - deadwood - gives you 4 logs?
	- then naturally falls over ... and blits with world ... to create deadwood?
	

bushes
	- no logs?
	- can periodically pick
		- berries
		- seeds?  or seeds == berries ...

- gather-plants 
	- grab them and get them
	- ex: ferns, roots, ...

- scythe-to-harvest?
	- ex: hay, straw, grains ...

--]]
local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local Plant = require 'zelda.obj.takesdamage'(Obj):subclass()

Plant.name = 'Plant'

Plant.sprite = 'plant1'
Plant.useGravity = false	-- true?
Plant.collidesWithTiles = false	-- this slows things down a lot.  so just turn off gravity and dont test with world.
Plant.collidesWithObjects = false --?

-- default
--Obj.min = vec3f(-.49, -.49, 0)
--Obj.max = vec3f(.49, .49, .98)

function Plant:init(args, ...)
	Plant.super.init(self, args, ...)
	
	-- TODO instead of 'numLogs', how about some kind of num-resources-dropped
	self.numLogs = args.numLogs
end

function Plant:damage(amount, attacker, inflicter)
	if not (inflicter and inflicter.name == 'axe') then return end

	local game = self.game
	game.threads:add(function()
		game:fade(1, function(x)
			-- TODO stack modifiers on attributes?
			self.drawAngle = math.rad(10) * math.sin(-x*30) * math.exp(-5*x)
		end)
	end)
	
	return Plant.super.damage(self, amount, attacker, inflicter)
end

function Plant:die()
	local game = self.game
	game.threads:add(function()
		game:fade(1, function(x)
			-- TODO 3d model?
			self.drawAngle = -x * math.pi * .5
		end)
		self:remove()
	
		-- and then add a bunch of wood items
		print('fell tree spawning', self.numLogs, 'logs')
		for i=1,(self.numLogs or 0) do
			local r = math.random() * 2
			local theta = math.random() * 2 * math.pi
			game:newObj{
				class = require 'zelda.obj.log',
				pos = self.pos + vec3f(
					math.cos(theta) * r,
					math.sin(theta) * r,
					0
				)
			}
		end
	end)
end

return Plant 
