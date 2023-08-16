local Obj = require 'zelda.obj.obj'

local SeededGround = Obj:subclass()

SeededGround.sprite = 'seededground'
SeededGround.useGravity = false
SeededGround.collidesWithTiles = false

return SeededGround 
