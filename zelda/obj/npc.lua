local vec2f = require 'vec-ffi.vec2f'
local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local NPC = Obj:subclass()
NPC.name = 'NPC'
NPC.sprite = 'link'
NPC.drawSize = vec2f(1, 1.5)
NPC.drawCenter = vec2f(.5, 1)

NPC.bbox = box3f{
	min = {-.3, -.3, 0},
	max = {.3, .3, 1.5},
}

return NPC
