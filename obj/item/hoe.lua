local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local HoedGround = require 'zelda.obj.hoedground'
local Item = require 'zelda.obj.item.item'

local ItemHoe = Item:subclass()

ItemHoe.name = 'hoe'

function ItemHoe:use(player)
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
		-- TODO link objects by voxels touched
		local found
		for _,obj in ipairs(game.objs) do
			if HoedGround:isa(obj)
			and math.floor(obj.pos.x) == x
			and math.floor(obj.pos.y) == y
			and math.floor(obj.pos.z) == z
			then
				found = true
				break
			end
		end
		if not found then
			game:newObj{
				class = HoedGround,
				pos = vec3f(x+.5, y+.5, z),
			}
			print(#game.objs)
		end
	end
end

return ItemHoe 
