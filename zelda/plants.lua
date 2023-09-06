-- plantTypes table
-- TODO planttypes.lua ?
-- used with item/seeds .plant, obj/seededground .plant etc
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local matrix_ffi = require 'matrix.ffi'
local table = require 'ext.table'

--[[
name = name
growType
	- sapling = grow to a tree
	- seeds = grow to a bush
	- seeds = grow to a vine
	- seeds = grow to a grain/hay/wheat

	- tree = produces fruit, seeds, leaves
		apricot
		cherry
		banana
		mango
		orange
		peach
		apple
		pomegranate
		figs
		tea
		SPRITES: seed-in-ground -> tree, fruit, seed, leaf
	
	- fern = pull up immediately
		SPRITES: fern-growing.  (spores not seeds)

	- bush = grows to a bush, then periodically gives off fruit (overlay sprite of that?)
		ex: coffee
			strawberry
			blueberry
		SPRITES: seed-in-ground -> bush, seed

	- stalk / vine = grows to a vine, overlay some fruit on it (or have a separate with-fruit sprite?)
		ex: green beans
			corn
			hops
			peppers
			tomato
			cranberries
			eggplant
			grape
			cactus
		SPRITES: seed-in-ground -> stalk, fruit, seed

	- vegetable = grows to a veg, then pull up to get the veg leaving nothing behind
		ex:  "cole" crops: broccoli, Brussels sprouts, cabbage, collard greens
			bulbs: garlic
			parsnip, carrot, parsley
			tubers: potatos
			stalks: rhubarb
			melon
			radish
			red cabbage
			artichoke
			beet
			bok choy
			pumpkin
			yam
			pineapple
			taro
		SPRITES: seed-in-ground -> veg, refine veg -> seed
	
	- leafs/grain/hay/wheat = grows to a veg, harvest with scythe
		harvest via 
			- 1) reaping via scythe
			- 2) threshing
		ex: 
			kale ... or really?
			rice
			wheat
			amaranth
		SPRITES: seed-in-ground -> veg, refine veg -> seed (same as vegetable but scythe to harvest)

	- flower = grows to a flower
		ex: jazz
			tulip
			poppy
			summer spangle
			sunflower
			fairy rose
		SPRITES: seed-in-ground -> flower, refine flower -> seed

cost = how much to buy/sell
--]]
local path = require 'ext.path'
local string = require 'ext.string'

local plantcsv = require 'csv'.file'plants.csv'
local fields = plantcsv.rows:remove(1)
plantcsv:setColumnNames(fields)

local plantTypes = plantcsv.rows:mapi(function(row)
	local plantType = {}
	for _,f in ipairs(fields) do
		plantType[f] = row[f]
	end

	-- TODO
	-- create the plant-obj-class and plant-fruit-class (and plant-seed-class)
	-- ... in zelda/plants.lua
	-- then these would be baked into classes 
	-- and not need to be set here

	-- TODO plantType
	plantType.growType = 'seeds'
	plantType.cost = 10
	
	local colorMatrix = matrix_ffi({4,4},'float'):zeros()
		:setRotate(
			math.random()*2*math.pi,
			1 + .2 * (math.random() - .5),
			1 + .2 * (math.random() - .5),
			1 + .2 * (math.random() - .5))
	plantType.colorMatrix = colorMatrix

	plantType.sprite = table{
		{weight=1, sprite='tree'},	-- grows slowly, maybe makes fruit every so many days
		{weight=5, sprite='bush'},	-- grows medium, also fruit
		{weight=5, sprite='plant'},	-- grows fast, scythe to get veg
		{weight=10, sprite='vegetable'},	-- grows fast, pull up to get veg
	}:pickWeighted().sprite

	-- pick a random sequence <-> plant sub-type
	local anim = require 'zelda.anim'
	local sprite = assert(anim[plantType.sprite])
	local seqnames = table.keys(sprite)
	local seqname = seqnames:pickRandom()
	plantType.seq = seqname

	local seq = assert(sprite[seqname])
	local frame = assert(seq[1])
	local framesize = assert(frame.atlasTcSize)
	plantType.drawSize = framesize / 20

	local Game = require 'zelda.game'

	local fruitSeqNames = table.keys(anim.fruit)
	local fruitClasses = table()
	local Fruit = require 'zelda.obj.fruit'
	fruitClasses:insert(
		Fruit:subclass{
			hpGiven = math.random(3,5),
			foodGiven = math.random(3,5),
			seq = fruitSeqNames:pickRandom(),
		}
	)
	

	if plantType.sprite == 'tree' then
		plantType.numLogs = 10
		plantType.hpMax = 5
		plantType.inflictTypes = {axe=true}
		plantType.shakeOnHit = true
		plantType.tipOnDie = true
		plantType.growDuration = Game.secondsPerYear

		if math.random() < .3 then
			plantType.fruitDuration = 3 * Game.secondsPerDay
			plantType.fruitClass = fruitClasses:pickRandom()
		end
	elseif plantType.sprite == 'bush' then
		plantType.numLogs = 2
		plantType.inflictTypes = {axe=true, sword=true}
		plantType.shakeOnHit = true
		plantType.tipOnDie = true
		plantType.growDuration = Game.secondsPerWeek
		
		if math.random() < .3 then
			plantType.fruitDuration = 4 * Game.secondsPerDay
			-- TODO mutilpe? grafting?
			plantType.fruitClass = fruitClasses:pickRandom()
		end
	else	-- plant/veg
		plantType.inflictTypes = {axe=true, sword=true}
		plantType.growDuration = Game.secondsPerWeek
		if plantType.sprite == 'vegetable' then
			plantType.drawSize = plantType.drawSize * .5
			plantType.drawCenter = vec3f(.5, .5, 0)
		end
		plantType.hpGiven = math.random(3,5)
		plantType.foodGiven = math.random(3,5)
	end

	plantType.objClass = require 'zelda.obj.plant':subclass(plantType)
	plantType.objClass.plantType = plantType

	plantType.seedClass = require 'zelda.item.seeds':subclass{
		name = plantType.name..' '..plantType.growType,
		plantType = plantType,
	}

	return plantType
end)

print('got', #plantTypes, 'plantTypes')
return plantTypes
