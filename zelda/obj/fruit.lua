--[[
ok zelda.obj.plant is the main plant class
for veg plants that you pull out, the class itself is what is picked and eaten
but for bushes and trees that drop fruit, this class is what is pulled out and eaten.
but while the tree is growing, it has to 
--]]
local vec2f = require 'vec-ffi.vec2f'
local Obj = require 'zelda.obj.obj'

local Fruit = Obj:subclass()
Fruit.classname = 'zelda.obj.fruit'
Fruit.name = 'fruit'
Fruit.sprite = 'fruit'
Fruit.seq = '1'	-- TODO multiple classes & pick randomly, like zelda.obj.plant
Fruit.useGravity = false
Fruit.collidesWithTiles = false
Fruit.collidesWithObjects = false
Fruit.useSeeThru = false
Fruit.itemTouch = true
Fruit.drawSize = vec2f(.5,.5)

return Fruit
