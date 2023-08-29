local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'

-- to contrast 'placeableObj', which puts a tile at a position
local function placeableTile(parent)
	local cl = parent:subclass()

	-- static method, so 'self' is the subclass
	function cl:useInInventory(player)
		local map = player.map

		-- TODO traceline and then step back
		local dst = (player.pos + vec3f(
			math.cos(player.angle),
			math.sin(player.angle),
			0
		)):map(math.floor)

		local tile = map:getTile(dst:unpack())
		if tile.type == Tile.typeValues.Empty then
			player:removeSelectedItem()
			tile.type = assert(self.tileType)
			tile.tex = 2	--maptexs.wood
			map:buildDrawArrays(
				dst.x, dst.y, dst.z,
				dst.x, dst.y, dst.z)
		end
	end

	return cl
end
return placeableTile
