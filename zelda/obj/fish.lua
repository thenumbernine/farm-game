local Obj = require 'zelda.obj.obj'
local Fish = Obj:subclass()

Fish.classname = 'zelda.obj.fish'
Fish.name = 'fish'
Fish.sprite ='fish'

-- TODO all fish subclasses / pick a fish
-- or merge this with animals?
do
	local prefix = 'sprites/fish/'
	local seqnames = require 'zelda.atlas'.getAllKeys(prefix)
	local seqname = seqnames:pickRandom():sub(#prefix+1):match'^(.*)%.png$'
	Fish.seq = seqname
end

-- just like fruit/veg, you have to subclass to specify these
-- another reason I should just make inventory story objects, not Item's
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
