-- TODO this is a copy of zelda.obj.stone
--  both are used for item-obj <-> item <-> tile
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local Tile = require 'zelda.tile'
local Obj = require 'zelda.obj.obj'

-- TODO subclass of item?
local Dirt = Obj:subclass()
Dirt.classname = 'zelda.obj.dirt'

Dirt.name = 'Dirt'

-- TODO i haven't made this sprite yet
-- but right now theres no way to drop dirt tiles
-- so meh? no need just yet
Dirt.sprite = 'dirt'

Dirt.useGravity = false

Dirt.collidesWithTiles = false
-- hmm how do I say 'test touch' but not 'test movement collision' ?
-- quake engines did touchtype_item ...
--Dirt.collidesWithObjects = false	

Dirt.min = box3f{
	min = {-.3, -.3, -.3},
	max = {.3, .3, .3},
}

function Dirt:touch(other)
	if other.addItem then
		if other:addItem(Dirt) then
			self:remove()
		end
	end
end


-- same as obj/log.lua
-- but for dif type
-- except maybe that part where I have it place beneath you first ...
-- or maybe wood should do that too?
function Dirt:useInInventory(player)
	local map = player.map
	-- only place upon button press
	local appPlayer = player.player
	if not (appPlayer.keyPress.useItem and not appPlayer.keyPressLast.useItem) then return end

	-- TODO traceline and then step back
	for z=-1,1 do
		local dst = (player.pos + vec3f(
			math.cos(player.angle),
			math.sin(player.angle),
			z
		)):map(math.floor)

		local tile = map:getTile(dst:unpack())
		if tile.type == Tile.typeValues.Empty then
			player:removeSelectedItem()
			tile.type = Tile.typeValues.Grass
			tile.tex = 0	--maptexs.grass
			map:buildDrawArrays(
				dst.x, dst.y, dst.z,
				dst.x, dst.y, dst.z)
			return
		end
	end
end

return Dirt
