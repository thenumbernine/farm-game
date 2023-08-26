local Obj = require 'zelda.obj.obj'

local Goomba = require 'zelda.obj.takesdamage'(Obj):subclass()

Goomba.name = 'Goomba'	-- TODO require name?

Goomba.sprite = 'goomba'
--Goomba.seq = 'walk'
Goomba.walkSpeed = 0

return Goomba
