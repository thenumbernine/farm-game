-- plants table
-- used with item/seeds .plant, obj/seededground .plant etc
local table = require 'ext.table'

--[[
name = name
growType
	- sapling = grow to a tree
	- seeds = grow to a bush
	- seeds = grow to a vine
	- seeds = grow to a grain/hay/wheat
cost = how much to buy/sell
--]]
local path = require 'ext.path'
local string = require 'ext.string'
local plants = string.split(string.trim(path'plants.csv':read()), '\n'):mapi(function(name)
	return {name=name, growType='seeds', cost=10}
end)

return plants
