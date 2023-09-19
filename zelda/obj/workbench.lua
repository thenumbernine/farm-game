local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local Workbench = require 'zelda.obj.placeableobj'(Obj):subclass()
Workbench.classname = 'zelda.obj.workbench'

Workbench.name = 'Workbench'
Workbench.sprite = 'workbench'

function Workbench:interactInWorld(player)
	player.appPlayer:workbenchPrompt()
end

return Workbench
