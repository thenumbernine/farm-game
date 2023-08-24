local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local Obj = require 'zelda.obj.obj'

--[[
TODO placeable item ...
... two kinds?
1. place item <-> change map data
2. place item <-> place object

TODO
- object represents the physical thing in the world
	use an ax or something to disconnect from world and become an item that you touch to pick up.
- object represents an item placeholder,
	touch to pick up.
either way i need states for pick-up-able and for world-interact-able

pick-up-able should be its own thing 'item' 
... which holds a container to the object it represents.

while some things don't have world-interactable objects (tools etc)

TODO do I need an 'Item' parent class?
not as long as I have .use() ...
- as a behavior?
--]]

local ItemBed = Obj:subclass()

ItemBed.name = 'bed'
ItemBed.sprite = 'bed'

-- TODO eventually dont do this 
ItemBed.useGravity = false
ItemBed.collidesWithTiles = false

-- static method
function ItemBed:useInInventory(player)
	local game = player.game
	local map = game.map

	-- TODO traceline and then step back
	local dst = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor)

	-- TODO also make sure no objects exist here
	local tileType = map:get(dst:unpack())
	if tileType == Tile.typeValues.Empty 
	-- TODO and no solid object exists on this tile
	then
		game:newObj{
			class = player:removeSelectedItem(),
			pos = dst+.5,
		}
	end
end

--[[
here's the beginning of item-state vs game-state
--]]
function ItemBed:interactInWorld(player)
	if self.sleeping then return end
	self.sleeping = true
	
	-- TODO sleep
	print'sleeping'
	local game = self.game
	game.threads:add(function()
		game:sleep(1)
		-- offst to the next cycle of 6am
		local day = math.floor((game.time / game.secondsPerHour - game.wakeHour) / game.hoursPerDay) + 1
		game.time = (day * game.hoursPerDay + game.wakeHour) * game.secondsPerHour
		self.sleeping = false
	end)
end

ItemBed.takesDamage = true
function ItemBed:damage(amount, attacker, inflicter)
	if not (inflicter and inflicter.name == 'axe') then return end

	self.game:newObj{
		class = require 'zelda.obj.item',
		itemClass = require 'zelda.obj.bed',
		pos = self.pos,
	}
	self:remove()
end

return ItemBed 
