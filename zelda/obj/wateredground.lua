local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local WateredGround = Obj:subclass()
WateredGround.name = 'WateredGround' 

WateredGround.sprite = 'watered'
WateredGround.useGravity = false
WateredGround.collidesWithTiles = false
WateredGround.collidesWithObjects = false
WateredGround.bbox = box3f{
	min = {-.3, -.3, -.001},
	max = {.3, .3, .001},
}

return WateredGround 
