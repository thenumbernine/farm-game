-- behavior
local function takesDamage(parent)
	local cl = parent:subclass()
	cl.classname = nil
	
	cl.takesDamage = true
	cl.hpMax = 1

	function cl:init(args)
		cl.super.init(self, args)

		self.hpMax = args.hpMax
		assert(self.hpMax)	-- either override or class static

		-- filter for what inflictor types are allowed
		self.inflictTypes = args.inflictTypes

		-- idk why you would want to start an enemy off at less than optimal HP but the feature is available ...
		self.hp = args.hp or self.hpMax
	end

	-- inflicter might be an object in the case of a projectile
	--  or in the case of an inventory equipped item it might be a class
	-- returns true if damage was taken, false otherwise
	function cl:damage(amount, attacker, inflicter)
		if self.dead then return end

		if self.inflictTypes then
			if not (inflicter and self.inflictTypes[inflicter.name]) then
				return
			end
		end

		self.hp = self.hp - amount
--print('lost', amount, 'now at', self.hp)
		if self.hp <= 0 then
			self.dead = true
			self:die()
		end

		return true
	end

	function cl:die()
		-- death effect
		local game = self.game

		-- flip over, fade out, float up in the air

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
				self.colorMatrix[{4,4}] = 1 - alpha
			end)
			self:remove()
		end)

	end

	return cl
end

return takesDamage
