--[[
obj/unit holds the object in the map that represents the player
	(stored alongside all the other objects)
player holds the client-specific stuff
	(stored in a list of per client stuff)
--]]
local class = require 'ext.class'
local table = require 'ext.table'
local ig = require 'imgui'

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
	'openInventory',
	-- quick cycle inventory
	'invLeft',
	'invRight',
	-- rotate view
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

-- dialog prompt
function Player:dialogPrompt(msg, title)
	self.gamePrompt = function()
		ig.igBegin(title..'###PlayerWindow', nil, bit.bor(
			ig.ImGuiWindowFlags_NoMove,
			ig.ImGuiWindowFlags_NoResize,
			ig.ImGuiWindowFlags_NoCollapse
		))
		ig.igText(msg)
		if ig.igButton'Ok###PlayerWindowOk' then
			self.gamePrompt = nil
		end
		ig.igEnd()
	end
end

--[[
options: table with ...
	name
	cost
	seedClass or objClass

farmgame.plants and farmgame.animals works for this
--]]
function Player:storePrompt(options)
	local player = self.obj
	self.gamePrompt = function()
		-- option is plantType or animalType
		local function buy(option, count)
			assert(count > 0)
			local cost = option.cost * count
			if cost <= self.money then
				local cl = option.seedClass or option.objClass
				if player:addItem(cl, count) then
					self.money = self.money - cost
				else
					self:dialogPrompt("new room in inventory", "sorry")
				end
			end
		end

		local size = ig.igGetMainViewport().WorkSize
		ig.igSetNextWindowPos(ig.ImVec2(size.x/2, 0), ig.ImGuiCond_Appearing, ig.ImVec2(.5, 0));
		ig.igBegin('Store Guy', nil, bit.bor(
			ig.ImGuiWindowFlags_NoMove,
			ig.ImGuiWindowFlags_NoResize,
			ig.ImGuiWindowFlags_NoCollapse
		))
		ig.igSetWindowFontScale(.5)

		ig.igText"want to buy something?"

		if ig.igButton'Ok###Ok2' then
			self.gamePrompt = nil
		end

		for i,option in ipairs(options) do
			for _,x in ipairs{1, 10, 100} do
				if ig.igButton('x'..x..'###'..i..'x'..x) then
					buy(option, x)
				end
				ig.igSameLine()
			end
			ig.igText('$'..option.cost..': '..option.name)
		end

		if #options > 0 then
			if ig.igButton'Ok' then
				self.gamePrompt = nil
			end
		end

		ig.igSetWindowFontScale(1)
		ig.igEnd()
	end
end

-- TODO turn this into 'craftingPrompt'
-- or maybe even generalize stores into this as well ... after all, they are just money -> goods ...
function Player:craftPrompt(craftOptions)
	local player = self.obj
	self.gamePrompt = function()
		local size = ig.igGetMainViewport().WorkSize
		ig.igSetNextWindowPos(ig.ImVec2(size.x/2, 0), ig.ImGuiCond_Appearing, ig.ImVec2(.5, 0));
		ig.igBegin('Crafting', nil, bit.bor(
			ig.ImGuiWindowFlags_NoMove,
			--ig.ImGuiWindowFlags_NoResize,
			ig.ImGuiWindowFlags_NoCollapse
		))
		ig.igSetWindowFontScale(.5)

		if ig.igButton'Ok###Ok2' then
			self.gamePrompt = nil
		end

		for i,opt in ipairs(craftOptions) do
			local can = true
			for _,inp in ipairs(opt.input) do
				if not player:hasItem(inp.class, inp.count) then
					can = false
					break
				end
			end
			if can then
				if ig.igButton('Go!###'..i) then
					for _,inp in ipairs(opt.input) do
						-- TODO what if something sneaks in between the gui detect and gui process?
						-- ... can anything?  I hope not ...
						assert(player:removeItem(inp.class, inp.count))
					end
					for _,outp in ipairs(opt.output) do
						player:addItem(outp.class, outp.count)
					end
				end
				for _,inp in ipairs(opt.input) do
					ig.igSameLine()
					ig.igText(inp.class.name..' x'..inp.count)
				end
				ig.igSameLine()
				ig.igText' => '
				for _,outp in ipairs(opt.output) do
					ig.igSameLine()
					ig.igText(outp.class.name..' x'..outp.count)
				end
			end
		end

		if #craftOptions > 0 then
			if ig.igButton'Ok' then
				self.gamePrompt = nil
			end
		end

		ig.igSetWindowFontScale(1)
		ig.igEnd()
	end
end

-- only call on another thread / mainloop?
function Player:setMap(destMap, destPos)
	local player = assert(self.obj)
	player:unlink()
	player.map.objs:removeObject(player)
	player.map = assert(destMap)
	player.map.objs:insert(player)
	player:setPos(destPos)	-- calls :link
end

return Player
