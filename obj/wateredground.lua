local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local WateredGround = Obj:subclass()
WateredGround.name = 'WateredGround' 

WateredGround.sprite = 'watered'
WateredGround.useGravity = false
WateredGround.collidesWithTiles = false
WateredGround.min = vec3f(-.3, -.3, -.001)
WateredGround.max = vec3f(.3, .3, .001)

return WateredGround 
