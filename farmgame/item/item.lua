--[[
here's the superclass of all items that don't have a world-form, only an item-form
can't think of what they really all need in common
--]]

local class = require 'ext.class'
local table = require 'ext.table'

local Item = class()
Item.classname = ...

--[[
TODO this matches Obj.toItem
however this is a static method atm.
except unlike Obj.toItem, this needs .map and .pos specified
--]]
function Item:toItemObj(args)
	assert(args.pos)
	assert(args.map):newObj(table({
		class = require 'farmgame.obj.item',
		itemClass = self.class,
	}, args))
end

return Item
