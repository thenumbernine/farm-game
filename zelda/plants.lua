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
local plants = string.split(string.trim(path'plants.csv':read()), '\n'):mapi(function(name)
	local color = vec3f(math.random(), math.random(), math.random()):normalize()
	return {name=name, growType='seeds', cost=10, color=vec4f(color.x, color.y, color.z, 1)}
end)

return plants
