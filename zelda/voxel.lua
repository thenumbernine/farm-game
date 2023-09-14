local class = require 'ext.class'
local table = require 'ext.table'
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local gl = require 'gl'

local cubeFaces = table()
for pm=0,1 do	-- plus/minus
	for i=0,2 do	-- x,y,z
		local i2 = (i+1)%3
		local i3 = (i2+1)%3
		if pm == 0 then i2, i3 = i3, i2 end
		local face = table()
		local v = pm == 0 and 0 or (bit.lshift(1, 3)-1)
		face:insert(v)
		v = bit.bxor(v, bit.lshift(1, i2))
		face:insert(v)
		v = bit.bxor(v, bit.lshift(1, i3))
		face:insert(v)
		v = bit.bxor(v, bit.lshift(1, i2))
		face:insert(v)
		v = bit.bxor(v, bit.lshift(1, i3))
		cubeFaces:insert(face)
	end
end

local function makeSimplexVtxs(n)
	local vtxs = table()
	for i=0,bit.lshift(1,n)-1 do
		local v = {}
		for j=0,n-1 do
			v[j+1] = bit.band(bit.rshift(i, j), 1)
		end
		vtxs:insert(v)
	end
	return vtxs
end

-- bit 0 = x+, 1 = y+, 2 = z+
local cubeVtxs = makeSimplexVtxs(3)

--baking makeSimplexVtxs(2) with xor'ing bits 0 and 1 for 2D simplex traversal
local unitquad = {{0,0}, {1,0}, {1,1}, {0,1}}
local unitQuadTris = {{0,0}, {1,0}, {0,1}, {0,1}, {1,0}, {1,1}}
local unitQuadTriIndexes = {1, 2, 4, 4, 2, 3}
local unitQuadTriStripIndexes = {1, 2, 4, 3}


local Tile = class()

Tile.bbox = box3f{
	min = {0,0,0},
	max = {1,1,1},
}

--[[
function Tile:render(i,j,k, shader)
	gl.glBegin(gl.GL_QUADS)
	for _,faces in ipairs(cubeFaces) do
		for f,face in ipairs(faces) do
			local v = cubeVtxs[face+1]
			gl.glVertexAttrib1f(shader.attrs.lum.loc, v[3])
			gl.glVertexAttrib2f(shader.attrs.texcoord.loc, unitquad[f][1], unitquad[f][2])
			gl.glVertex3f(
				i + (1 - v[1]) * self.bbox.min.x + v[1] * self.bbox.max.x, 
				j + (1 - v[2]) * self.bbox.min.y + v[2] * self.bbox.max.y, 
				k + (1 - v[3]) * self.bbox.min.z + v[3] * self.bbox.max.z) 
		end
	end
	gl.glEnd()
end
--]]

-- assign here before making subclasses
Tile.cubeVtxs = cubeVtxs 
Tile.cubeFaces = cubeFaces 
Tile.unitquad = unitquad
Tile.unitQuadTris = unitQuadTris
Tile.unitQuadTriIndexes = unitQuadTriIndexes
Tile.unitQuadTriStripIndexes = unitQuadTriStripIndexes 
Tile.texrects = {}

Tile.types = {}				-- index => obj
Tile.typeForName = {}		-- name => obj
Tile.typeValues = {}		-- name => index


local Atlas = require 'zelda.atlas'
local spriteAtlasMap = Atlas.atlasMap
-- returns a 0-based table, indexed with voxel.tex
local function getTexRects(sprite)
	return Atlas.getAllKeys('sprites/maptiles/'..sprite):mapi(function(fn)
		return spriteAtlasMap[fn]
	end):setmetatable(nil)
end


local EmptyTile = Tile:subclass()
EmptyTile.name = 'Empty'	-- excluding 'Tile' suffix of all Tile classes ...
-- TODO give each Tile an obj, and give Empty none
EmptyTile.render = nil
EmptyTile.lightDiminish = 1


local SolidTile = Tile:subclass()
SolidTile.name = 'Solid'
SolidTile.solid = true
SolidTile.isUnitCube = true	-- render shorthand for side occlusion
SolidTile.lightDiminish = 15	-- TODO unless .shape>0, then just diminish ... .... half?
assert(SolidTile.cubeFaces)

local StoneTile = SolidTile:subclass{name='Stone'}
StoneTile.texrects = getTexRects'cavestone'

local GrassTile = SolidTile:subclass{name='Grass'}
GrassTile.texrects = getTexRects'grass'

local DirtTile = SolidTile:subclass{name='Dirt'}
DirtTile.texrects = getTexRects'dirt'
-- include a 9-patch for grass borders?

local TilledTile = SolidTile:subclass{name='Tilled'}
-- TODO dirt on the sides, tilled on the top only
TilledTile.texrects = getTexRects'tilled'
-- include a 9-patch for dirt borders?

-- TODO - call this when setting the tile to a new tile type
function TilledTile:onChangeFrom()
	-- TODO remove all HoedGround objs at this tile location
end


local WateredTile = SolidTile:subclass{name='Watered'}
-- TODO dirt on the sides, tilled on the top only
WateredTile.texrects = getTexRects'watered'
-- include a 9-patch for dirt borders?



-- TODO hmm seeded tile ... but custom renderer per-seed type?

-- TODO custom renderer per wood type?
local WoodTile = SolidTile:subclass{name='Wood'}
WoodTile.texrects = getTexRects'wood'

local WaterTile = Tile:subclass{name='Water'}
WaterTile.texrects = getTexRects'water_'
WaterTile.isUnitCube = true	-- put in Tile?
WaterTile.lightDiminish = 2
-- TODO auto flag this if any texrect have a transparent pixel
WaterTile.transparent = true
-- TODO contents = ... vacuum, air, poison gas, water, acid, lava, oil, ... plasma ... einstein-bose condensate ... quantum spin-liquid ... quark matter ... hole in the fabric of spacetime ... 
WaterTile.contents = 'water'

--[[
what do i want ...
- empty
- harvestable ground with flags: 
	- hoed?
	- watered?
	- fertilized? / quality
	- retention soil'd? / quality
	- what kind of seed is planted here
--]]
Tile.types[0] = EmptyTile()
table.insert(Tile.types, StoneTile())
table.insert(Tile.types, GrassTile())
table.insert(Tile.types, DirtTile())
table.insert(Tile.types, TilledTile())
table.insert(Tile.types, WateredTile())
table.insert(Tile.types, WoodTile())
table.insert(Tile.types, WaterTile())

-- 0 exists
for index=0,#Tile.types do
	local obj = Tile.types[index]
	obj.index = index
	Tile.typeValues[obj.name] = index
	Tile.typeForName[obj.name] = obj
end

return Tile
