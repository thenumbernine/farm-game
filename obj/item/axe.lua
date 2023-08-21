local vec3f = require 'vec-ffi.vec3f'
local Item = require 'zelda.obj.item.item'

local ItemAxe = Item:subclass()

ItemAxe.name = 'axe'

-- static method
function ItemAxe:useInInventory(player)
	local game = player.game
	local map = game.map

	-- TODO dif animation than sword
	if player.attackEndTime >= game.time then return end
	player.swingPos = vec3f(player.pos.x, player.pos.y, player.pos.z + .7)
	player.attackTime = game.time
	player.attackEndTime = game.time + player.attackDuration

	-- TODO traceline
	local x,y,z = (player.pos + vec3f(
		math.cos(player.angle),
		math.sin(player.angle),
		0
	)):map(math.floor):unpack()

	local objs = map:getTileObjs(x,y,z)
	if objs then
		for _,obj in ipairs(objs) do
			if not obj.removeFlag
			and obj ~= player
			and obj.takesDamage
			and not obj.dead
			then
				obj:damage(1, player, self)
			end
		end
	end
end

return ItemAxe 
