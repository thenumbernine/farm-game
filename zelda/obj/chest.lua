local box3f = require 'vec-ffi.box3f'
local Obj = require 'zelda.obj.obj'

local Chest = require 'zelda.obj.placeableobj'(Obj):subclass()
Chest.classname = 'zelda.obj.chest'

Chest.name = 'chest'
Chest.sprite = 'chest'

Chest.useGravity = false
Chest.collidesWithTiles = false
Chest.bbox = box3f{
	min = {-.5, -.5, 0},
	max = {.5, .5, .5},
}

-- same as Player
Chest.numInvItems = 48

function Chest:init(args)
	Chest.super.init(self, args)

	-- same with player
	self.items = {}
end

function Chest:interactInWorld(player)
	player.appPlayer.chestOpen = self
	player.appPlayer.invOpen = true
end

return Chest
