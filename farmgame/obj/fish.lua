--[[
TODO move Fish into farmgame.obj.animal ?
but also, don't create fish objs until you actually go fishing ...
then they're in-map, and make them go away after a while .. ?

because fish+animals
	- need food / constantly eat
	- need to breathe ... tho i don't have this in either
	- ... rewrite animal movement to include swim, fly, and walk
		- swimming+breathing ... = swim on top of water?
--]]
local Obj = require 'farmgame.obj.obj'
local Fish = Obj:subclass()

Fish.classname = ...
Fish.name = 'fish'
Fish.sprite ='fish'

-- TODO all fish subclasses / pick a fish
-- or merge this with animals?
do
	local prefix = 'sprites/fish/'
	local seqnames = require 'farmgame.atlas'.getAllKeys(prefix)
	local seqname = seqnames:pickRandom():sub(#prefix+1):match'^(.*)%.png$'
	Fish.seq = seqname
end

-- just like fruit/veg, you have to subclass to specify these
-- another reason I should just make inventory story objects, not Item's
-- TODO instead how about a separate 'meat' item ... then fish / animal meat?
Fish.foodGiven = 2
Fish.hpGiven = 2

-- same as fruit / plant-vegetable
function Fish:useInInventory(player)
	local appPlayer = player.appPlayer
	if appPlayer.keyPress.useItem and appPlayer.keyPressLast.useItem then return end
	assert(player:removeSelectedItem() == self)
	player.hp = math.min(player.hp + self.hpGiven, player.hpMax)
	player.food = math.min(player.food + self.foodGiven, player.foodMax)
end

return Fish
