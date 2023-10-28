local Obj = require 'farmgame.obj.obj'
local Door = Obj:subclass()
Door.classname = 'farmgame.obj.door'
Door.name = 'door'
Door.sprite = 'waterd'	-- todo ...
Door.useGravity = false
Door.collidesWithTiles = false
Door.collidesWithObjects = false
Door.itemTouch = true	-- non-solid, touches solid

function Door:init(args)
	Door.super.init(self, args)
	-- dest in game.maps
	self.destMap = assert(args.destMap)
	self.destMapPos = assert(args.destMapPos)
end

function Door:touch(other)
	if other.appPlayer then
		if not self.destMap then
			-- TODO how about a 'nextTouch' time?
print("couldn't enter map")
		else
			self.game.threads:addMainLoopCall(function()
				other.appPlayer:setMap(self.destMap, self.destMapPos)
			end)
		end
	end
end

return Door
