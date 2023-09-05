local ig = require 'imgui'
local table = require 'ext.table'
local GameAppPlayingMenu = require 'gameapp.menu.playing'

local PlayingMenu = GameAppPlayingMenu:subclass()

-- called from gameapp.menu.newgame
function PlayingMenu:startNewGame()
	local app = self.app
	-- sets app.paused = false
	PlayingMenu.super.startNewGame(self)

	app:resetGame()
end

function PlayingMenu:updateGUI()
	local app = self.app
	local game = app.game
	local appPlayer = app.players[1]
	local playerObj = appPlayer.obj

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

	ig.igText('$'..appPlayer.money)
	ig.igText('HP: '..playerObj.hp..'/'..playerObj.hpMax)
	ig.igText('FP: '..playerObj.food..'/'..playerObj.foodMax)
	ig.igText(game:timeToStr())
	if true then
		ig.igText(tostring(playerObj.pos))
		ig.igText('#sprites '..game.numSpritesDrawn)
	end

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
			local env = setmetatable({app=app, game=game, player=appPlayer}, {__index=_G})
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


	if appPlayer.gamePrompt then
		-- TODO put zindex of new windows over the items, and just leave the items up
		appPlayer.gamePrompt()
	else
		local chestOpen = appPlayer.chestOpen
		-- TODO this matches what's in zelda.obj.player ...
		local maxItems = playerObj.numSelectableItems
		if appPlayer.invOpen then
			maxItems = playerObj.numInvItems
			if chestOpen then
				maxItems = maxItems + chestOpen.numInvItems
			end
		end

		local bw = math.floor(app.width / playerObj.numSelectableItems)
		local bh = bw
		local x = 0
		local y = app.height - bh - 4
		ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ButtonTextAlign, ig.ImVec2(0,0))

		for iMinus1=0,maxItems-1 do
			local i = iMinus1 + 1
			local itemInfo
			if i <= playerObj.numInvItems then
				itemInfo = playerObj.items[i]
			elseif i <= playerObj.numInvItems + chestOpen.numInvItems then
				itemInfo = chestOpen.items[i - playerObj.numInvItems]
			else
				error("shouldn't be here")
			end

			local selected = playerObj.selectedItem == i
			if selected then
				local selectColor = ig.ImVec4(0,0,1,.5)
				ig.igPushStyleColor_Vec4(ig.ImGuiCol_Button, selectColor)
			end

			-- TODO maybe instead, use igSetCursorPos and use a full-sized no-background window?
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
			ig.igPushID_Int(i)
			if self:itemButton(itemInfo, bw, bh) then
				playerObj.selectedItem = i
			end
			ig.igPopID()

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
				y = y - bh
				if i == playerObj.numInvItems then
					y = y - math.floor(bh/2)
				end
			else
				x = x + bw
			end
		end
		ig.igPopStyleVar(1)
	end
end

local ffi = require 'ffi'
local anim = require 'zelda.anim'
function PlayingMenu:itemButton(itemInfo, bw, bh)
	ig.igSetCursorPos(ig.ImVec2(0,0))
	local size = ig.ImVec2(bw, bh)
	if itemInfo then
		local cl = assert(itemInfo.class)
		if cl.sprite and cl.seq then
			local sprite = anim[cl.sprite]
			if sprite then
				local seq = sprite[cl.seq]
				if seq then
					local frame = seq[1]
					if frame then
						local tex = frame.tex
						if tex then
							--local tw, th = tex.width, tex.height
							-- why isn't bw x bh the same for imagebutton and for button?
							size = ig.ImVec2(bw, bh 
								-- * th / tw	-- maybe not worth it ...
							)
							local cr,cg,cb = 1,1,1
							-- assume the color matrix <-> scale matrix
							-- hmm otherwise how to draw imgui icons?
							if cl.colorMatrix then
								-- will only color by the 1st row
								cr,cg,cb = cl.colorMatrix.ptr[0], cl.colorMatrix.ptr[5], cl.colorMatrix.ptr[10]
							end
							local result = ig.igImageButton('',
								ffi.cast('void*', tex.id),
								size,		-- how come the image gets clipped?
								ig.ImVec2(0,0),
								ig.ImVec2(1,1),
								ig.ImVec4(0,0,0,0),
								ig.ImVec4(cr,cg,cb,1)) 
							if itemInfo.count > 1 then
								-- why isn't 0,0 the upper-left corner of text?
								-- y-offset i'd understand (top vs bottom coordinate origin)
								-- but why is it x-offset as well?
								ig.igSetCursorPos(ig.ImVec2(8,4))
								ig.igText('x'..itemInfo.count)
							end
							return result
						end
					end
				end
			end
		end

		if itemInfo.count == 1 then
			return ig.igButton(cl.name, size)
		else
			return ig.igButton(cl.name..'\nx'..itemInfo.count, size)
		end
	end
	return ig.igButton('', size)
end

return PlayingMenu
