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
		local v = vec3f()
		for j=0,n-1 do
			v.s[j] = bit.band(bit.rshift(i, j), 1)
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
			gl.glVertexAttrib1f(shader.attrs.lum.loc, v.z)
			gl.glVertexAttrib2f(shader.attrs.texcoord.loc, unitquad[f][1], unitquad[f][2])
			gl.glVertex3f(
				i + (1 - v.x) * self.bbox.min.x + v.x * self.bbox.max.x,
				j + (1 - v.y) * self.bbox.min.y + v.y * self.bbox.max.y,
				k + (1 - v.z) * self.bbox.min.z + v.z * self.bbox.max.z)
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


local Atlas = require 'farmgame.atlas'
local spriteAtlasMap = Atlas.atlasMap
-- returns a 0-based table, indexed with voxel.tex
local function setTexRects(cl, sprite)
	local atlasKeys = Atlas.getAllKeys('sprites/maptiles/'..sprite)
	cl.seqNames = atlasKeys:mapi(function(k)
		local f = k:match'^sprites/maptiles/(.*)%.[^%.]-$'
		assert(f, "failed to find prefix sprites/maptiles/")
		return f
	end)
	cl.texrects = atlasKeys:mapi(function(fn)
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
setTexRects(StoneTile, 'cavestone')

local BedrockTile = SolidTile:subclass{name='Bedrock'}
setTexRects(BedrockTile, 'bedrock')

local GrassTile = SolidTile:subclass{name='Grass'}
setTexRects(GrassTile, 'grass')

local DirtTile = SolidTile:subclass{name='Dirt'}
setTexRects(DirtTile, 'dirt')
-- include a 9-patch for grass borders?

local TilledTile = SolidTile:subclass{name='Tilled'}
-- TODO dirt on the sides, tilled on the top only
setTexRects(TilledTile, 'tilled')
-- include a 9-patch for dirt borders?

-- TODO - call this when setting the tile to a new tile type
function TilledTile:onChangeFrom()
	-- TODO remove all HoedGround objs at this tile location
end

local WateredTile = SolidTile:subclass{name='Watered'}
-- TODO dirt on the sides, tilled on the top only
setTexRects(WateredTile, 'watered')
-- include a 9-patch for dirt borders?

-- TODO hmm seeded tile ... but custom renderer per-seed type?

-- TODO custom renderer per wood type?
local WoodTile = SolidTile:subclass{name='Wood'}
setTexRects(WoodTile, 'wood')


local WaterTile = Tile:subclass{name='Water'}
setTexRects(WaterTile, 'water_')
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
Tile.types = {}				-- index => obj
Tile.types[0] = EmptyTile()
table.insert(Tile.types, StoneTile())
table.insert(Tile.types, GrassTile())
table.insert(Tile.types, DirtTile())
table.insert(Tile.types, TilledTile())
table.insert(Tile.types, WateredTile())
table.insert(Tile.types, WoodTile())
table.insert(Tile.types, WaterTile())
table.insert(Tile.types, BedrockTile())

-- Tile.types[0] exists
Tile.typeForName = {}		-- name => obj
Tile.typeValues = {}		-- name => index
for index=0,#Tile.types do
	local obj = Tile.types[index]
	obj.index = index
	Tile.typeValues[obj.name] = index
	Tile.typeForName[obj.name] = obj

	-- while we're here, also make farmgame.item.voxel.* subclasses
	-- TODO I'm only doing this because right now the item system only handles classes, not objects
	-- obvious TODO is make it handle objects
	local vcl = require 'farmgame.item.placeabletile':subclass()
	vcl.tileType = index
	vcl.tileShape = 0	-- default class is cube shape
	vcl.tileClass = obj	-- misnomer, these ar stored as objects within Voxel.types[] ... not classes
	vcl.name = obj.name
	if obj.seqNames then
		vcl.sprite = 'maptiles'
		vcl.seq = obj.seqNames:pickRandom()
	else
		print("can't find seqNames for voxel "..obj.name)
	end
	vcl.classname = 'farmgame.item.voxel.'..obj.name
	package.loaded[vcl.classname] = vcl
end

local OBJLoader = require 'mesh.objloader'

local Shape = class()

-- this is inline already and optimized for removing matching adjacent sides
-- TODO do this with all?
local CubeShape = Shape:subclass{name='Cube'}

local HalfShape = Shape:subclass{name='Half'}
HalfShape.modelFilename = 'voxels/half.obj'

-- 1:1 slope
local Slope_1_1Shape = Shape:subclass{name='Slope_1_1'}
Slope_1_1Shape.modelFilename = 'voxels/slope_1_1.obj'

-- 1:2 slope
local Slope_1_2Shape = Shape:subclass{name='Slope_1_2'}
Slope_1_2Shape.modelFilename = 'voxels/slope_1_2.obj'

-- 1:1 slope with 1 corner up (at the 1,1 position)
local Slope_1_1_1upShape = Shape:subclass{name='Slope_1_1_1up'}
Slope_1_1_1upShape.modelFilename = 'voxels/slope_1_1_1up.obj'

-- 1:2 slope with 1 corner up (at the 1,1 position)
local Slope_1_2_1upShape = Shape:subclass{name='Slope_1_2_1up'}
Slope_1_2_1upShape.modelFilename = 'voxels/slope_1_2_1up.obj'

-- 1:1 slope with 3 corners up (the corner down is at the 0,0 position)
local Slope_1_1_3upShape = Shape:subclass{name='Slope_1_1_3up'}
Slope_1_1_3upShape.modelFilename = 'voxels/slope_1_1_3up.obj'

-- 1:2 slope with 3 corners up (the corner down is at the 0,0 position)
local Slope_1_2_3upShape = Shape:subclass{name='Slope_1_2_3up'}
Slope_1_2_3upShape.modelFilename = 'voxels/slope_1_2_3up.obj'


Tile.shapes = {}
Tile.shapes[0] = CubeShape()
table.insert(Tile.shapes, HalfShape())
table.insert(Tile.shapes, Slope_1_1Shape())
table.insert(Tile.shapes, Slope_1_2Shape())
table.insert(Tile.shapes, Slope_1_1_1upShape())
table.insert(Tile.shapes, Slope_1_2_1upShape())
table.insert(Tile.shapes, Slope_1_1_3upShape())
table.insert(Tile.shapes, Slope_1_2_3upShape())

-- Tile.shapes[0] exists
Tile.shapeForName = {}		-- name => obj
Tile.shapeValues = {}		-- name => index
for shapeIndex=0,#Tile.shapes do
	local shapeObj = Tile.shapes[shapeIndex]
	shapeObj.index = shapeIndex
	Tile.shapeValues[shapeObj.name] = shapeIndex
	Tile.shapeForName[shapeObj.name] = shapeObj

	if shapeObj.name ~= 'Cube' then
		for typeIndex=1,#Tile.types do
			local typeObj = Tile.types[typeIndex]
			if typeObj.solid then	-- TODO also skip tilled and watered tile types
				local vcl = require 'farmgame.item.placeabletile':subclass()
				vcl.tileType = typeIndex
				vcl.tileShape = shapeIndex
				vcl.tileClass = typeObj	-- TODO 'tileObj' ? not sure ... or maybe don't put instances in the type[] table ...
				vcl.name = typeObj.name..' '..shapeObj.name
				vcl.classname = 'farmgame.item.voxel.'..typeObj.name..'_'..shapeObj.name
				package.loaded[vcl.classname] = vcl
			end
		end
	end

	-- index 0 doesn't have one ... but maybe could ...
	if shapeObj.modelFilename then
		shapeObj.model = OBJLoader():load(shapeObj.modelFilename)
	
		-- TODO here
		-- cycle through all faces
		-- if they are planar in the x/y/z +/- planes then flag them accordingly
		-- also somehow detect if the full [0,1]^2 surface of that side is filled
		-- then use that with occlusion
	end
end

return Tile
