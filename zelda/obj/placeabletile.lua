local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'

-- to contrast 'placeableObj', which puts a tile at a position
local function placeableTile(parent)
	local cl = parent:subclass()
	cl.classname = nil

	-- static method, so 'self' is the subclass
	function cl:useInInventory(player)
		local map = player.map
		-- only place upon button press
		local appPlayer = player.player
		if not (appPlayer.keyPress.useItem and not appPlayer.keyPressLast.useItem) then return end

		-- TODO traceline and then step back
		local dst = (player.pos + vec3f(
			math.cos(player.angle),
			math.sin(player.angle),
			0
		)):map(math.floor)

		-- opposite order as tools remove tiles
		for dz=-1,1 do
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
