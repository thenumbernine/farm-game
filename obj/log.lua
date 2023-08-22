local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local LogItem = Obj:subclass()

LogItem.name = 'Log'
LogItem.sprite = 'log'
LogItem.useGravity = false
LogItem.collidesWithTiles = false

-- hmm how do I say 'test touch' but not 'test movement collision' ?
-- quake engines did touchtype_item ...
--LogItem.collidesWithObjects = false	

LogItem.min = vec3f(-.3, -.3, -.3)
LogItem.max = vec3f(.3, .3, .3)

function LogItem:touch(other)
	if other.addItem then
		other:addItem(LogItem)
		self:remove()
	end
end

return LogItem
