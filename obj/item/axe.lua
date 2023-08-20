local vec3f = require 'vec-ffi.vec3f'
local Item = require 'zelda.obj.item.item'

local ItemAxe = Item:subclass()

ItemAxe.name = 'axe'

-- static method
function ItemAxe:useInInventory(player)
	local game = player.game
	local map = game.map

	-- TODO traceline
	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()

	local objs = map:getTileObjs(x,y,z)
	if objs then
		for _,obj in ipairs(objs) do
			if obj.canBeChoppedDown then
				-- then bleh , make it do some animation or something
				-- until then ...
				obj:remove()
				-- and then add a bunch of wood items
				for i=1,(obj.numLogs or 0) do
					local r = math.random() * 2
					local theta = math.random() * 2 * math.pi
					game:newObj{
						class = require 'zelda.obj.log',
						pos = obj.pos + vec3f(
							math.cos(theta) * r,
							math.sin(theta) * r,
							0
						)
					}
				end
			end
		end
	end
end

return ItemAxe 
