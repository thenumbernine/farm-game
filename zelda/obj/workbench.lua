local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local Workbench = require 'zelda.obj.placeableobj'(Obj):subclass()
Workbench.classname = 'zelda.obj.workbench'

Workbench.name = 'Workbench'
Workbench.sprite = 'workbench'

function Workbench:interactInWorld(player)
	player.appPlayer:craftPrompt{
		-- TODO craft slopes? or dig slopes with a shovel?
		{
			input = {
				{
					class = require 'zelda.item.voxel.Dirt',
					count = 1,
				},
			},
			output = {
				{
					class = require 'zelda.item.voxel.Dirt_Slope45',
					count = 1,
				},
				{
					class = require 'zelda.item.voxel.Dirt_Half',
					count = 1,
				},
			},
		},
		{
			input = {
				{
					class = require 'zelda.item.voxel.Wood',
					count = 1,
				},
			},
			output = {
				{
					class = require 'zelda.item.voxel.Wood_Slope45',
					count = 1,
				},
				{
					class = require 'zelda.item.voxel.Wood_Half',
					count = 1,
				},
			},
		},
		{
			input = {
				{
					class = require 'zelda.item.voxel.Stone',
					count = 1,
				},
			},
			output = {
				{
					class = require 'zelda.item.voxel.Stone_Slope45',
					count = 1,
				},
				{
					class = require 'zelda.item.voxel.Stone_Half',
					count = 1,
				},
			},
		},
	}
end

return Workbench
