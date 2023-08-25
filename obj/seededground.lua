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

function SeededGround:init(args)
	SeededGround.super.init(self, args)

	-- is a class, subclass of item/seeds
	self.seedType = args.seedType
end

return SeededGround 
