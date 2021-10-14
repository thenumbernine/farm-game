local class = require 'ext.class'
local gl = require 'gl'

local Tile = class()

local EmptyTile = class(Tile)

local SolidTile = class(Tile)

local cubeFaces = {
	{3, 1, 0, 2},	-- xy <-> xor on 1,2
	{4, 5, 7, 6},	-- ... and xor on z and flip indexes
	{6, 2, 0, 4},	-- yz <-> xor on 2,4
	{1, 3, 7, 5},
	{5, 4, 0, 1},	-- zx <-> xor on 4,1
	{2, 6, 7, 3},
}

-- bit 0 = x+, 1 = y+, 2 = z+
local cubeVtxs = {
	{0,0,0},
	{1,0,0},
	{0,1,0},
	{1,1,0},
	{0,0,1},
	{1,0,1},
	{0,1,1},
	{1,1,1},
}

local tcs = {{0,0}, {1,0}, {1,1}, {0,1}}

function SolidTile:render(i,j,k)
	gl.glBegin(gl.GL_QUADS)
	for _,faces in ipairs(cubeFaces) do
		for f,face in ipairs(faces) do
			gl.glTexCoord2f(tcs[f][1], tcs[f][2])
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

return Tile
