local vec3f = require 'vec-ffi.vec3f'
local Obj = require 'zelda.obj.obj'

local Plant = Obj:subclass()

Plant.name = 'Plant'

Plant.sprite = 'plant1'
Plant.useGravity = false	-- true?
Plant.collidesWithTiles = false	-- this slows things down a lot.  so just turn off gravity and dont test with world.
Plant.collidesWithObjects = false --?

function Plant:init(args, ...)
	Plant.super.init(self, args, ...)
	self.numLogs = args.numLogs
end

function Plant:onChopDown()
	local game = self.game
	game.threads:add(function()
		game:fade(1, function(alpha)
			-- TODO 3d model?
			self.drawAngle = -alpha * math.pi * .5
		end)
		self:remove()
	
		-- and then add a bunch of wood items
		for i=1,(self.numLogs or 0) do
			local r = math.random() * 2
			local theta = math.random() * 2 * math.pi
			game:newObj{
				class = require 'zelda.obj.log',
				pos = self.pos + vec3f(
					math.cos(theta) * r,
					math.sin(theta) * r,
					0
				)
			}
		end
	end)
end

return Plant 
