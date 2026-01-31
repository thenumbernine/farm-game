local table = require 'ext.table'
local assert = require 'ext.assert'
local vec4x4f = require 'vec-ffi.vec4x4f'

local Atlas = require 'farmgame.atlas'
local spriteNames = Atlas.spriteNames
local anim = require 'farmgame.anim'

local animals = spriteNames:filter(function(name)
	return name:match'^animal_'
end):mapi(function(spriteName)
	local animalType = {}
	
	local colorMatrix = vec4x4f()
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

	local sprite = assert.index(anim, spriteName)
	local seq = assert.index(sprite, seqname)
	local frame = assert.index(seq, 1)
	local framesize = assert.index(frame, 'atlasTcSize')
	animalType.drawSize = framesize / 20

	-- TODO ... classname and serialization
	-- same with farmgame.plants
	-- needs to store the plantType/animalType
	animalType.objClass = require 'farmgame.obj.animal':subclass(animalType)
	animalType.objClass.animalType = animalType
	return animalType
end)

print('got', #animals, 'animals')

return animals
