-- to contrast 'placeableTile', which puts a tile at a position
local function placeableObj(parent)
	local cl = parent:subclass()

	-- static method
	function cl:useInInventory(player)
		local map = player.map

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

	return cl
end
return placeableObj
