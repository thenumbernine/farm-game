local table = require 'ext.table'
local string = require 'ext.string'
local path = require 'ext.path'

-- anim[sprite][seq][frame]
local anim = {
	link = {
		useDirs = true,
		stand_r = {
			{filename = 'sprites/link/stand_r.png'},
		},
		stand_u = {
			{filename = 'sprites/link/stand_u.png'},
		},
		stand_l = {
			{filename = 'sprites/link/stand_r.png', hflip=true},
		},
		stand_d = {
			{filename = 'sprites/link/stand_d.png'},
		},
	
		-- TODO 'useDirs' per-frame / seq instead of per-sprite ....
		kneel_r = {{filename = 'sprites/link/kneel.png'}},
		kneel_u = {{filename = 'sprites/link/kneel.png'}},
		kneel_l = {{filename = 'sprites/link/kneel.png', hflip=true}},
		kneel_d = {{filename = 'sprites/link/kneel.png'}},
	
		handsup_r = {{filename = 'sprites/link/handsup.png'}},
		handsup_u = {{filename = 'sprites/link/handsup.png'}},
		handsup_l = {{filename = 'sprites/link/handsup.png', hflip=true}},
		handsup_d = {{filename = 'sprites/link/handsup.png'}},
	},
	goomba = {
		stand = {
			{filename = 'sprites/goomba/stand.png'},
		},
	},
	
	-- [[ ground sprites
	hoed = {
		stand = {
			--{filename = 'sprites/hoed/stand.obj'},
			{filename = 'sprites/hoed/stand.png'},
		},
	},
	watered = {
		stand = {
			--{filename = 'sprites/watered/stand.obj'},
			{filename = 'sprites/watered/stand.png'},
		},
	},
	seededground = {
		stand = {
			--{filename = 'sprites/seededground/stand.obj'},
			{filename = 'sprites/seededground/stand.png'},
		},
	},
	log = {
		stand = {
			{filename = 'sprites/log/stand.png'},
		},
	},
	bed = {
		stand = {
			{filename = 'sprites/bed/stand.png'},
		},
	},
	chest = {
		stand = {
			{filename = 'sprites/chest/stand.png'},
		},
	},
	--]]
}

-- auto-add.  i think this was below but below also had udlr stuff meh.
local spriteAtlasMap = require 'zelda.atlas'
local spriteAtlasKeys = table.keys(spriteAtlasMap)
for _,dir in ipairs{
	'tree',
	'plant',
	'bush',
	'fruit',
	'item',
	'vegetable',
} do
	local sprite = {}
	for _,f in ipairs(spriteAtlasKeys) do
		local prefix = 'sprites/'..dir..'/'
		if f:match('^'..string.patescape(prefix)) then
			local fbase = path(f:sub(#prefix+1)):getext()
			sprite[fbase] = {
				{filename = f},
			}
		end
	end
	anim[dir] = sprite
end


-- TODO use the filesystem for the whole thing? and no table?
-- or TODO use spritesheets?
--[[
local path = require 'ext.path'
for _,spritename in ipairs{'goomba'} do
	local sprite = {}
	anim[spritename] = sprite
	for f in path('sprites/'..spritename):dir() do
		local base, ext = path(f):getext()
		local seqname, frameindex = base:match'^(.-)(%d*)$'
		frameindex = tonumber(frameindex) or frameindex
		-- TODO auto group sequences of numbers?
		sprite[seqname] = sprite[seqname] or {}
		table.insert(sprite[seqname], {
			filename = 'sprites/'..spritename..'/'..f, 
			index = frameindex,
		})
	end
	for seqname,seq in pairs(sprite) do
		table.sort(seq, function(a,b) return a.index < b.index end)
	end
	-- I don't need the frames after sorting, right?
	for seqname,seq in pairs(sprite) do
		for index,frame in ipairs(seq) do
			frame.index = nil
		end
	end
end
--]]

return anim
