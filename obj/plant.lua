local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local Plant = Obj:subclass()

Plant.name = 'Plant'

Plant.sprite = 'plant1'
Plant.useGravity = false	-- true?
Plant.collidesWithTiles = false	-- this slows things down a lot.  so just turn off gravity and dont test with world.
Plant.collidesWithObjects = false --?

Plant.canBeChoppedDown = true

function Plant:init(args, ...)
	Plant.super.init(self, args, ...)
	self.numLogs = args.numLogs
end

return Plant 
