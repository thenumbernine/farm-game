local box3f = require 'vec-ffi.box3f'
local Obj = require 'farmgame.obj.obj'

local Chest = require 'farmgame.obj.placeableobj'(Obj):subclass()
Chest.classname = ...

Chest.name = 'chest'
Chest.sprite = 'chest'

Chest.useGravity = false
Chest.collidesWithTiles = false

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

function Chest:damage(amount, attacker, inflicter)
	-- don't break if we have anything inside
	for i=1,self.numInvItems do
		if self.items[i] ~= nil then return end
	end

	return Chest.super.damage(self, amount, attacker, inflicter)
end

return Chest
