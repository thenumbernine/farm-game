local table = require 'ext.table'
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
}

--[[
auto-add.  i think this was below but below also had udlr stuff meh.
TODO 
- auto determine frame numbers in sequences
- auto determine when sequence is using up/down/right (and flip)
- store 'usedirs' per frame, not per sprite or per seq
--]]
local Atlas = require 'farmgame.atlas'
local spriteAtlasMap = Atlas.atlasMap
local spriteAtlasKeys = Atlas.atlasKeys
local spriteNames = table(Atlas.spriteNames)
-- because I just added it manually
-- TODO the TODO above so I can add it automatically
spriteNames:removeObject'link'

for _,dir in ipairs(spriteNames) do
	local sprite = {}
	local prefix = 'sprites/'..dir..'/'
	for _,f in ipairs(Atlas.getAllKeys(prefix)) do
		local fbase = path(f:sub(#prefix+1)):getext()
		sprite[fbase] = {
			{filename = f},
		}
	end
	anim[dir] = sprite
end

return anim
