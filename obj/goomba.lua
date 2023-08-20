local Obj = require 'zelda.obj.obj'

local Goomba = Obj:subclass()

Goomba.name = 'Goomba'	-- TODO require name?

Goomba.sprite = 'goomba'
--Goomba.seq = 'walk'
Goomba.walkSpeed = 0

Goomba.takesDamage = true

-- TODO put this in a superclass
function Goomba:damage(amount)
	local game = self.game

	-- TODO if hp < 0 then ...
	self.dead = true
	
	self.collidesWithTiles = false
	self.vflip = true
	self.vel.z = self.vel.z + 6
	-- TODO add some random damage from the inflicter
	local th = math.random() * 2 * math.pi
	local r = 1
	self.vel.x = self.vel.x + r * math.cos(th)
	self.vel.y = self.vel.y + r * math.sin(th)

	-- coroutines
	game.threads:add(function()
		game:fade(1, function(alpha)
			self.color.w = 1 - alpha
		end)
		self:remove()
	end)
end

return Goomba
