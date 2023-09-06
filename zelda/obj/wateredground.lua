local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'
local Game = require 'zelda.game'

local WateredGround = Obj:subclass()
WateredGround.classname = 'zelda.obj.wateredground'
WateredGround.name = 'WateredGround' 

WateredGround.sprite = 'watered'
WateredGround.disableBillboard = true
WateredGround.drawCenter = vec3f(.5, .5, 0)

WateredGround.useGravity = false
WateredGround.collidesWithTiles = false
WateredGround.collidesWithObjects = false
WateredGround.bbox = box3f{
	min = {-.3, -.3, -.001},
	max = {.3, .3, .001},
}
WateredGround.spritePosOffset = vec3f(0,0,.002)

-- TODO how to grow plants
WateredGround.removeDuration = Game.secondsPerDay - Game.secondsPerHour

return WateredGround 
