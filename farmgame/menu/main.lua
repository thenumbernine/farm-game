local table = require 'ext.table'

-- just hack the main menu class instead of subclassing it.
local GameAppMainMenu = require 'gameapp.menu.main'

local MainMenu = GameAppMainMenu:subclass() 

MainMenu.menuOptions = table(MainMenu.menuOptions)

MainMenu.menuOptions:removeObject(nil, function(o)
	return o.name == 'New Game Co-op'
end)
MainMenu.menuOptions:removeObject(nil, function(o)
	return o.name == 'High Scores'
end)
MainMenu.menuOptions:insert(3, {
	name = 'Save Game',
	click = function(self)
		-- TODO save menu?
		-- or TODO pick a filename upon 'new game' and just save there?
		local app = self.app
		local game = app.game
		if not game then return end
		app:saveGame(app.saveBaseDir/game.saveDir)
		-- TODO print upon fail or something
	end,
	visible = function(self)
		return not not (self.app and self.app.game)
	end,
})

MainMenu.menuOptions:insert(4, {
	name = 'Load Game',
	click = function(self)
		local app = self.app
		app.menu = require 'farmgame.menu.loadgame'(app)
	end,
	visible = function(self)
		local app = self.app
		-- TODO detect upon construction and upon save?
		local num = 0
		if app.saveBaseDir:exists()
		and app.saveBaseDir:isdir() then
			for fn in app.saveBaseDir:dir() do
				if (app.saveBaseDir/fn):isdir() then
					num = num + 1
				end
			end
		end
		return num > 0
	end,
})

-- [[ draw the background as an opengl quad
function MainMenu:updateGUI(...)
	local app = self.app
	local view = app.view

	local aspectRatio = app.width / app.height
	view.projMat:setOrtho(-.5 * aspectRatio, .5 * aspectRatio, -.5, .5, -1, 1)
	view.mvMat
		:setTranslate(-.5 * aspectRatio, -.5)
		:applyScale(aspectRatio, 1)
	view.mvProjMat:mul4x4(view.projMat, view.mvMat)

	local sceneObj = app.splashMenu.splashSceneObj
	sceneObj.uniforms.mvProjMat = view.mvProjMat.ptr
	sceneObj:draw()
	
	MainMenu.super.updateGUI(self, ...)
end
--]]

--[[ draw the background as a imgui image ...
-- ugh makes me tempted to switch back to my own gui
local ig = require 'imgui'
local ffi = require 'ffi'
function MainMenu:updateGUI(...)
	MainMenu.super.updateGUI(self, ...)
	local tex = app.splashMenu.splashSceneObj.texs[1]
	local posMin = ig.igGetCursorScreenPos()
	local windowPos = ig.ImVec2()
	ig.igGetWindowPos(windowPos)
	local windowSize = ig.ImVec2()
	ig.igGetWindowSize(windowSize)
	local posMax = ig.ImVec2(
		windowPos.x + windowSize.x - .5,
		windowPos.y + windowSize.y - .5)
	local drawlist = ig.igGetWindowDrawList()
	ig.ImDrawList_AddImage(
		drawlist,
		ffi.cast('void*', tex.id),
		posMin,
		posMax,
		ig.ImVec2(0, 1),
		ig.ImVec2(0, 1),
		0xffffffff
	)
end
--]]

return MainMenu
