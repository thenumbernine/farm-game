local vec2f = require 'vec-ffi.vec2f'
local Obj = require 'zelda.obj.obj'

local NPC = Obj:subclass()
NPC.name = 'NPC'
NPC.sprite = 'link'
NPC.drawSize = vec2f(1,1.5)

function NPC:interactInWorld(player)
	-- TODO popup speech / store stuff
	print'talking to npc'
end

return NPC
