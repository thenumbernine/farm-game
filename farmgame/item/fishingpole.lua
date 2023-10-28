local Item = require 'farmgame.item.item'

local FishingPole = Item:subclass()
FishingPole.classname = 'farmgame.item.fishingpole'
FishingPole.name = 'fishingpole'
FishingPole.sprite = 'item'
FishingPole.seq = 'fishingpole'

-- static method, 'self' is subclass
function FishingPole:useInInventory(player)
	local game = player.game
	local appPlayer = player.appPlayer
	if not (appPlayer.keyPress.useItem and not appPlayer.keyPressLast.useItem) then return end
	-- TODO here, when we cast, gotta draw the fishing line ...
	-- in fact, player in general needs some client-side modifications to his rendering
	--[[
	fishing states:
	- not fishing
	- casting (animation)
	- line is out
	- line is being tugged (from fish or bottom or snag ...)
	- fish is on
	
	I could code all fishing as a coroutine right here
	buuut
	coroutines aren't so easy to serialize
	and its locals are harder to access/debug than obj.player state vars
	so ...
	--]]
	if not player.fishing then
		player.fishing = 'casting'
		player.fishingCastTime = game.time
print'CASTING'	
	--else
	--	player.fishing = nil
	-- handled in player update
	end
end

return FishingPole 
