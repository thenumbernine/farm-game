local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

-- TODO move to obj/item/ ?
-- or ... no need for obj/item/ at all?
-- idk how to organize
local LogItem = Obj:subclass()

LogItem.name = 'Log'
LogItem.sprite = 'log'
LogItem.useGravity = false
LogItem.collidesWithTiles = false

-- hmm how do I say 'test touch' but not 'test movement collision' ?
-- quake engines did touchtype_item ...
--LogItem.collidesWithObjects = false	

LogItem.min = vec3f(-.3, -.3, -.3)
LogItem.max = vec3f(.3, .3, .3)

function LogItem:touch(other)
	if other.addItem then
		other:addItem(LogItem)
		self:remove()
	end
end

function LogItem:useInInventory(player)
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
		tile.type = Tile.typeValues.Solid
		tile.tex = 2	--maptexs.wood
		map:updateDrawArrays()
	end
end

return LogItem