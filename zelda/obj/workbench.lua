local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local Workbench = Obj:subclass()
Workbench.classname = 'zelda.obj.workbench'

Workbench.name = 'Workbench'
Workbench.sprite = 'workbench'

function Workbench:interactInWorld(player)
	local appPlayer = player.appPlayer
	appPlayer:workbenchPrompt()
end

return Workbench
