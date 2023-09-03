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
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local Plant = require 'zelda.obj.takesdamage'(Obj):subclass()

-- TODO makeSubclass based on plantType
-- just like item/seeds
-- and then again for item/fruit
-- in fact maybe plantType should just generate per-plant a seed, a plant, and (optionlly) a fruit

Plant.name = 'Plant'

Plant.sprite = 'plant1'
Plant.spritePosOffset = vec3f(0,0,.003)

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

	-- TODO maybe move these to takesdamage
	-- have objects pick their own custom on-damage and on-death
	self.shakeOnHit = args.shakeOnHit
	self.tipOnDie = args.tipOnDie

	-- TODO instead of 'numLogs', how about some kind of num-resources-dropped
	self.numLogs = args.numLogs

	self.plantType = args.plantType
	assert(self.plantType)
end

function Plant:update(...)
	local game = self.game

	-- TODO how about < some frac (like 1/7th) show the seed
	self.growTime = game.time - self.createTime
	self.growFrac = self.growTime / self.growDuration
	
	if self.growFrac < 1/7 then
		-- seed-form:
		self.sprite = 'seededground'
		self.seq = 'stand'
		self.drawSize:set(1,1)
		self.bbox.min:set(-.3, -.3, -.001)
		self.bbox.max:set(.3, .3, .001)
		self.disableBillboard = true
		self.drawCenter:set(.5, .5)
	else
		-- plant-form:
		self.sprite = self.plantType.sprite
		self.seq = nil	-- fall back on class seq, generated class based on plantType
		local sx, sy = self.plantType.drawSize:unpack()
		if self.growFrac < 1 then
			sx = sx * self.growFrac
			sy = sy * self.growFrac
		end
		self.drawSize:set(sx, sy)
		self.bbox.min:set(-.49, -.49, 0)
		self.bbox.max:set(.49, .49, .98)
		self.disableBillboard = nil
		self.drawCenter:set(self.class.drawCenter:unpack())
	end

	if self.plantType.sprite == 'vegetable' then
		self.shakeWhenNear = self.growFrac >= 1
	end

	-- TODO old and dying trees

	-- don't do physics update
	--Plant.super.update(self, ...)
end

function Plant:interactInWorld(player)
	if self.shakeWhenNear
	and not player.pullUpPlantThread
	then
		local game = self.game
		-- if this is a tree or bush and it has fruit ... 
		-- ... drop the fruit
		-- TODO draw it also
		-- if this is a veg then pull it up
		-- how about fruit?  same?
		game.threads:add(function()
			self.pos:set(player.pos:unpack())
			local srcpos = self.pos:clone()
			self.useSeeThru = false
			game:fade(.5, function(x)
				self.pos.z = srcpos.z + 2*x
			end)
			self.pos:set(srcpos:unpack())
			self:toItem()
		end)
		player.pullUpPlantThread = game.threads:add(function()
			player.cantMove = true
			player.seq = 'kneel'
			game:sleep(.5)
			player.seq = 'handsup'
			game:sleep(.5)
			player.seq = 'stand'
			player.pullUpPlantThread = nil
			player.cantMove = nil
		end)
	end
end

function Plant:damage(amount, attacker, inflicter)
	if Plant.super.damage(self, amount, attacker, inflicter) then
		if self.shakeOnHit
		and not self.dead
		then
			-- shake plant angle ... for trees chopping down.
			self:shake()
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
				self.colorMatrix[{4,4}] = 1 - alpha
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
				self.map:newObj{
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

-- TODO maybe share this with tree axe hit?
function Plant:shake()
	if self.shakeThread then return end
	local game = self.game
	self.shakeThread = game.threads:add(function()
		game:fade(1, function(x)
			-- TODO stack modifiers on attributes?
			self.drawAngle = math.rad(10) * math.sin(-x*30) * math.exp(-5*x)
		end)
		self.shakeThread = nil
	end)
end

-- static method
function Plant:useInInventory(player)
	-- only run when the player pushes the button
	-- TODO maybe the push vs hold functionality should be moved to the player code?
	local appPlayer = player.player
	if appPlayer.keyPress.useItem and appPlayer.keyPressLast.useItem then return end

	-- heal and eat
	assert(player:removeSelectedItem() == self)

	player.hp = math.min(player.hp + self.hpGiven, player.hpMax)
	player.food = math.min(player.food + self.foodGiven, player.foodMax)
end

return Plant
