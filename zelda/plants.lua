-- plants table
-- TODO planttypes.lua ?
-- used with item/seeds .plant, obj/seededground .plant etc
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
		SPRITES: seed-in-ground -> veg, seed
	
	- leafs/grain/hay/wheat = grows to a veg, harvest with scythe
		harvest via 
			- 1) reaping via scythe
			- 2) threshing
		ex: 
			kale ... or really?
			rice
			wheat
			amaranth
		SPRITES: seed-in-ground -> veg, seed (same as vegetable but scythe to harvest)

	- flower = grows to a flower
		ex: jazz
			tulip
			poppy
			summer spangle
			sunflower
			fairy rose
		SPRITES: seed-in-ground -> flower

cost = how much to buy/sell
--]]
local path = require 'ext.path'
local string = require 'ext.string'

local plantcsv = require 'csv'.file'plants.csv'
local fields = plantcsv.rows:remove(1)
plantcsv:setColumnNames(fields)

local plants = plantcsv.rows:mapi(function(row)
	local plant = {}
	for _,f in ipairs(fields) do
		plant[f] = row[f]
	end
	
	plant.growType = 'seeds'
	plant.cost = 10
	
	local color = vec3f(math.random(), math.random(), math.random()):normalize()
	plant.color = vec4f(color.x, color.y, color.z, 1)

	plant.sprite = table{
		{weight=1, sprite='faketree'},
		{weight=6, sprite='fakebush'},
		{weight=12, sprite='fakeplant'},
	}:pickWeighted().sprite

	return plant
end)

print('got', #plants, 'plants')
return plants
