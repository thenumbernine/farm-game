local Obj = require 'zelda.obj.obj'

local Hoed = Obj:subclass()

Hoed.sprite = 'hoed'
Hoed.useGravity = false
Hoed.collidesWithTiles = false

return Hoed 
