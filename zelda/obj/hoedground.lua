local vec2f = require 'vec-ffi.vec2f'
local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local HoedGround = Obj:subclass()

HoedGround.name = 'HoedGround'

HoedGround.sprite = 'hoed'
HoedGround.disableBillboard = true
HoedGround.drawCenter = vec2f(.5, .5)

HoedGround.useGravity = false
HoedGround.collidesWithTiles = false
HoedGround.collidesWithObjects = false
HoedGround.bbox = box3f{
	min = {-.3, -.3, -.001},
	max = {.3, .3, .001},
}

return HoedGround 
