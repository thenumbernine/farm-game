local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local HoedGround = require 'zelda.obj.hoedground'
local Plant = require 'zelda.obj.plant'
local Item = require 'zelda.item.item'

local ItemHoe = Item:subclass()

ItemHoe.name = 'hoe'
ItemHoe.sprite = 'item'
ItemHoe.seq = 'item_hoe'

-- static method
function ItemHoe:useInInventory(player)
	local map = player.map
	
	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()
	local topTile = map:get(x,y,z)
	local groundTile = map:get(x,y,z-1)
	if groundTile == Tile.typeValues.Grass
	and topTile == Tile.typeValues.Empty
	and not map:hasObjType(x,y,z,HoedGround)
	-- TODO any kind of solid object
	--  a better classification would be only allow watered/hoedground/seededground types (which should all have a common parent class / flag)
	and not map:hasObjType(x,y,z,Plant)
	then
		player.map:newObj{
			class = HoedGround,
			pos = vec3f(x+.5, y+.5, z + .001),
		}
	end
end

return ItemHoe 
