local table = require 'ext.table'
local matrix_ffi = require 'matrix.ffi'

local Atlas = require 'zelda.atlas'
local spriteNames = Atlas.spriteNames
local anim = require 'zelda.anim'

local animals = spriteNames:filter(function(name)
	return name:match'^animal_'
end):mapi(function(spriteName)
	local animalType = {}
	
	local colorMatrix = matrix_ffi({4,4},'float'):zeros()
		:setRotate(
			.2 * (math.random() - .5)*2*math.pi,
			1 + .2 * (math.random() - .5),
			1 + .2 * (math.random() - .5),
			1 + .2 * (math.random() - .5))
	animalType.colorMatrix = colorMatrix
	
	animalType.name = spriteName:match'^animal_(.*)$'
	animalType.sprite = spriteName
	animalType.cost = 10

	-- [[ pick a random seq
	-- TODO do this here or on obj ctor?
	local spritePrefix = 'sprites/'..spriteName..'/'
	local seqnames = Atlas.getAllKeys(spritePrefix)
	local seqname = seqnames:pickRandom():sub(#spritePrefix+1):match'^(.*)%.png$'
	animalType.seq = seqname
	--]]

	local sprite = assert(anim[spriteName])
	local seq = assert(sprite[seqname])
	local frame = assert(seq[1])
	local framesize = assert(frame.atlasTcSize)
	animalType.drawSize = framesize / 20

	-- TODO ... classname and serialization
	-- same with zelda.plants
	-- needs to store the plantType/animalType
	animalType.objClass = require 'zelda.obj.animal':subclass(animalType)
	animalType.objClass.animalType = animalType
	return animalType
end)

print('got', #animals, 'animals')

return animals
