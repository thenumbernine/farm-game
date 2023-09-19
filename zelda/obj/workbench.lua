local table = require 'ext.table'
local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local Workbench = require 'zelda.obj.placeableobj'(Obj):subclass()
Workbench.classname = 'zelda.obj.workbench'

Workbench.name = 'Workbench'
Workbench.sprite = 'workbench'

function Workbench:interactInWorld(player)
	local options = table()
	for _,tilename in ipairs{'Dirt', 'Wood', 'Stone'} do
		for _,shapename in ipairs{'Slope45', 'Half'} do
			options:insert{
				input = {
					{
						class = require('zelda.item.voxel.'..tilename),
						count = 1,
					},
				},
				output = {
					{
						class = require('zelda.item.voxel.'..tilename..'_'..shapename),
						count = 1,
					},
				}

			}
		end
	end
	-- TODO craft slopes? or dig slopes with a shovel?
	player.appPlayer:craftPrompt(options)
end

return Workbench
