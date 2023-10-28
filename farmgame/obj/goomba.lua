local Obj = require 'farmgame.obj.obj'

local Goomba = require 'farmgame.obj.takesdamage'(Obj):subclass()
Goomba.classname = 'farmgame.obj.goomba'

Goomba.name = 'Goomba'	-- TODO require name?

Goomba.sprite = 'animal_goomba'
--Goomba.seq = 'walk'
Goomba.walkSpeed = 0

return Goomba
