--[[
obj/player holds the object in the map that represents the player
	(stored alongside all the other objects)
player holds the client-specific stuff
	(stored in a list of per client stuff)
--]]
local class = require 'ext.class'
local table = require 'ext.table'

-- TODO instances should be a member of game?
local Player = class()

-- gameplay keys to record for demos (excludes pause)
Player.gameKeyNames = table{
	'up',
	'down',
	'left',
	'right',
	'jump',
	'useItem',
	'interact',
	'rotateLeft',
	'rotateRight',
}

-- all keys to capture via sdl events during gameplay
Player.keyNames = table(Player.gameKeyNames):append{
	'pause',
}

-- set of game keys (for set testing)
Player.gameKeySet = Player.gameKeyNames:mapi(function(k)
	return true, k
end):setmetatable(nil)

function Player:init(args)
	self.app = assert(args.app)
	self.index = assert(args.index)
	self.keyPress = {}
	self.keyPressLast = {}
	for _,k in ipairs(self.keyNames) do
		self.keyPress[k] = false
		self.keyPressLast[k] = false
	end

	self.money = 1000
end

return Player 
