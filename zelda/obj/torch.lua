local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local ffi = require 'ffi'
local Obj = require 'zelda.obj.obj'

local Torch = require 'zelda.obj.placeableobj'(Obj):subclass()

Torch.classname = 'zelda.obj.torch'
Torch.name = 'torch'
Torch.sprite = 'torch'
Torch.useGravity = false
Torch.collidesWithTiles = false
Torch.collidesWithObjects = false
Torch.drawSize = vec2f(.25, .5)
--[[
Torch.bbox = box3f{
	min = vec3f(-.1, -.1, -.1),
	max = vec3f(.1, .1, .1),
}
--]]

--[[
obj.light ...
... upon :setPos and changing tiles ...
... change the light
and then do the ol' flood-fill + falloff
--]]
Torch.light = ffi.C.MAX_LUM

return Torch
