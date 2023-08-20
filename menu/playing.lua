local ig = require 'imgui'
local Menu = require 'gameapp.menu.menu'

local PlayingMenu = Menu:subclass()

function PlayingMenu:init(app)
	PlayingMenu.super.init(self, app)
	app.paused = false
end

function PlayingMenu:update()
	self.app:drawTouchRegions()
end

function PlayingMenu:updateGUI()
	local app = self.app
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
		ig.ImGuiWindowFlags_NoBackground
	))
	ig.igSetWindowFontScale(.5)
	ig.igText('$'..player.money)
	ig.igSetWindowFontScale(1)

	ig.igEnd()
	--]]

	--[[ if esc / pause-key was pushed ...
	if app.paused then
		local size = ig.igGetMainViewport().WorkSize
		ig.igSetNextWindowPos(ig.ImVec2(size.x/2, size.y/2), ig.ImGuiCond_Appearing, ig.ImVec2(.5, .5));
		ig.igBegin'Paused'
		if ig.igButton(app.paused and 'Resume' or 'Pause') then
			app.paused = not app.paused
		end
		if ig.igButton'Config' then
			app.pushMenuState = app.menustate
			app.menustate = Menu.Config(app)
		end
		if ig.igButton'End Game' then
			app:endGame()
		end
		ig.igEnd()
	end
	--]]

	if playerObj.gamePrompt then
		-- TODO put zindex of new windows over the items, and just leave the items up
		playerObj.gamePrompt()
	else

		local maxItems = 12
		local bw = math.floor(app.width / maxItems)
		local bh = bw
		local x = 0
		local y = app.height - bh - 4
		ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ButtonTextAlign, ig.ImVec2(.5, .5))

		for i=1,maxItems do
			local item = playerObj.items[i]

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
				ig.ImGuiWindowFlags_Tooltip
			))
			ig.igSetWindowFontScale(.5)
			--[[
			if selected then
				ig.igPushStyleVar_Float(ig.ImGuiStyleVar_FrameBorderSize, 1)
			end
			--]]
			local name = '###'..i
			if item then name = item.name..name end
			ig.igButton(name, ig.ImVec2(bw,bh))
		

			--[[
			if selected then
				ig.igPopStyleVar(1)
			end
			--]]
			ig.igEnd()

			if selected then
				ig.igPopStyleColor(1)
			end

			x = x + bw
		end
		ig.igPopStyleVar(1)
	end
end

return PlayingMenu
