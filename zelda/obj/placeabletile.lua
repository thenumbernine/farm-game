local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'

-- to contrast 'placeableObj', which puts a tile at a position
local function placeableTile(parent)
	local cl = parent:subclass()
	cl.classname = nil

	-- static method, so 'self' is the subclass
	function cl:useInInventory(player)
		local map = player.map

		-- TODO traceline and then step back
		local dst = (player.pos + vec3f(
			math.cos(player.angle),
			math.sin(player.angle),
			0
		)):map(math.floor)

		-- first try to place in front
		-- next try to place one below
		-- hmm maybe? idk
		for dz=0,-1,-1 do
			local tile = map:getTile(dst.x, dst.y, dst.z+dz)
			if tile and tile.type == Tile.typeValues.Empty then
				player:removeSelectedItem()
				tile.type = assert(self.tileType)
				tile.tex = 2	--maptexs.wood
				map:buildDrawArrays(
					dst.x, dst.y, dst.z,
					dst.x, dst.y, dst.z)
				break
			end
		end
	end

	return cl
end
return placeableTile
