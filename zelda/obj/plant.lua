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
local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local Plant = require 'zelda.obj.takesdamage'(Obj):subclass()

Plant.name = 'Plant'

Plant.sprite = 'plant1'
Plant.useGravity = false	-- true?
Plant.collidesWithTiles = false	-- this slows things down a lot.  so just turn off gravity and dont test with world.
Plant.collidesWithObjects = false --?
Plant.useSeeThru = true

Plant.numLogs = 0

--[[ default
Plant.box = box3f{
	min={-.49, -.49, 0},
	max={.49, .49, .98},
}
--]]
-- but TODO dif sizes for dif stages in life and for dif types of plants

function Plant:init(args, ...)
	Plant.super.init(self, args, ...)

	self.plantedTime = args.plantTime or self.game.time

	-- TODO maybe move these to takesdamage
	self.shakeOnHit = args.shakeOnHit
	self.tipOnDie = args.tipOnDie
	
	-- TODO instead of 'numLogs', how about some kind of num-resources-dropped
	self.numLogs = args.numLogs

	self.plantType = assert(args.plantType)
	self.color:set(self.plantType.color:unpack())
end

function Plant:update(...)
	local game = self.game

	if game.time - self.plantedTime < game.secondsPerDay then
		self.sprite = 'seededground'
		-- TODO bbox as well
		--self.bbox = box3f{min = {-.3, -.3, -.001}, max = {.3, .3, .001},}
	else
		self.sprite = self.plantType.sprite
	end

	Plant.super.update(self, ...)
end

function Plant:damage(amount, attacker, inflicter)
	if Plant.super.damage(self, amount, attacker, inflicter) then
		if self.shakeOnHit 
		and not self.dead
		then
			-- shake plant angle ... for trees chopping down.
			local game = self.game
			game.threads:add(function()
				game:fade(1, function(x)
					-- TODO stack modifiers on attributes?
					self.drawAngle = math.rad(10) * math.sin(-x*30) * math.exp(-5*x)
				end)
			end)
		end
		return true
	end
end

function Plant:die()
	-- hmm, move this to takesdamage? or keep it specilized here?
	-- takesdamage already has the goomba death in it ....
	-- maybe put a bunch of canned deaths in takesdamage and have an arg to pick which one
	local game = self.game
	if not self.tipOnDie then 
		-- fade out and remove
		game.threads:add(function()
			game:fade(1, function(alpha)
				self.color.w = 1 - alpha
			end)
			self:remove()
		end)
	else
		game.threads:add(function()
			-- TODO is this not working with sprites anymore?
			game:fade(1, function(x)
				-- TODO 3d model?
				self.drawAngle = -x * math.pi * .5
			end)
			self:remove()
		
			-- and then add a bunch of wood items
			print('fell tree spawning', self.numLogs, 'logs')
			for i=1,self.numLogs do
				local r = math.random() * 2
				local theta = math.random() * 2 * math.pi
				game:newObj{
					class = require 'zelda.obj.item',
					itemClass = require 'zelda.obj.log',
					pos = self.pos + vec3f(
						math.cos(theta) * r,
						math.sin(theta) * r,
						0
					)
				}
			end
		end)
	end
end

return Plant 
