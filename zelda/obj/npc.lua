local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local NPC = Obj:subclass()
NPC.classname = 'zelda.obj.npc'

NPC.name = 'NPC'
NPC.sprite = 'link'
NPC.drawSize = vec2f(1, 1.5)
NPC.drawCenter = vec3f(.5, 1, 0)

NPC.bbox = box3f{
	min = {-.3, -.3, 0},
	max = {.3, .3, 1.5},
}

return NPC
