local table = require 'ext.table'
local matrix_ffi = require 'matrix.ffi'

local Atlas = require 'zelda.atlas'
local spriteNames = Atlas.spriteNames

local animals = spriteNames:filter(function(name)
	return name:match'^animal_'
end):mapi(function(sprite)
	local animalType = {}
	
	local colorMatrix = matrix_ffi({4,4},'float'):zeros()
		:setRotate(
			.2 * (math.random() - .5)*2*math.pi,
			1 + .2 * (math.random() - .5),
			1 + .2 * (math.random() - .5),
			1 + .2 * (math.random() - .5))
	animalType.colorMatrix = colorMatrix
	
	animalType.name = sprite:match'^animal_(.*)$'
	animalType.sprite = sprite
	animalType.cost = 10

	-- [[ pick a random seq
	-- TODO do this here or on obj ctor?
	do
		local prefix = 'sprites/'..sprite..'/'
		local seqnames = Atlas.getAllKeys(prefix)
		animalType.seq = seqnames:pickRandom():sub(#prefix+1):match'^(.*)%.png$'
	end
	--]]

	-- TODO ... classname and serialization
	-- same with zelda.plants
	-- needs to store the plantType/animalType
	animalType.objClass = require 'zelda.obj.animal':subclass(animalType)
	animalType.objClass.animalType = animalType
	return animalType
end)

print('got', #animals, 'animals')

return animals
