local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'

-- to contrast 'placeableTile', which puts a tile at a position
local function placeableObj(parent)
	local cl = parent:subclass()
	cl.classname = nil

	-- static method
	function cl:useInInventory(player)
		local map = player.map

		-- hmm continuous use vs single?
		-- where should this constraint be?
		if player.appPlayer.keyPressLast.useItem then return end

		-- TODO traceline and then step back
		local dst = (player.pos + vec3f(
			math.cos(player.angle),
			math.sin(player.angle),
			0
		)):map(math.floor)

		-- TODO also make sure no objects exist here
		local tileType = map:getType(dst:unpack())
		if tileType == Tile.typeValues.Empty
		-- TODO and no solid object exists on this tile
		then
print('placing '..tostring(self.classname))
			player.map:newObj{
				class = player:removeSelectedItem(),
				pos = dst+.5,
			}
		end
	end

	-- fake-takesdamage?
	-- or TODO use real takesdamage?
	cl.takesDamage = true
	function cl:damage(amount, attacker, inflicter)
		if not (inflicter and (inflicter.name == 'axe' or inflicter.name == 'pickaxe')) then return end
		self:toItem()
	end

	return cl
end
return placeableObj
