local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local HoedGround = require 'zelda.obj.hoedground'
local SeededGround = require 'zelda.obj.seededground'
local Item = require 'zelda.obj.item.item'

local ItemSeeds = Item:subclass()

ItemSeeds.name = 'seeds'

function ItemSeeds:use(player)
	local game = player.game
	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()
	print(x,y,z)
	local topTile = game.map:get(x,y,z)
	local groundTile = game.map:get(x,y,z-1)
	if groundTile == Tile.typeValues.Grass
	and topTile == Tile.typeValues.Empty
	then
		-- TODO dif kinds of seeds ... hmm ...
		-- TODO link objects by voxels touched
		local foundSeededGround
		local foundHoed
		for _,obj in ipairs(game.objs) do
			if SeededGround:isa(obj)
			and math.floor(obj.pos.x) == x
			and math.floor(obj.pos.y) == y
			and math.floor(obj.pos.z) == z
			then
				foundSeededGround = true
				--break
			end
			if HoedGround:isa(obj)
			and math.floor(obj.pos.x) == x
			and math.floor(obj.pos.y) == y
			and math.floor(obj.pos.z) == z
			then
				foundHoed = true
				--break
			end
	
		end
		if foundHoed 
		and not foundSeededGround 
		then
			game:newObj{
				class = SeededGround,
				pos = vec3f(x+.5, y+.5, z),
			}
			print(#game.objs)
		end
	end
end

return ItemSeeds 
