local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local HoedGround = Obj:subclass()

HoedGround.name = 'HoedGround'

HoedGround.sprite = 'hoed'
HoedGround.useGravity = false
HoedGround.collidesWithTiles = false
HoedGround.min = vec3f(-.3, -.3, -.001)
HoedGround.max = vec3f(.3, .3, .001)

return HoedGround 
