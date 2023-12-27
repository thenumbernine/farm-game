local NPC = require 'farmgame.obj.npc'

local Clerk = NPC:subclass()

Clerk.classname = ...

function Clerk:init(args)
	Clerk.super.init(self, args)

	self.storeOptions = assert(args.storeOptions, "clerk store needs options")
end

function Clerk:interactInWorld(player)
	player.appPlayer:storePrompt(self.storeOptions)
end

return Clerk
