local table = require 'ext.table'
local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'farmgame.obj.obj'

local Workbench = require 'farmgame.obj.placeableobj'(Obj):subclass()
Workbench.classname = ...

Workbench.name = 'Workbench'
Workbench.sprite = 'workbench'

function Workbench:interactInWorld(player)
	local options = table()
	for _,tilename in ipairs{'Dirt', 'Wood', 'Stone'} do
		for _,shapename in ipairs{'Half', 'Slope_1_1', 'Slope_1_2'} do
			options:insert{
				input = {
					{
						class = require('farmgame.item.voxel.'..tilename),
						count = 1,
					},
				},
				output = {
					{
						class = require('farmgame.item.voxel.'..tilename..'_'..shapename),
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
