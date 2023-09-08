--[[
details / subclasses are in zelda/animals [].objClass
--]]
local Obj = require 'zelda.obj.obj'

local Animal = require 'zelda.obj.placeableobj'(
	require 'zelda.obj.takesdamage'(
		Obj
	)
):subclass()
Animal.classname = 'zelda.obj.animal'

Animal.name = 'Animal'

function Animal:init(args, ...)
	Animal.super.init(self, args, ...)
	-- store in obj for serialization's sake
	-- TODO there are a few other ways to serialize Plant/Animal subclasses
	self.animalType = args.animalType or self.animalType
	assert(self.animalType)
end


return Animal
