local ffi = require 'ffi'
local vec3f = require 'vec-ffi.vec3f'

-- to contrast 'placeableObj', which puts a tile at a position
local Item = require 'zelda.item.item'

local PlaceableVoxel = Item:subclass()
PlaceableVoxel.classname = 'zelda.item.placeabletile'

local function angleSnapTo90(angle)
	return (angle / (.5 * math.pi)) % 4
end

--[[ subclass needs to provide all this
-- or TODO allow objs to go in inventory, not just classes
function PlaceableVoxel:init(args)
	PlaceableVoxel.super.init(self, args)

	self.tileType = assert(args.tileType)
	self.tileClass = assert(Voxel.types[self.tileType])
	self.name = self.tileClass.name
	self.sprite = 'maptiles'
	-- what to show the item as
	self.seq = self.tileClass.seqNames:pickRandom()
end
--]]

-- static method, so 'self' is the subclass
function PlaceableVoxel:useInInventory(player)
	local Voxel = require 'zelda.voxel'
	local map = player.map
	-- only place upon button press
	local appPlayer = player.appPlayer
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
		if tile
		and tile.type == Voxel.typeValues.Empty
		then
			player:removeSelectedItem()
print('setting tile to', self.tileType, self.tileShape)
			tile.type = self.tileType
			tile.shape = self.tileShape

			--tile.rotx = 0
			tile.roty = 0
			tile.rotz = angleSnapTo90(player.angle)
			
			tile.tex = math.random(#self.tileClass.texrects)-1
			-- if this is blocking a light sources ...
			-- ... that means I need to update all blocks within MAX_LUM from this point.
			map:updateLightAtPos(dst:unpack())
			return
		end
	end
end

return PlaceableVoxel
