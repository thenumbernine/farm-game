local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

-- TODO placeable item ...
local ItemBed = Obj:subclass()

ItemBed.name = 'bed'
ItemBed.sprite = 'bed'

function ItemBed:use(player)
	local game = player.game

	if player.attackEndTime >= game.time then return end
	
	player.swingPos = vec3f(player.pos:unpack())
	player.attackTime = game.time
	player.attackEndTime = game.time + player.attackDuration

	-- see if we hit anyone
	for _,obj in ipairs(game.objs) do
		if obj ~= player 
		and obj.takesDamage
		and not obj.dead
		then
			local attackDist = 2	-- should match rFar in the draw code.  TODO as well consider object bbox / bounding radius.
			if (player.pos - obj.pos):lenSq() < attackDist*attackDist then
				obj:damage(1)
			end
		end
	end
end

return ItemBed 
