local class = require 'ext.class'
local Obj = require 'zelda.obj.obj'

local Goomba = class(Obj)
Goomba.sprite = 'goomba'
Goomba.seq = 'walk'
--Goomba.seqUsesDir = true	-- ok shouldn't this be for the anim sys to decide, not the obj?
Goomba.walkSpeed = 0

-- TODO put this in a superclass
function Goomba:damage(amount)
	-- TODO set the death sequence and remove it when it's done
	-- and remove solid etc in the mean time

	self.removeFlag = true
end

return Goomba
