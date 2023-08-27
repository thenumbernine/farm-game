-- plants table
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
	
	return plant
end)

print('got', #plants, 'plants')
return plants
