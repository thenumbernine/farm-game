local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local HoedGround = Obj:subclass()

HoedGround.name = 'HoedGround'

HoedGround.sprite = 'hoed'
HoedGround.useGravity = false
HoedGround.collidesWithTiles = false
HoedGround.collidesWithObjects = false
HoedGround.bbox = box3f{
	min = {-.3, -.3, -.001},
	max = {.3, .3, .001},
}

return HoedGround 
