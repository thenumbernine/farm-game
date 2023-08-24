local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local SeededGround = Obj:subclass()

SeededGround.sprite = 'seededground'
SeededGround.useGravity = false
SeededGround.collidesWithTiles = false
SeededGround.collidesWithObjects = false
SeededGround.bbox = box3f{
	min = {-.3, -.3, -.001},
	max = {.3, .3, .001},
}

return SeededGround 
