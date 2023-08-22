local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local Tile = require 'zelda.tile'
local Obj = require 'zelda.obj.obj'

-- TODO move to obj/item/ ?
-- or ... no need for obj/item/ at all?
-- idk how to organize
local Log = Obj:subclass()

Log.name = 'Log'
Log.sprite = 'log'
Log.useGravity = false

Log.collidesWithTiles = false
-- hmm how do I say 'test touch' but not 'test movement collision' ?
-- quake engines did touchtype_item ...
--Log.collidesWithObjects = false	

Log.min = box3f{
	min = {-.3, -.3, -.3},
	max = {.3, .3, .3},
}

function Log:touch(other)
	if other.addItem then
		other:addItem(Log)
		self:remove()
	end
end

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
