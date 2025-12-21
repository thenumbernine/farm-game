local table = require 'ext.table'
local ig = require 'imgui'
local Obj = require 'farmgame.obj.obj'
local GameAppPlayingMenu = require 'gameapp.menu.playing'

local PlayingMenu = GameAppPlayingMenu:subclass()

function PlayingMenu:updateGUI()
	local app = self.app
	local game = app.game
	local appPlayer = app.players[1]
	local player = appPlayer.obj

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
	ig.igText('HP: '..player.hp..'/'..player.hpMax)
	ig.igText('FP: '..player.food..'/'..player.foodMax)
	ig.igText(game:timeToStr())
	if true then
		ig.igText('pos '..tostring(player.pos))
		local number = require'ext.number'
		local s = number.tostring(player.collideFlags, 2)
		s = ('0'):rep(7-#s)..s
		ig.igText('collideFlags '..s)
		ig.igText('#sprites '..game.numSpritesDrawn)
	end

	if ig.igButton'Console' then
		self.consoleOpen = not self.consoleOpen
	end

	ig.igSetWindowFontScale(1)
	ig.igEnd()
	--]]


	-- taken from imgui/tests/console.lua
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
		if not ig.igIsAnyItemActive() then
			ig.igSetKeyboardFocusHere(0)
		end
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
			local env = setmetatable({
				app = app,
				game = game,
				player = player,
				map = player.map,
				appPlayer = appPlayer,
			}, {
				__index = _G,
			})
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
	end
	--else .. ?
	do
		local chestOpen = appPlayer.chestOpen
		-- TODO this matches what's in farmgame.obj.unit ...
		local maxItems = player.numSelectableItems
		if appPlayer.invOpen then
			maxItems = player.numInvItems
			if chestOpen then
				maxItems = maxItems + chestOpen.numInvItems
			end
		end

		local bw = math.floor(app.width / player.numSelectableItems)
		local bh = bw
		local x = 0
		local y = app.height - bh - 4
		ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ButtonTextAlign, ig.ImVec2(0,0))	-- one of these desn't work in cimgui 1.91.9

		for iMinus1=0,maxItems-1 do
			local i = iMinus1 + 1
			local itemInfo
			if i <= player.numInvItems then
				itemInfo = player.items[i]
			elseif i <= player.numInvItems + chestOpen.numInvItems then
				itemInfo = chestOpen.items[i - player.numInvItems]
			else
				error("shouldn't be here")
			end

			local selected = appPlayer.selectedItem == i
			if selected then
				local selectColor = ig.ImVec4(0,0,1,.5)
				ig.igPushStyleColor_Vec4(ig.ImGuiCol_Button, selectColor)	-- one of these desn't work in cimgui 1.91.9
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
			if selected then
				ig.igPushStyleVar_Float(ig.ImGuiStyleVar_FrameBorderSize, 1)
			end
			ig.igPushID_Int(i)
			if self:itemButton(itemInfo, bw, bh) then
				appPlayer.selectedItem = i
			end
			ig.igPopID()

			if selected then
				ig.igPopStyleVar(1)
			end
			ig.igEnd()

			if selected then
				ig.igPopStyleColor(1)
			end

			if iMinus1 % player.numSelectableItems == player.numSelectableItems-1 then
				x = 0
				y = y - bh
				if i == player.numInvItems then
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
local anim = require 'farmgame.anim'
function PlayingMenu:itemButton(itemInfo, bw, bh)
	local app = self.app
	ig.igSetCursorPos(ig.ImVec2(0,0))
	local size = ig.ImVec2(bw, bh)
	if itemInfo then
		local cl = assert(itemInfo.class)
		local frame = Obj.getFrame(cl.sprite, cl.seq, 1, 0, app)
		if frame
		and frame.atlasTcPos
		and frame.atlasTcSize
		then
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
				cr = cl.colorMatrix.ptr[0]
				cg = cl.colorMatrix.ptr[5]
				cb = cl.colorMatrix.ptr[10]
			end
			local result = ig.igImageButton('',
				ffi.cast('ImTextureID', app.spriteAtlasTex.id),
				size,		-- how come the image gets clipped?
				ig.ImVec2(
					frame.atlasTcPos.x / app.spriteAtlasTex.width,
					frame.atlasTcPos.y / app.spriteAtlasTex.height
				),
				ig.ImVec2(
					(frame.atlasTcPos.x + frame.atlasTcSize.x) / app.spriteAtlasTex.width,
					(frame.atlasTcPos.y + frame.atlasTcSize.y) / app.spriteAtlasTex.height
				),
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

		if itemInfo.count == 1 then
			return ig.igButton(cl.name, size)
		else
			return ig.igButton(cl.name..'\nx'..itemInfo.count, size)
		end
	end
	return ig.igButton('', size)
end

return PlayingMenu
