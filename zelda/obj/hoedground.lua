local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'
local Game = require 'zelda.game'

local HoedGround = Obj:subclass()
HoedGround.classname = 'zelda.obj.hoedground'

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
HoedGround.spritePosOffset = vec3f(0,0,.001)

-- TODO how to gauge plant growth / hoed ground / watered ground ...
HoedGround.removeDuration = Game.secondsPerDay - Game.secondsPerHour

return HoedGround 
