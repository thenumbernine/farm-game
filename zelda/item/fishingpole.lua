local Item = require 'zelda.item.item'

local FishingPole = Item:subclass()
FishingPole.classname = 'zelda.item.fishingpole'
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
