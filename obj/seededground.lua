local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local SeededGround = Obj:subclass()

SeededGround.sprite = 'seededground'
SeededGround.useGravity = false
SeededGround.collidesWithTiles = false
SeededGround.min = vec3f(-.3, -.3, -.001)
SeededGround.max = vec3f(.3, .3, .001)

return SeededGround 
