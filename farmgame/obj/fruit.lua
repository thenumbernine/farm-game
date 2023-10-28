--[[
ok farmgame.obj.plant is the main plant class
for veg plants that you pull out, the class itself is what is picked and eaten
but for bushes and trees that drop fruit, this class is what is pulled out and eaten.
but while the tree is growing, it has to 
--]]
local vec2f = require 'vec-ffi.vec2f'
local Obj = require 'farmgame.obj.obj'

local Fruit = Obj:subclass()
Fruit.classname = 'farmgame.obj.fruit'
Fruit.name = 'fruit'
Fruit.sprite = 'fruit'
Fruit.seq = '1'	-- TODO multiple classes & pick randomly, like farmgame.obj.plant
Fruit.useGravity = false
Fruit.collidesWithTiles = false
Fruit.collidesWithObjects = false
Fruit.useSeeThru = false
Fruit.itemTouch = true
Fruit.drawSize = vec2f(.5,.5)

local Game = require 'farmgame.game'
Fruit.growDuration = Game.secondsPerDay

function Fruit:update(dt)
	-- don't do physics update
	--Fruit.super.update(self, dt)
	local game = self.game
	local growTime = game.time - self.createTime
	local growFrac = growTime / self.growDuration
	self.drawSize:set(
		self.class.drawSize.x * math.min(growFrac, 1),
		self.class.drawSize.y * math.min(growFrac, 1))
	if growFrac > 1 then
		self.ready = true
	end
end

-- static method (so self = subclass)
-- also in Plant (for vegs)
function Fruit:useInInventory(player)
	-- only run when the player pushes the button
	-- TODO maybe the push vs hold functionality should be moved to the player code?
	local appPlayer = player.appPlayer
	if appPlayer.keyPress.useItem and appPlayer.keyPressLast.useItem then return end

	-- heal and eat
	assert(player:removeSelectedItem() == self)

	player.hp = math.min(player.hp + self.hpGiven, player.hpMax)
	player.food = math.min(player.food + self.foodGiven, player.foodMax)
end

return Fruit
