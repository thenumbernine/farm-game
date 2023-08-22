local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local HoedGround = require 'zelda.obj.hoedground'
local SeededGround = require 'zelda.obj.seededground'
local Item = require 'zelda.obj.item.item'

local ItemSeeds = Item:subclass()

ItemSeeds.name = 'seeds'

-- TODO instead make this all part of Plant
ItemSeeds.subclasses = {}

function ItemSeeds:makeSubclass(name)
	local subcl = ItemSeeds.subclasses[name]
	if subcl then return subcl end
	subcl = ItemSeeds:subclass{
		name = name,
	}
	ItemSeeds.subclasses[name] = subcl
	return subcl
end

-- static method
function ItemSeeds:useInInventory(player)
	local game = player.game
	local map = game.map
	
	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()
	local topTile = map:get(x,y,z)
	local groundTile = map:get(x,y,z-1)
	if groundTile == Tile.typeValues.Grass
	and topTile == Tile.typeValues.Empty
	and map:hasObjType(x,y,z, HoedGround)
	and not map:hasObjType(x,y,z, SeededGround)
	then
		game:newObj{
			-- TODO SeededGround vs ItemSeeds ...
			class = SeededGround,
			--player:removeSelectedItem(),
			pos = vec3f(x+.5, y+.5, z + .002),
		}
	end
end

return ItemSeeds 
