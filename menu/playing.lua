--[[
TODO move this back to gameapp.menu
--]]
local ig = require 'imgui'
local sdl = require 'ffi.req' 'sdl'
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
		ig.ImGuiWindowFlags_NoBackground
	))
	ig.igSetWindowFontScale(.5)
	ig.igText('$'..player.money)
	ig.igText(game:timeToStr())
	ig.igSetWindowFontScale(1)

	ig.igEnd()
	--]]

	if playerObj.gamePrompt then
		-- TODO put zindex of new windows over the items, and just leave the items up
		playerObj.gamePrompt()
	else

		local maxItems = playerObj.maxItems
		local bw = math.floor(app.width / maxItems)
		local bh = bw
		local x = 0
		local y = app.height - bh - 4
		ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ButtonTextAlign, ig.ImVec2(0,0))

		for i=1,maxItems do
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
				ig.ImGuiWindowFlags_Tooltip
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

function PlayingMenu:event(e)
	local app = self.app
	if e.type == sdl.SDL_KEYDOWN
	and e.key.keysym.sym == sdl.SDLK_ESCAPE
	and app.game
	then
		app.paused = true
		app.menu = app.mainMenu
	end
end

return PlayingMenu
