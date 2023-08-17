local Obj = require 'zelda.obj.obj'

local WateredGround = Obj:subclass()

WateredGround.sprite = 'watered'
WateredGround.useGravity = false
WateredGround.collidesWithTiles = false

return WateredGround 
