local class = require 'ext.class'
local table = require 'ext.table'
local gl = require 'gl'

local Tile = class()

local EmptyTile = class(Tile)

local SolidTile = class(Tile)

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

--baking makeSimplexVtxs(2) with xor'ing bits 0 and 1 for simplex traversal
local unitquad = {{0,0}, {1,0}, {1,1}, {0,1}}

function SolidTile:render(i,j,k)
	gl.glBegin(gl.GL_QUADS)
	for _,faces in ipairs(cubeFaces) do
		for f,face in ipairs(faces) do
			gl.glTexCoord2f(unitquad[f][1], unitquad[f][2])
			local v = cubeVtxs[face+1]
			gl.glVertex3f(v[1]+i, v[2]+j, v[3]+k)
		end
	end
	gl.glEnd()
end


Tile.typeValues = {
	EMPTY = 0,
	SOLID = 1,
}

Tile.types = {
	SolidTile(),
}

Tile.cubeVtxs = cubeVtxs 
Tile.cubeFaces = cubeFaces 
Tile.unitquad = unitquad

return Tile
