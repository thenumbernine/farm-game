local Obj = require 'farmgame.obj.obj'

-- TODO instead of 'enemy', 'combat', and give it to player
local Goomba = require 'farmgame.obj.enemy'(Obj):subclass()
Goomba.classname = 'farmgame.obj.goomba'

Goomba.name = 'Goomba'	-- TODO require name?

Goomba.sprite = 'animal_goomba'
--Goomba.seq = 'walk'
Goomba.walkSpeed = 0

return Goomba
