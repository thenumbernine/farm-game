--[[
ok every pick up able object needs an item form
so this is going to hold that item form
it'll hold the class (and count?) and work as a wrapper 

hmmmm tempting to make this for *all* objs
--]]
local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local Item = Obj:subclass()

Item.name = 'Item'

Item.useGravity = false

Item.collidesWithTiles = false
-- hmm how do I say 'test touch' but not 'test movement collision' ?
-- quake engines did touchtype_item ...
--Item.collidesWithObjects = false	

Item.min = box3f{
	min = {-.3, -.3, 0},
	max = {.3, .3, .6},
}

function Item:init(args)
	Item.super.init(self, args)

	self.itemClass = assert(args.itemClass)
	self.itemCount = args.itemCount or 1
	
	-- use the same sprite? or a dif one?
	self.sprite = self.itemClass.sprite
	--self.sprite = self.itemClass.itemSprite
end

function Item:touch(other)
	if other.addItem
	and not other.dead
	and not other.removeFlag
	then
		other:addItem(self.itemClass, self.itemCount)
		self:remove()
	end
end

return Item
