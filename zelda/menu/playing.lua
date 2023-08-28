local ig = require 'imgui'
local table = require 'ext.table'
local GameAppPlayingMenu = require 'gameapp.menu.playing'

local PlayingMenu = GameAppPlayingMenu:subclass()

function PlayingMenu:startNewGame()
	local app = self.app
	-- sets app.paused = false
	PlayingMenu.super.startNewGame(self)

	app:resetGame()
end

function PlayingMenu:updateGUI()
	local app = self.app
	local game = app.game
	local player = app.players[1]
	local playerObj = player.obj

	-- [[
	ig.igSetNextWindowPos(ig.ImVec2(0, 0), 0, ig.ImVec2())
	ig.igSetNextWindowSize(ig.ImVec2(-1, -1), 0)
	ig.igBegin('X', nil, bit.bor(
		ig.ImGuiWindowFlags_NoMove,
		ig.ImGuiWindowFlags_NoResize,
		ig.ImGuiWindowFlags_NoCollapse,
		ig.ImGuiWindowFlags_NoDecoration,
		ig.ImGuiWindowFlags_NoBackground,
		ig.ImGuiWindowFlags_NoNav		-- because nav = igio can-capture = tells gameapp sdl events not to capture
	))
	ig.igSetWindowFontScale(.5)

	ig.igText('$'..player.money)
	ig.igText(game:timeToStr())
	ig.igText(tostring(playerObj.pos))

	if ig.igButton'Console' then
		self.consoleOpen = not self.consoleOpen
	end

	ig.igSetWindowFontScale(1)
	ig.igEnd()
	--]]


	-- taken from imguiapp/tests/console.lua
	if self.consoleOpen then
		-- how do you change in-window font-scale *AND* window-title-bar font-scale? ...
		--[[ can't do this, it won't set.  maybe it takes a frame for imgui to respond?
		local igio = ig.igGetIO()
		local oldScale = igio[0].FontGlobalScale
		igio[0].FontGlobalScale = 1
		--]]
		ig.luatableBegin('Console', self, 'consoleOpen',
			bit.bor(
				ig.ImGuiWindowFlags_NoTitleBar,
				ig.ImGuiWindowFlags_NoCollapse,
				ig.ImGuiWindowFlags_NoNav
				--ig.ImGuiWindowFlags_NoBackground,
				--ig.ImGuiWindowFlags_Tooltip
			)
		)
		-- [[ this only changes in-window scale
		-- cheap hack in the mean time: no titlebar
		ig.igSetWindowFontScale(.5)
		--]]
		local size = ig.igGetWindowSize()
		self.consoleBuffer = self.consoleBuffer or ''
		if ig.luatableInputTextMultiline('code', self, 'consoleBuffer',
			ig.ImVec2(size.x,size.y - 64),
			ig.ImGuiInputTextFlags_EnterReturnsTrue
			+ ig.ImGuiInputTextFlags_AllowTabInput)
		or ig.igButton('run code')
		then
			print('executing...\n'..self.consoleBuffer)
			local env = setmetatable({app=app, game=game, player=player}, {__index=_G})
			local f, err = load(self.consoleBuffer, nil, nil, env)
			if not f then
				print(err)
			else
				local res = table.pack(pcall(f))
				if not res:remove(1) then
					print(res[1])
				else
					res.n = res.n - 1	-- remove() doesn't do this
					if res.n > 0 then
						print(res:unpack())
					end
				end
			end
		end
		ig.igSameLine()
		if ig.igButton'clear code' then
			self.consoleBuffer = ''
		end
		ig.igSetWindowFontScale(1)
		ig.igEnd()

		--igio[0].FontGlobalScale = oldScale
	end


	if playerObj.gamePrompt then
		-- TODO put zindex of new windows over the items, and just leave the items up
		playerObj.gamePrompt()
	else

		local maxItems = player.invOpen
			and playerObj.numInvItems
			or playerObj.numSelectableItems

		local bw = math.floor(app.width / playerObj.numSelectableItems)
		local bh = bw
		local x = 0
		local y = player.invOpen
			and (app.height - bh * 4 - 4)
			or (app.height - bh - 4)
		ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ButtonTextAlign, ig.ImVec2(0,0))

		for iMinus1=0,maxItems-1 do
			local i = iMinus1 + 1
			local itemInfo = playerObj.items[i]

			local selected = playerObj.selectedItem == i
			if selected then
				local selectColor = ig.ImVec4(0,0,1,.5)
				ig.igPushStyleColor_Vec4(ig.ImGuiCol_Button, selectColor)
			end

			ig.igSetNextWindowPos(ig.ImVec2(x,y), 0, ig.ImVec2())
			ig.igSetNextWindowSize(ig.ImVec2(bw, bh), 0)
			ig.igBegin('inventory '..i, nil, bit.bor(
				ig.ImGuiWindowFlags_NoTitleBar,
				ig.ImGuiWindowFlags_NoResize,
				ig.ImGuiWindowFlags_NoScrollbar,
				ig.ImGuiWindowFlags_NoCollapse,

				ig.ImGuiWindowFlags_NoBackground,
				ig.ImGuiWindowFlags_Tooltip,

				ig.ImGuiWindowFlags_NoNav	-- nav is bad for my app capturing sdl input
			))
			ig.igSetWindowFontScale(.5)
			--[[
			if selected then
				ig.igPushStyleVar_Float(ig.ImGuiStyleVar_FrameBorderSize, 1)
			end
			--]]
			local name = '###'..i
			if itemInfo then
				if itemInfo.count == 1 then
					name = itemInfo.class.name..name
				else
					name = itemInfo.class.name..'\nx'..itemInfo.count..name
				end
			end
			if ig.igButton(name, ig.ImVec2(bw,bh)) then
				playerObj.selectedItem = i
			end


			--[[
			if selected then
				ig.igPopStyleVar(1)
			end
			--]]
			ig.igEnd()

			if selected then
				ig.igPopStyleColor(1)
			end

			if iMinus1 % playerObj.numSelectableItems == playerObj.numSelectableItems-1 then
				x = 0
				y = y + bh
			else
				x = x + bw
			end
		end
		ig.igPopStyleVar(1)
	end
end

return PlayingMenu
