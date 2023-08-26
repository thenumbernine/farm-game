local vec3f = require 'vec-ffi.vec3f'
local Tile = require 'zelda.tile'
local Item = require 'zelda.item.item'

-- TODO move to obj/item/ ?
-- or ... no need for obj/item/ at all?
-- idk how to organize
-- maybe Log (and tools) should be in zelda/items
-- and no need for zelda/obj/items
local Log = Item:subclass()

Log.name = 'Log'
Log.sprite = 'log'

function Log:useInInventory(player)
	local game = player.game
	local map = game.map

	-- TODO traceline and then step back
	local dst = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor)

	local tile = map:getTile(dst:unpack())
	if tile.type == Tile.typeValues.Empty then
		player:removeSelectedItem()
		tile.type = Tile.typeValues.Wood
		tile.tex = 2	--maptexs.wood
		map:buildDrawArrays()
	end
end

return Log
