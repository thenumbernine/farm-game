local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local Plant = Obj:subclass()

Plant.name = 'Plant'

Plant.sprite = 'plant1'
Plant.useGravity = false	-- true?
Plant.collidesWithTiles = false
--Plant.collidesWithObjects = false --?

return Plant 
