local Obj = require 'zelda.obj.obj'

local HoedGround = Obj:subclass()

HoedGround.sprite = 'hoed'
HoedGround.useGravity = false
HoedGround.collidesWithTiles = false

return HoedGround 
