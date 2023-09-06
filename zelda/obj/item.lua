--[[
ok every pick up able object needs an item form
so this is going to hold that item form
it'll hold the class (and count?) and work as a wrapper 

hmmmm tempting to make this for *all* objs
because, otherwise, the trend becomes making separate obj/ and item/ for *all* pick-up-able objects
so how about making Item here a behavior instead of a superclass?
and then give a ctor arg spawn-in-item-form? 
but that would mean special conditioning for each object whether it's in item-form or world-form ...
hmm maybe I don't need obj/ and item/ folders for all objects?
maybe I can just use the item/ folder for objs that *only* have an item-form (like weapons) but not world-form (i.e. beds)
--]]
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local vec4f = require 'vec-ffi.vec4f'
local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local Item = Obj:subclass()
Item.classname = 'zelda.obj.item'

Item.name = 'Item'

Item.useGravity = false

Item.collidesWithTiles = false
-- hmm how do I say 'test touch' but not 'test movement collision' ?
-- quake engines did touchtype_item ...
Item.collidesWithObjects = false	-- won't block other objects
Item.itemTouch = true			-- will trigger touch of other moving objects, but won't push.

Item.min = box3f{
	min = {-.3, -.3, 0},
	max = {.3, .3, .6},
}

Item.drawSize = vec2f(.8, .8)
Item.drawCenter = vec3f(.5, .5, 0)
Item.rotation = math.pi * .5
Item.disableBillboard = true
Item.spritePosOffset = vec3f(0, 0, .5)

function Item:init(args)
	Item.super.init(self, args)

	self.itemClass = assert(args.itemClass)
	
	-- TODO get rid of?
	self.itemCount = args.itemCount or 1
	
	-- use the same sprite? or a dif one?
	self.sprite = self.itemClass.sprite
	self.seq = self.itemClass.seq
	if self.itemClass.colorMatrix then
		self.colorMatrix:copy(self.itemClass.colorMatrix)
	end
end

function Item:touch(other)
	if other.addItem
	and not other.dead
	and not other.removeFlag
	then
		if other:addItem(self.itemClass, self.itemCount) then
			self:remove()
		end
	end
end

return Item
