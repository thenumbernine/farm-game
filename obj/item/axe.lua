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
			if obj.onChopDown then
				obj:onChopDown()
			end
		end
	end
end

return ItemAxe 
