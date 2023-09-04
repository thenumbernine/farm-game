local path = require 'ext.path'
local ig = require 'imgui'
local Menu = require 'gameapp.menu.menu'

local LoadGameMenu = Menu:subclass()

function LoadGameMenu:updateGUI()
	local app = self.app
	
	if ig.igButton'Back###1' then
		app.menu = app.mainMenu
	end

	local found 
	if app.saveBaseDir:exists()
	and app.saveBaseDir:isdir() then
		for fn in app.saveBaseDir:dir() do
			if path(fn):isdir() then
				found = true
				if ig.igButton(fn) then
					app:loadGame(app.saveBaseDir/fn)
					app.menu = app.playingMenu
					return
				end
			end
		end
	end

	if found then
		if ig.igButton'Back###2' then
			app.menu = app.mainMenu
		end
	end
end

return LoadGameMenu 
