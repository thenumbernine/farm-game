--[[
TODO merge this with obj/seededground
--]]
local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local HoedGround = require 'zelda.obj.hoedground'
local Plant = require 'zelda.obj.plant'
local Item = require 'zelda.item.item'

local ItemSeeds = Item:subclass()

ItemSeeds.name = 'seeds'

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
	-- TODO how about a flag for objs whether they block seeds or not?
	and not map:hasObjType(x,y,z, Plant)
	then
		assert(player:removeSelectedItem() == self)
		game:newObj{
			class = self.plantType.objClass,
			pos = vec3f(x+.5, y+.5, z + .003),
		}
	end
end

return ItemSeeds 
