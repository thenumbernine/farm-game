local ffi = require 'ffi'
local sdl = require 'ffi.req' 'sdl'
local class = require 'ext.class'
local table = require 'ext.table'
local vec2f = require 'vec-ffi.vec2f'
local vec3i = require 'vec-ffi.vec3i'
local vec3f = require 'vec-ffi.vec3f'
local vec4f = require 'vec-ffi.vec4f'
local Image = require 'image'
local gl = require 'gl'
local GLTex2D = require 'gl.tex2d'
local GLProgram = require 'gl.program'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLGeometry = require 'gl.geometry'
local GLSceneObject = require 'gl.sceneobject'
local Map = require 'zelda.map'
local Tile = require 'zelda.tile'
local Obj = require 'zelda.obj.obj'
local ThreadManager = require 'threadmanager'

-- put this somewhere as to not give it a require loop
assert(not Obj.classes)
Obj.classes = require 'zelda.obj.all'

local function hexcolor(i)
	return
		bit.band(0xff, bit.rshift(i,16))/255,
		bit.band(0xff, bit.rshift(i,8))/255,
		bit.band(0xff, i)/255,
		1
end

-- t = table of {.weight=...}
local function pickWeighted(t)
	local totalWeight = 0
	for _,p in ipairs(t) do
		totalWeight = totalWeight + p.weight
	end
	local pickWeight = totalWeight * math.random()
	for _,p in ipairs(t) do
		pickWeight = pickWeight - p.weight
		if pickWeight <= 0 then return p end
	end
	error"here"
end

local Game = class()

Game.secondsPerMinute = 1

Game.minutesPerHour = 60
Game.secondsPerHour = Game.secondsPerMinute * Game.minutesPerHour

Game.hoursPerDay = 24
Game.secondsPerDay = Game.secondsPerHour * Game.hoursPerDay

-- when to start / wake up
Game.wakeHour = 6

-- 16 x 16 = 256 tiles in a typical screen
-- 8 x 8 x 8 = 512 tiles
function Game:init(args)
	self.app = assert(args.app)
	local app = self.app

	-- start at 6am on the first day
	self.time = self.wakeHour * self.secondsPerHour
	
	self.threads = ThreadManager()

	self.quadVtxBuf = app.quadVertexBuf
	self.quadGeom = app.quadGeom

	-- TODO would be nice per-hour-of-the-day ...
	-- why am I not putting this in a texture?
	-- because I also want a gradient for at-ground vs undergournd
	-- but maybe I still should ..
	local skyTexData = {
		{{10, 10, 20}, {50, 50, 85}},
		{{80, 80, 120}, {70, 80, 110}},
		{{80, 120, 140}, {140, 170, 200}},
		{{0, 100, 170}, {255, 100, 0}},
		{{10, 10, 20}, {50, 50, 85}},
	}

	self.skyTex = GLTex2D{
		image = Image(#skyTexData, #skyTexData[1], 4, 'unsigned char', function(u,v)
			local t = skyTexData[u+1][v+1]
			return t[1], t[2], t[3], 255
		end),
		minFilter = gl.GL_NEAREST,
		magFilter = gl.GL_LINEAR,
		wrap = {
			s = gl.GL_CLAMP_TO_EDGE,
			t = gl.GL_CLAMP_TO_EDGE,
		},
	}

	self.skyShader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec2 vertex;
out vec2 vtxv;
uniform mat4 mvProjMat;
void main() {
	vtxv = vertex;
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
}
]],
		fragmentCode = app.glslHeader..[[
in vec2 vtxv;
out vec4 fragColor;
uniform float timeOfDay;
uniform sampler2D skyTex;
void main() {
	fragColor = texture(skyTex, vec2(timeOfDay, vtxv.y));
}
]],
		uniforms = {
			skyTex = 0,
		},
	}:useNone()

	self.skySceneObj = GLSceneObject{
		geometry = self.quadGeom,
		program = self.skyShader,
		attrs = {
			vertex = self.quadVtxBuf,
		},
		texs = {
			self.skyTex,
		},
	}

	self.spriteShader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec2 vertex;
out vec2 texcoordv;
out vec3 viewPosv;

uniform vec2 uvscale;
uniform vec2 drawCenter;
uniform vec2 drawSize;
uniform vec2 drawAngleDir;
uniform vec3 pos;

uniform mat4 viewMat;
uniform mat4 projMat;

void main() {
	texcoordv = (vertex - .5) * uvscale + .5;
	
	vec2 c = (drawCenter - vertex) * drawSize;
	c = vec2(
		c.x * drawAngleDir.x - c.y * drawAngleDir.y,
		c.x * drawAngleDir.y + c.y * drawAngleDir.x
	);
	vec4 worldpos = vec4(pos, 1.);
	vec3 ex = vec3(viewMat[0].x, viewMat[1].x, viewMat[2].x);
	vec3 ey = vec3(viewMat[0].y, viewMat[1].y, viewMat[2].y);
	worldpos.xyz += ex * c.x;
	worldpos.xyz += ey * c.y;
	
	vec4 viewPos = viewMat * worldpos;
	
	viewPosv = viewPos.xyz;

	gl_Position = projMat * viewPos;
}
]],
		fragmentCode = app.glslHeader..[[
in vec2 texcoordv;
in vec3 viewPosv;

out vec4 fragColor;

uniform sampler2D tex;
uniform vec4 color;

uniform bool useSeeThru;
uniform vec3 playerViewPos;

const float cosClipAngle = .9;	// = cone with 25 degree from axis 

// gl_FragCoord is in pixel coordinates with origin at lower-left
void main() {
	fragColor = color * texture(tex, texcoordv);

	// alpha-testing
	if (fragColor.a < .1) discard;

	if (useSeeThru) {
		vec3 testViewPos = playerViewPos + vec3(0., 1., -2.);
		if (normalize(viewPosv - testViewPos).z > cosClipAngle) {
			//fragColor.w = .2;
			discard;
		}
	}
}
]],
		uniforms = {
			tex = 0,
		},
	}:useNone()

	self.spriteSceneObj = GLSceneObject{
		geometry = self.quadGeom,
		program = self.spriteShader,
		attrs = {
			vertex = self.quadVtxBuf,
		},
		texs = {},
	}

	self.meshShader = require 'mesh':makeShader{
		glslHeader = app.glslHeader,
	}

	self.swordShader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec3 vertex;
in vec4 color;
out vec4 colorv;
uniform mat4 mvProjMat;
void main() {
	colorv = color;
	gl_Position = mvProjMat * vec4(vertex, 1.);
}
]],
		fragmentCode = app.glslHeader..[[
in vec4 colorv;
out vec4 fragColor;
void main() {
	fragColor = colorv;
}
]],
	}:useNone()

	self.swordSwingNumDivs = 20
	self.swordSwingVtxBufCPU = ffi.new('vec3f_t[?]', 2 * self.swordSwingNumDivs)
	
	-- build the map

	self.texpack = GLTex2D{
		filename = 'texpack.png',
		magFilter = gl.GL_LINEAR,
		minFilter = gl.GL_NEAREST,
	}

	-- TODO chop into chunks for faster updates
	self.map = Map{
		game = self,
		sizeInChunks = vec3i(3, 2, 1),
	}


	local houseSize = vec3f(3, 3, 2)
	local houseCenter = vec3f(
		math.floor(self.map.size.x/2),
		math.floor(self.map.size.y*3/4),
		math.floor(self.map.size.z/2) + houseSize.z)

	-- copied in game's init
	local npcPos = vec3f(
		self.map.size.x*.95,
		self.map.size.y*.5,
		self.map.size.z-.5)
	
	do
		local simplexnoise = require 'simplexnoise.3d'
	--print'generating map'
		local map = self.map
		local maptexs = {
			grass = 0,
			stone = 1,
			wood = 2,
		}

		-- simplex noise resolution
		local blockSize = 8
		local half = bit.rshift(map.size.z, 1)
		--local step = vec3i(1, map.size.x, map.size.x * map.size.y)
		--local ijk = vec3i()
		local xyz = vec3f()
		for k=0,map.size.z-1 do
			--ijk.z = k
			xyz.z = k / blockSize
			for j=0,map.size.y-1 do
				--ijk.y = j
				xyz.y = j / blockSize
				for i=0,map.size.x-1 do
					--ijk.x = i
					xyz.x = i / blockSize
					local c = simplexnoise(xyz:unpack())
					local maptype = Tile.typeValues.Empty
					local maptex = k >= half-1
						and maptexs.grass
						or maptexs.stone
					if k >= half then
						c = c + (k - half) * .5
					end

					-- [[ make the top flat?
					if k >= half
					and (
						(vec2f(i,j) - vec2f(houseCenter.x, houseCenter.y)):length() < 15
						or (vec2f(i,j) - vec2f(npcPos.x, npcPos.y)):length() < 5
					) then
						c = k == half and 0 or 1
					end
					--]]

					if c < .5 then
						maptype =
							maptex == maptexs.stone
							and Tile.typeValues.Stone
							or Tile.typeValues.Grass
					end
					--local index = ijk:dot(step)
					local tile = assert(map:getTile(i,j,k))
					tile.type = maptype
					tile.tex = maptex
				end
			end
		end

		do
			for x=houseCenter.x-houseSize.x,houseCenter.x+houseSize.x do
				for y=houseCenter.y-houseSize.y, houseCenter.y+houseSize.y do
					for z=houseCenter.z-houseSize.z, houseCenter.z+houseSize.z do
						local adx = math.abs(x - houseCenter.x)
						local ady = math.abs(y - houseCenter.y)
						local adz = math.abs(z - houseCenter.z)
						local linf = math.max(adx/houseSize.x, ady/houseSize.y, adz/houseSize.z)
						if linf == 1 then
							local tile = assert(map:getTile(x,y,z))
							tile.type = Tile.typeValues.Wood
							tile.tex = maptexs.wood
						end
					end
				end
				local t = assert(map:getTile(houseCenter.x, houseCenter.y - houseSize.y, houseCenter.z - houseSize.z + 1))
				t.type = 0
				t.tex = 0
				local t = assert(map:getTile(houseCenter.x, houseCenter.y - houseSize.y, houseCenter.z - houseSize.z + 2))
				t.type = 0
				t.tex = 0
			end
		end

	--print"building draw arrays"
		map:buildDrawArrays()
		map:buildAlts()
	--print'init done'
	end

	self.objs = table()
	app.players[1].obj = self:newObj{
		class = Obj.classes.Player,
		pos = vec3f(
			self.map.size.x*.5,
			self.map.size.y*.5,
			self.map.size.z-.5),
		player = assert(app.players[1]),
	}
					
	local ItemSeeds = require 'zelda.item.seeds'

	local game = self
	self:newObj{
		class = Obj.classes.NPC,
		pos = vec3f(
			self.map.size.x*.95,
			self.map.size.y*.5,
			self.map.size.z-.5),
		interactInWorld = function(interactObj, playerObj)
			local player = playerObj.player
--print('setting gamePrompt')
			playerObj.gamePrompt = function()
				local function buy(plant, amount)
					assert(amount > 0)
					local cost = plant.cost * amount
					if cost <= player.money then
						player.money = player.money - cost
						playerObj:addItem(ItemSeeds:makeSubclass(plant), amount)
					end
				end

				local ig = require 'imgui'
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
					playerObj.gamePrompt = nil
--print('clearing gamePrompt')
				end
			
				local plants = require 'zelda.plants'
				for i,plant in ipairs(plants) do
					for _,x in ipairs{1, 10, 100} do
						if ig.igButton('x'..x..'###'..i..'x'..x) then buy(plant, x) end
						ig.igSameLine()
					end
					ig.igText('$'..plant.cost..': '..plant.name)
				end

				if ig.igButton'Ok' then
					playerObj.gamePrompt = nil
--print('clearing gamePrompt')
				end
	
				ig.igSetWindowFontScale(1)
				ig.igEnd()		
			end
		end,
	}

	self:newObj{
		class = require 'zelda.obj.bed',
		pos = houseCenter + vec3f(houseSize.x-1, -(houseSize.y-1), -(houseSize.z-1)) + .5,
	}

	-- [[ plants
	for j=0,self.map.size.y-1 do
		for i=0,self.map.size.x-1 do
			local k = self.map.size.z-1
			while k >= 0 do
				local tile = self.map:getTile(i,j,k)
				if tile.type ~= Tile.typeValues.Empty
				and tile.tex == 0	-- grass tex
				then
					break
				end
				k = k - 1
			end
			if k >= 0 then
				-- found a grass tile
				local r = math.random()
				if (vec2f(i,j) - vec2f(houseCenter.x, houseCenter.y)):length() < 7.5
				or (vec2f(i,j) - vec2f(npcPos.x, npcPos.y)):length() < 5
				then
					r = 1
				end
				if r < .7 then
					local anim = require 'zelda.anim'
					local objInfo = pickWeighted{
						{sprite='tree1', weight=1, numLogs=10, hpMax=5},
						{sprite='tree2', weight=1, numLogs=10, hpMax=5},
						{sprite='bush1', weight=4, numLogs=2},
						{sprite='bush2', weight=4, numLogs=2},
						{sprite='bush3', weight=4, numLogs=2},
						{sprite='plant1', weight=8},
						{sprite='plant2', weight=8},
						{sprite='plant3', weight=8},
					}
					local tex = anim[objInfo.sprite].stand[1].tex
					self:newObj(table(objInfo, {
						class = require 'zelda.obj.plant',
						drawSize = vec2f(tex.width, tex.height) / 16,
						pos = vec3f(i + .5, j + .5, k + 1),
					}):setmetatable(nil))
				end
			end
		end
	end
	--]]
	
-- [[
	for k=1,5 do
		local i = math.random(tonumber(self.map.size.x))-1
		local j = math.random(tonumber(self.map.size.y))-1
		for _,dir in ipairs{{1,0},{0,1},{-1,0},{0,-1}} do
			local ux, uy = table.unpack(dir)
			local g = self:newObj{
				class = Obj.classes.Goomba,
				pos = vec3f(ux + i, uy + j, self.map.size.z-1),
			}
		end
	end
--]]
end

function Game:timeToStr()
	-- time scale?  1 second = 1 minute?
	local tm = math.floor(self.time) 
	local m = tm % self.minutesPerHour
	local th = (tm - m) / self.minutesPerHour
	local h = th % self.hoursPerDay
	local td = (th - h) / self.hoursPerDay
	-- for display's sake:
	if h == 0 then h = self.hoursPerDay end
	m = math.floor(m/10) * 10
	return ('%d %02d:%02d'):format(td,h,m)
end

function Game:newObj(args)
--print('new', args.class.name, 'at', args.pos)
	local cl = assert(args.class)
	args.game = self
	local obj = cl(args)
	self.objs:insert(obj)
	return obj
end

function Game:draw()
	local app = self.app
	local view = app.view

	self.viewFollow = app.players[1].obj
	--self.viewFollow = self.goomba

	-- before calling super.update and redoing the gl matrices, update view...
	--self.view.angle:fromAngleAxis(1,0,0,20)
	view.pos:set((self.viewFollow.pos + view.angle:zAxis() * app.viewDist):unpack())

	view:setup(app.width / app.height)
	--app.orbit.pos:set((app.view.angle:zAxis() * app.viewDist):unpack())

-- [[ sky
	do
		gl.glDisable(gl.GL_DEPTH_TEST)

		view.mvProjMat:setOrtho(0,1,0,1,-1,1)

		self.skySceneObj.uniforms.mvProjMat = view.mvProjMat.ptr
		self.skySceneObj.uniforms.timeOfDay = (self.time / self.secondsPerDay) % 1
		-- testing: 1 min = 1 day
		--self.skySceneObj.uniforms.timeOfDay = (self.time / 60) % 1
		self.skySceneObj:draw()

		gl.glEnable(gl.GL_DEPTH_TEST)

		view.mvProjMat:mul4x4(view.projMat, view.mvMat)
	end
--]]


	do
		-- [[ clip by fragcoord
		-- clip pos
		local x,y,z,w = view.mvMat:mul4x4v4(
			self.viewFollow.pos.x,
			self.viewFollow.pos.y,
			self.viewFollow.pos.z + .1)
		self.playerViewPos = vec4f(x,y,z,w)
		local x,y,z,w = view.mvProjMat:mul4x4v4(
			self.viewFollow.pos.x,
			self.viewFollow.pos.y,
			self.viewFollow.pos.z + .1)
		local normalizedDeviceCoordDepth = z / w
		local dnear = 0
		local dfar = 1
		local windowZ = normalizedDeviceCoordDepth * (dfar - dnear)*.5 + (dfar + dnear)*.5
		-- clip by depth ...
		self.playerClipPos = vec4f(x,y,z,w)
		--]]
		-- [[
		-- and clip by world z ...
		self.playerPos = vec3f(self.viewFollow.pos:unpack()) + .1
		--]]
	end

	self.map:draw()

	for _,obj in ipairs(self.objs) do
		obj:draw()
	end
end

function Game:update(dt)
	for _,obj in ipairs(self.objs) do
		if obj.update then obj:update(dt) end
	end

	-- now threads
	self.threads:update()

	-- only after update do the removals
	for i=#self.objs,1,-1 do
		local obj = self.objs[i]
		if obj.removeFlag then
			obj:unlink()
			table.remove(self.objs, i)
		end
	end

	self.time = self.time + dt
end

-- TODO only call this from a thread
function Game:sleep(seconds)
	assert(coroutine.isyieldable(coroutine.running()))
	local endTime = self.time + seconds
	while self.time < endTime do
		coroutine.yield()
	end
	-- final yield?
	--coroutine.yield()
end

function Game:fade(seconds, callback)
	assert(coroutine.isyieldable(coroutine.running()))
	local startTime = self.time
	local endTime = startTime + seconds
	while self.time < endTime do
		local alpha = (self.time - startTime) / (endTime - startTime)
		callback(alpha)
		coroutine.yield()
	end
	-- final callback(1) ?
	callback(1)
end

function Game:fadeAppTime(seconds, callback)
	assert(coroutine.isyieldable(coroutine.running()))
	local app = self.app
	-- TODO rename app.thisTime to app.time?
	local startTime = app.thisTime
	local endTime = startTime + seconds
	while app.thisTime < endTime do
		local alpha = (app.thisTime - startTime) / (endTime - startTime)
		callback(alpha)
		coroutine.yield()
	end
	-- final callback(1) ?
	callback(1)
end

function Game:reset()
	self.app.game = Game{app=self.app}
end

function Game:event(event, ...)
	local app = self.app
	local playerObj = app.players[1].obj
	if not playerObj then return end
	if event.type == sdl.SDL_KEYDOWN
	or event.type == sdl.SDL_KEYUP
	then
		local down = event.type == sdl.SDL_KEYDOWN

		-- menu items 1-12
		-- how about another two buttons for switching active menu left + right?
		-- or how about press a button to open menu, then in-menu arrow-keys switch current selected item
		-- and whatver that is among the top 12 is whatver you're selected on when you close menu
		-- and that way console controls work.
		if down then
			if event.key.keysym.sym >= ('1'):byte()
			and event.key.keysym.sym <= ('9'):byte()
			then
				playerObj.selectedItem = event.key.keysym.sym - ('1'):byte() + 1
			elseif event.key.keysym.sym == ('0'):byte() then
				playerObj.selectedItem = 10
			elseif event.key.keysym.sym == ('-'):byte() then
				playerObj.selectedItem = 11
			elseif event.key.keysym.sym == ('='):byte() then
				playerObj.selectedItem = 12
			end
		end
	end
end

return Game