-- plantTypes table
-- TODO planttypes.lua ?
-- used with item/seeds .plant, obj/seededground .plant etc
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local vec4f = require 'vec-ffi.vec4f'
local table = require 'ext.table'

--[[
name = name
growType
	- sapling = grow to a tree
	- seeds = grow to a bush
	- seeds = grow to a vine
	- seeds = grow to a grain/hay/wheat

TODO growType->plantType:
	

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
	
	local color = vec3f(math.random(), math.random(), math.random()):normalize()
	plantType.color = vec4f(color.x, color.y, color.z, 1)

	plantType.sprite = table{
		{weight=1, sprite='faketree'},
		{weight=6, sprite='fakebush'},
		{weight=12, sprite='fakeplant'},
	}:pickWeighted().sprite

	-- pick a random sequence <-> plant sub-type
	local anim = require 'zelda.anim'
	local sprite = assert(anim[plantType.sprite])
	local seqnames = table.keys(sprite)
	local seqname = seqnames:pickRandom()
	plantType.seq = seqname

	local seq = assert(sprite[seqname])
	local frame = assert(seq[1])
	local tex = assert(frame.tex, "failed to find frame for sprite "..plantType.sprite.." seq "..seqname)
	plantType.drawSize = vec2f(tex.width, tex.height) / 20

	-- TODO drawSize should be proportional to the sprite used
	if plantType.sprite == 'faketree' then
		--plantType.drawSize = vec2f(128, 128)/20
		plantType.numLogs = 10
		plantType.hpMax = 5
		plantType.inflictTypes = {axe=true}
		plantType.shakeOnHit = true
		plantType.tipOnDie = true
	elseif plantType.sprite == 'fakebush' then
		--plantType.drawSize = vec2f(64, 64)/20
		plantType.numLogs = 2
		plantType.inflictTypes = {axe=true, sword=true}
		plantType.shakeOnHit = true
		plantType.tipOnDie = true
	else
		--plantType.drawSize = vec2f(32, 32)/20
		plantType.inflictTypes = {axe=true, sword=true}
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
