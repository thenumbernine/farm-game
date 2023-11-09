local Obj = require 'farmgame.obj.obj'
-- TODO instead call this 'battleent' or something
local function applyEnemy(parent)
	parent = parent or Obj
	local Enemy = require 'farmgame.obj.takesdamage'(parent):subclass()

	-- if player is within N squares of a monster ...
	-- ... (via flood-fill, same as lights?) ...
	-- ... then we start a battle

	-- or if the player walks up to a friendly and attacks it, then it goes enemy, and yeah enter battle
	function Enemy:update(...)
		Enemy.super.update(self, ...)
		local game = self.game	-- \__ why separate these two? ...
		local app = game.app	-- /
		for _,appPlayer in ipairs(app.players) do
			if appPlayer ~= self.appPlayer then
				-- TODO .objs ?  for teams?
				-- and then give appPlayer a viewFollow? (right now it's set to .game so ...)
				local player = appPlayer.obj
				local dist = (player.pos - self.pos):length()	-- TODO l1? l-inf?
				if dist < game.battleDistance then
					-- start new battle
					game:newBattle(player, self.player)
				end
			end
		end
	end

	return Enemy
end
return applyEnemy
