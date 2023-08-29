local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
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

local Bed = Obj:subclass()

Bed.name = 'bed'
Bed.sprite = 'bed'
Bed.drawSize = vec2f(2, 2)
Bed.drawCenter = vec2f(.5, .5)

-- TODO eventually dont do this
Bed.useGravity = false
Bed.collidesWithTiles = false
Bed.bbox = box3f{
	min = {-.5, -.5, 0},
	max = {.5, .5, .5},
}

-- static method
function Bed:useInInventory(player)
	local map = self.map

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
		player.map:newObj{
			class = player:removeSelectedItem(),
			pos = dst+.5,
		}
	end
end

Bed.sleepTime = 3

--[[
here's the beginning of item-state vs game-state
--]]
function Bed:interactInWorld(player)
	if player.sleeping then return end

	local game = self.game
	game.threads:add(function()
		local startPos = player.pos:clone()
		local endPos = self.pos + vec3f(0, 0, .5)

		--player.seq = 'handsup'

		game:fade(.5, function(x)
			player.pos = startPos * (1 - x) + endPos * x + vec3f(0,0,1) * (4 * x * (1 - x))
		end)

		player:setPos(player.pos:unpack())

		-- TODO at this point, if the player used the bed, have it cancel the sleep?
		-- idk maybe maybe not

		game:sleep(.3)

		--player.seq = 'kneel'
		--game:sleep(.5)

		player.drawAngle = .5 * math.pi
		player.drawCenter:set(.5, .5)
		player.sleeping = true

		local startTime = game.time
		local day = math.floor((startTime / game.secondsPerHour - game.wakeHour) / game.hoursPerDay) + 1
		-- offst to the next cycle of 6am
		local endTime = (day * game.hoursPerDay + game.wakeHour) * game.secondsPerHour
		game:fadeAppTime(self.sleepTime, function(x)
			game.time = startTime * (1 - x) + endTime * x
		end)
		player.sleeping = false
		player.drawAngle = 0
		player.drawCenter:set(player.class.drawCenter:unpack())
	end)
end

Bed.takesDamage = true
function Bed:damage(amount, attacker, inflicter)
	if not (inflicter and (inflicter.name == 'axe' or inflicter.name == 'pickaxe')) then return end

	self.map:newObj{
		class = require 'zelda.obj.item',
		itemClass = require 'zelda.obj.bed',
		pos = self.pos,
	}
	self:remove()
end

return Bed
