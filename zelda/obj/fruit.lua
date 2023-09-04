--[[
ok zelda.obj.plant is the main plant class
for veg plants that you pull out, the class itself is what is picked and eaten
but for bushes and trees that drop fruit, this class is what is pulled out and eaten.
but while the tree is growing, it has to 
--]]
local Obj = require 'zelda.obj'

local Fruit = Obj:subclass()
Fruit.classname = 'zelda.obj.fruit'

return Fruit
