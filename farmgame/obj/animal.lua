--[[
details / subclasses are in farmgame/animals [].objClass
--]]
local table = require 'ext.table'
local Obj = require 'farmgame.obj.obj'

local Animal = require 'farmgame.behaviors'(
	Obj,
	require 'farmgame.obj.placeableobj',
	require 'farmgame.obj.takesdamage'	-- apply takesdamage last so it overrides :damage()
):subclass()
Animal.classname = ...

Animal.name = 'Animal'
Animal.walking = true

function Animal:init(args, ...)
	Animal.super.init(self, args, ...)
	-- store in obj for serialization's sake
	-- TODO there are a few other ways to serialize Plant/Animal subclasses
	self.animalType = args.animalType or self.animalType
	assert(self.animalType)
end

Animal.states = table{
	{
		name = 'wait',
		enter = function(self)
			self.vel:set(0,0,0)
		end,
	},
	{
		name = 'walk',
		enter = function(self)
			--self.seq = 'walk'
			local angle = math.random() * 2 * math.pi
			local walkSpeed = 1
			self.vel:set(
				math.cos(angle) * walkSpeed,
				math.sin(angle) * walkSpeed,
				0)
		end,
		leave = function(self)
			self.seq = nil
		end,
	},
	{	-- TODO only pick this state if our food is low
		-- TODO for carnivores, go into hunt mode
		name = 'eat',
		enter = function(self)
			--self.seq = 'graze'
			-- TODO up the food points here too
		end,
		leave = function(self)
			self.seq = nil
		end,
	},
}

function Animal:update(dt)
	local game = self.game

	--animal fsm
	--	wait 
	--	walk
	--	eat grass 
	--		or chase something else to eat for carnivores
	if not self.state 
	or game.time > self.nextStateTime
	then
		if self.state and self.state.leave then
			self.state.leave(self)
		end
		self.state = self.states:pickRandom()
		if self.state.enter then
			self.state.enter(self)
		end
		local stateDuration = 5
		self.nextStateTime = game.time + stateDuration
	end

	if self.state.update then
		self.state.update(self)
	end

	Animal.super.update(self, dt)
end

return Animal
