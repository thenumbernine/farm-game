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

function ItemBed:interactInWorld(player)
	self:remove()
	player:addItem(self.class)
end

return ItemBed 
