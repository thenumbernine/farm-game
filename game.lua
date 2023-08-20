local ffi = require 'ffi'
local sdl = require 'ffi.req' 'sdl'
local class = require 'ext.class'
local table = require 'ext.table'
local Map = require 'zelda.map'
local Tile = require 'zelda.tile'
local gl = require 'gl'
local GLTex2D = require 'gl.tex2d'
local GLProgram = require 'gl.program'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLGeometry = require 'gl.geometry'
local GLSceneObject = require 'gl.sceneobject'
local vec2f = require 'vec-ffi.vec2f'
local vec3i = require 'vec-ffi.vec3i'
local vec3f = require 'vec-ffi.vec3f'
local vec4f = require 'vec-ffi.vec4f'
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

-- 16 x 16 = 256 tiles in a typical screen
-- 8 x 8 x 8 = 512 tiles
function Game:init(args)
	self.app = assert(args.app)
	local app = self.app

	self.time = 0
	self.threads = ThreadManager()

	self.quadVtxBuf = app.quadVertexBuf
	self.quadGeom = app.quadGeom

	self.skyColorBufCPU = ffi.new('vec4f_t[4]', {
		vec4f(hexcolor(0xda9134)),
		vec4f(hexcolor(0xda9134)),
		vec4f(hexcolor(0x313453)),
		vec4f(hexcolor(0x313453)),
	})
	self.skyColorBuf = GLArrayBuffer{
		size = ffi.sizeof(self.skyColorBufCPU),
		data = self.skyColorBufCPU,
	}:unbind()

	self.skyShader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec2 vertex;
in vec4 color;
out vec4 colorv;
uniform mat4 mvProjMat;
void main() {
	colorv = color;
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
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

	self.skySceneObj = GLSceneObject{
		geometry = self.quadGeom,
		program = self.skyShader,
		attrs = {
			vertex = self.quadVtxBuf,
			color = self.skyColorBuf,
		}
	}

	self.spriteShader = GLProgram{
		vertexCode = app.glslHeader..[[
in vec2 vertex;
out vec2 texcoordv;
out vec3 posv;

uniform vec2 uvscale;
uniform vec2 drawCenter;
uniform vec2 drawSize;
uniform vec2 drawAngleDir;
uniform vec3 pos;

uniform mat4 viewMat;
uniform mat4 projMat;

void main() {
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
	worldpos = viewMat * worldpos;
	
	posv = worldpos.xyz;

	texcoordv = (vertex - .5) * uvscale + .5;

	gl_Position = projMat * worldpos;
}
]],
		fragmentCode = app.glslHeader..[[
in vec2 texcoordv;
in vec3 posv;

out vec4 fragColor;

uniform sampler2D tex;
uniform vec4 color;

uniform vec4 viewport;
uniform vec4 playerViewPos;

// gl_FragCoord is in pixel coordinates with origin at lower-left
void main() {
	fragColor = color * texture(tex, texcoordv);

	// alpha-testing
	if (fragColor.a < .1) discard;

	// keep the dx dy outside the if block to prevent errors.
	//vec3 dx = dFdx(posv);
	//vec3 dy = dFdy(posv);
	if (length(
			gl_FragCoord.xy - .5 * viewport.zw
		) < .35 * viewport.w
	) {
		//vec3 n = normalize(cross(dx, dy));
		//if (dot(n, playerPos - posv) < -.01) 
		
		//if (gl_FragCoord.z / gl_FragCoord.w < playerClipPos.z / playerClipPos.w)
		//if (gl_FragCoord.z < playerClipPos.z)
		//if (gl_FragCoord.w < playerClipPos.w)
		
		if (posv.z > playerViewPos.z + 1.)
		{
			fragColor.w = .5;
			//discard;
		}
	}
}
]],
		uniforms = {
			tex = 0,
			drawCenter = {.5, 1},
			viewport = {0,0,1,1},
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
	
	self.map = Map{
		game = self,
		size = vec3i(96, 64, 32),
	}

	self.objs = table()
	app.players[1].obj = self:newObj{
		class = Obj.classes.Player,
		pos = vec3f(
			self.map.size.x*.5,
			self.map.size.y*.5,
			self.map.size.z-.5),
		player = assert(app.players[1]),
	}
					
	local ItemSeeds = require 'zelda.obj.item.seeds'
	app.players[1].obj:addItem(ItemSeeds:makeSubclass'test')

	local game = self
	self:newObj{
		class = Obj.classes.NPC,
		pos = vec3f(
			self.map.size.x*.95,
			self.map.size.y*.5,
			self.map.size.z-.5),
		interactInWorld = function(interactObj, playerObj)
			local player = playerObj.player
			playerObj.gamePrompt = function()
				local function buy(opt, amount)
					assert(amount > 0)
					local cost = opt.cost * amount
					if cost <= player.money then
						player.money = player.money - cost
						playerObj:addItem(ItemSeeds:makeSubclass(opt.name), amount)
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
			
				ig.igText"want to buy something?"
			
				local options = table{
					{name='blackberry seeds', cost=10},
					{name='acacia sapling', cost=10},
					{name='almond seeds', cost=10},
					{name='anise seeds', cost=10},
					{name='dill seeds', cost=10},
					{name='apple seeds', cost=10},
					{name='citrus seeds', cost=10},
					{name='barley seeds', cost=10},
					{name='bay seeds', cost=10},
					{name='greenbeans seeds', cost=10},
					{name='cinnamon seeds', cost=10},
					{name='corriander seeds', cost=10},
					{name='cotton seeds', cost=10},
					{name='cucumber seeds', cost=10},
					{name='cumin seeds', cost=10},
					{name='black cumin seeds', cost=10},
					{name='date seeds', cost=10},
					{name='fig sapling', cost=10},
					{name='flax seeds', cost=10},
					{name='garlic seeds', cost=10},
					{name='grape seeds', cost=10},
					{name='hemlock seeds', cost=10},
					{name='jujube seeds', cost=10},
					{name='leek seeds', cost=10},
					{name='lentil seeds', cost=10},
					{name='lily-of-the-valley seeds', cost=10},
					{name='linen seeds', cost=10},
					{name='mint seeds', cost=10},
					{name='mustard seeds', cost=10},
					{name='nettle seeds', cost=10},
					{name='pistachio seeds', cost=10},
					{name='oak sapling', cost=10},
					{name='olive sapling', cost=10},
					{name='onion seeds', cost=10},
					{name='pomegranate sapling', cost=10},
					{name='saffron seeds', cost=10},
					{name='walnut sapling', cost=10},
					{name='watermelon seeds', cost=10},
					{name='wheat seeds', cost=10},
					{name='wormwood seeds', cost=10},
				}
				for i,opt in ipairs(options) do
					for _,x in ipairs{1, 10, 100} do
						if ig.igButton('x'..x..'###'..i..'x'..x) then buy(opt, x) end
						ig.igSameLine()
					end
					ig.igText(opt.name)
				end

				if ig.igButton'Ok' then
					playerObj.gamePrompt = nil
				end
				ig.igEnd()		
			end
		end,
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
	
	self:newObj{
		class = require 'zelda.obj.item.bed',
		pos = houseCenter + vec3f(houseSize.x-1, -(houseSize.y-1), -(houseSize.z-1)) + .5,
	}

	-- plants
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
					local spriteInfo = pickWeighted{
						{sprite='tree1', weight=1, numLogs=10},
						{sprite='tree2', weight=1, numLogs=10},
						{sprite='bush1', weight=4, numLogs=2},
						{sprite='bush2', weight=4, numLogs=2},
						{sprite='bush3', weight=4, numLogs=2},
						{sprite='plant1', weight=8},
						{sprite='plant2', weight=8},
						{sprite='plant3', weight=8},
					}
					local tex = anim[spriteInfo.sprite].stand[1].tex
					self:newObj{
						class = require 'zelda.obj.plant',
						sprite = spriteInfo.sprite,
						numLogs = spriteInfo.numLogs,
						drawSize = vec2f(tex.width, tex.height) / 16,
						pos = vec3f(i + .5, j + .5, k + 1),
					}
				end
			end
		end
	end

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

function Game:newObj(args)
print('new', args.class.name, 'at', args.pos)
	local cl = assert(args.class)
	args.game = self
	local obj = cl(args)
	self.objs:insert(obj)
	return obj
end

function Game:draw()
	local app = self.app
	local view = app.view

	local viewFollow = app.players[1].obj
	--local viewFollow = self.goomba

	-- before calling super.update and redoing the gl matrices, update view...
	--self.view.angle:fromAngleAxis(1,0,0,20)
	view.pos:set((viewFollow.pos + view.angle:zAxis() * app.viewDist):unpack())

	view:setup(app.width / app.height)
	--app.orbit.pos:set((app.view.angle:zAxis() * app.viewDist):unpack())

-- [[ sky
	do
		GLTex2D:unbind()
		gl.glDisable(gl.GL_DEPTH_TEST)


		view.mvProjMat:setOrtho(0,1,0,1,-1,1)

		self.skySceneObj.uniforms.mvProjMat = view.mvProjMat.ptr
		self.skySceneObj:draw()

		gl.glEnable(gl.GL_DEPTH_TEST)

		view.mvProjMat:mul4x4(view.projMat, view.mvMat)
	end
--]]


	do
		-- [[ clip by fragcoord
		-- clip pos
		local x,y,z,w = view.mvMat:mul4x4v4(
			viewFollow.pos.x,
			viewFollow.pos.y,
			viewFollow.pos.z + .1)
		self.playerViewPos = vec4f(x,y,z,w)
		local x,y,z,w = view.mvProjMat:mul4x4v4(
			viewFollow.pos.x,
			viewFollow.pos.y,
			viewFollow.pos.z + .1)
		local normalizedDeviceCoordDepth = z / w
		local dnear = 0
		local dfar = 1
		local windowZ = normalizedDeviceCoordDepth * (dfar - dnear)*.5 + (dfar + dnear)*.5
		-- clip by depth ...
		self.playerClipPos = vec4f(x,y,z,w)
		--]]
		-- [[
		-- and clip by world z ...
		self.playerPos = vec3f(viewFollow.pos:unpack()) + .1
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

-- TODO only call this from a
function Game:sleep(seconds)
	assert(coroutine.isyieldable(coroutine.running()))
	local endTime = self.time + seconds
	while self.time < endTime do
		coroutine.yield()
	end
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
end

function Game:event(event, ...)
	local app = self.app
	local playerObj = app.players[1].obj
	if not playerObj then return end
	if event.type == sdl.SDL_KEYDOWN
	or event.type == sdl.SDL_KEYUP
	then
		local down = event.type == sdl.SDL_KEYDOWN
		
		-- reset
		if event.key.keysym.sym == ('r'):byte() then
			self.app.game = Game{app=self.app}
		end

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
