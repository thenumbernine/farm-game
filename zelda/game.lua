local ffi = require 'ffi'
local sdl = require 'ffi.req' 'sdl'
local class = require 'ext.class'
local table = require 'ext.table'
local math = require 'ext.math'
local path = require 'ext.path'
local vec2f = require 'vec-ffi.vec2f'
local vec3i = require 'vec-ffi.vec3i'
local vec3f = require 'vec-ffi.vec3f'
local vec4f = require 'vec-ffi.vec4f'
local gl = require 'gl'
local GLTex2D = require 'gl.tex2d'
local GLProgram = require 'gl.program'
local glreport = require 'gl.report'
local ThreadManager = require 'threadmanager'
local noise2d = require 'simplexnoise.2d'
local noise3d = require 'simplexnoise.3d'
local Map = require 'zelda.map'
local Tile = require 'zelda.tile'
local NPC = require 'zelda.obj.npc'

local function hexcolor(i)
	return
		bit.band(0xff, bit.rshift(i,16))/255,
		bit.band(0xff, bit.rshift(i,8))/255,
		bit.band(0xff, i)/255,
		1
end

--[[
occludes = table of {pos=vec3f, radius=number}
--]]
local function addPlants(map, occludes)
	local game = map.game
	-- [[ plants
	local plantTypes = require 'zelda.plants'
	local ij = vec2f()
	for j=0,map.size.y-1 do
		ij.y = j
		for i=0,map.size.x-1 do
			ij.x = i
			local k = map.size.z-1
			local voxel
			while k >= 0 do
				voxel = map:getTile(i,j,k)
				if voxel.type ~= Tile.typeValues.Empty then
					break
				end
				k = k - 1
			end
			if k >= 0
			and voxel
			and voxel.type == Tile.typeValues.Grass
			then
				-- found a grass tile
				local r = math.random()
				for _,occlude in ipairs(occludes) do
					if (ij - vec2f(occlude.pos.x, occlude.pos.y)):lenSq() < occlude.radius * occlude.radius then
						r = 1
						break
					end
				end
				if r < .7 then
					-- TODO pick plants based on biome
					-- and move the rest of these stats into the plantType
					local plantType = plantTypes:pickRandom()
					map:newObj{
						class = plantType.objClass,
						pos = vec3f(i + .5, j + .5, k + 1 - voxel.half * .5),
						-- TODO scale by plant life
						createTime = game.time - math.random() * plantType.growDuration * 2,
					}
				end
			end
		end
	end
	--]]
end

local function makeFarmMap(game)
--[[
TODO how to handle multiple maps with objects-in-map ...
- should I create all objs in mem, store them per-map, and update all objects?
- should I create all objs, and only update the ones in used maps?
- should I store objs on disk in unused maps?
--]]
	local map = Map{
		game = game,
		sizeInChunks = vec3i(3, 2, 1),
	}

	local houseSize = vec3f(3, 3, 2)
	local houseCenter = vec3f(
		math.floor(map.size.x/2),
		math.floor(map.size.y*3/4),
		math.floor(map.size.z/2) + houseSize.z)

	local lakeCenter = vec3f(
		math.floor(map.size.x*.1),
		math.floor(map.size.y*.1),
		math.floor(map.size.z/2))

	-- TODO this should be the pathway to the town 
	local toTownPos = vec3f(
		map.size.x*.95,
		map.size.y*.5,
		map.size.z-.5)

	do
	--print'generating map'
		local maptexs = {
			grass = 0,
			stone = 1,
			wood = 2,
		}

		-- simplex noise resolution
		local blockBits = 3
		local blockSize = bit.lshift(1, blockBits)
		local half = bit.rshift(map.size.z, 1)
		--local step = vec3i(1, map.size.x, map.size.x * map.size.y)
		--local ijk = vec3i()
		local xyz = vec3f()
		for k=0,map.size.z-1 do
			--ijk.z = k
			xyz.z = (k - bit.rshift(map.size.z,1)) / blockSize	-- z=0 <=> midpoint
			for j=0,map.size.y-1 do
				--ijk.y = j
				xyz.y = (j - bit.rshift(map.size.y,1))  / blockSize
				for i=0,map.size.x-1 do
					--ijk.x = i
					xyz.x = (i - bit.rshift(map.size.x,1)) / blockSize
					-- noise range should be between [-1,1] (with gradients bound to [-1,1] as well)
					local c = noise2d(xyz.x, xyz.y)
					-- map to [0,1]
					c = c * .25


					-- [[ make it flat around the house and NPC
					if (
						(vec2f(i,j) - vec2f(houseCenter.x, houseCenter.y)):length() < 15
						or (vec2f(i,j) - vec2f(toTownPos.x, toTownPos.y)):length() < 5
					) then
						-- make it flat ground
						-- TODO falloff around borders
						c = 0
					end
					--]]

					-- put zero halfway up the map
					c = xyz.z + c

					-- lower the lake
					local inLake = (vec2f(i,j) - vec2f(lakeCenter.x, lakeCenter.y)):length() < 15
					if inLake then
						c = c + .7
					end

					local voxelType
					if c < 0 then
						voxelType = Tile.typeForName.Stone
					elseif c < .1 then
						voxelType = Tile.typeForName.Grass
					else
						voxelType = Tile.typeForName.Empty
					end

					-- [[ make it a hole where the lake will be
					-- TODO again, use a gaussian surface
					if inLake then
						if k <= map.size.z*.5 - 2
						and voxelType == Tile.typeForName.Empty
						then
							voxelType = Tile.typeForName.Water
						end
					end
					--]]

					--local index = ijk:dot(step)
					local voxel = assert(map:getTile(i,j,k))
					voxel.type = voxelType.index
					voxel.tex = math.random(#voxelType.texrects)-1
				end
			end
		end

		-- make some grass tiles half-high
		-- TODO this but in the lop above
		for k=0,map.size.z-2 do
			for j=0,map.size.y-1 do
				for i=0,map.size.x-1 do
					local voxel = map:getTile(i,j,k)
					local nextVoxel = map:getTile(i,j,k+1)
					if nextVoxel.type == Tile.typeValues.Empty
					and voxel.type == Tile.typeValues.Grass
					then
						-- but not around the house or npc
						if k >= half
						and (
							(vec2f(i,j) - vec2f(houseCenter.x, houseCenter.y)):length() < 15
							or (vec2f(i,j) - vec2f(toTownPos.x, toTownPos.y)):length() < 5
						) then
						else
							voxel.half = math.random() < .5 and 1 or 0
						end
					end
				end
			end
		end

		do
			local WoodTile = Tile.typeForName.Wood
			for x=houseCenter.x-houseSize.x,houseCenter.x+houseSize.x do
				for y=houseCenter.y-houseSize.y, houseCenter.y+houseSize.y do
					for z=houseCenter.z-houseSize.z, houseCenter.z+houseSize.z do
						local adx = math.abs(x - houseCenter.x)
						local ady = math.abs(y - houseCenter.y)
						local adz = math.abs(z - houseCenter.z)
						local linf = math.max(adx/houseSize.x, ady/houseSize.y, adz/houseSize.z)
						if linf == 1 then
							local voxel = assert(map:getTile(x,y,z))
							voxel.type = WoodTile.index
							voxel.tex = math.random(#WoodTile.texrects)-1
							voxel.half = 0
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
		map:buildAlts()
		map:initLight()
		map:buildDrawArrays(
			0,0,0,
			map.size.x-1, map.size.y-1, map.size.z-1)
	--print'init done'
	end

	-- hmm I should redo my maps as 2d noise ...
	-- TODO around here, make a river or something.

	--[[ hack for flat ground for testing
	for k=0,map.size.z-1 do
		for j=0,map.size.y-1 do
			for i=0,map.size.x-1 do
				local voxel = assert(map:getTile(i,j,k))
				voxel.type = k <= 1
					and Tile.typeValues.Stone
					or Tile.typeValues.Empty
			end
		end
	end
	--]]

	-- [[
	map:newObj{
		class = require 'zelda.obj.bed',
		pos = houseCenter + vec3f(houseSize.x-1, -(houseSize.y-1), -(houseSize.z-1)) + .5,
	}
	map:newObj{
		class = require 'zelda.obj.chest',
		pos = houseCenter + vec3f(houseSize.x-1, houseSize.y-1, -(houseSize.z-1)) + .5,
	}
	--]]

	addPlants(map, {
		{pos = houseCenter, radius = 7.5},
		{pos = toTownPos, radius = 5},
	})

	-- [[
	local Goomba = require 'zelda.obj.goomba'
	for k=1,5 do
		local i = math.random(tonumber(map.size.x))-1
		local j = math.random(tonumber(map.size.y))-1
		for _,dir in ipairs{{1,0},{0,1},{-1,0},{0,-1}} do
			local ux, uy = table.unpack(dir)
			local g = map:newObj{
				class = Goomba,
				pos = vec3f(ux + i, uy + j, map.size.z-1),
			}
		end
	end
	--]]

	return map
end

function makeTownMap(game)
	local map = Map{
		game = game,
		sizeInChunks = vec3i(3, 2, 1),
	}

	local buildingSizes = table{
		vec3f(3, 3, 2),
		vec3f(3, 3, 2),
	}
	local buildingPoss = table{
		vec3f(
			math.floor(map.size.x/2),
			math.floor(map.size.y*3/4),
			math.floor(map.size.z/2) + buildingSizes[1].z),
		vec3f(
			math.floor(map.size.x*3/4),
			math.floor(map.size.y*3/4),
			math.floor(map.size.z/2) + buildingSizes[2].z),
	}

	-- simplex noise resolution
	local blockBits = 3
	local blockSize = bit.lshift(1, blockBits)
	local half = bit.rshift(map.size.z, 1)
	local xyz = vec3f()
	local ij = vec2f()
	for k=0,map.size.z-1 do
		xyz.z = (k - bit.rshift(map.size.z,1)) / blockSize	-- z=0 <=> midpoint
		for j=0,map.size.y-1 do
			xyz.y = (j - bit.rshift(map.size.y,1))  / blockSize
			ij.y = j
			for i=0,map.size.x-1 do
				xyz.x = (i - bit.rshift(map.size.x,1)) / blockSize
				ij.x = i
				-- noise range should be between [-1,1] (with gradients bound to [-1,1] as well)
				local c = noise2d(xyz.x, xyz.y)
				-- map to [0,1]
				c = c * .25

				-- [[ make it flat around the house and NPC
				for _,buildingPos in ipairs(buildingPoss) do
					if (
						(ij - vec2f(buildingPos.x, buildingPos.y)):length() < 15
					) then
						-- make it flat ground
						-- TODO falloff around borders
						c = 0
					end
				end
				--]]

				-- put zero halfway up the map
				c = xyz.z + c

				local voxelType
				if c < 0 then
					voxelType = Tile.typeForName.Stone
				elseif c < .1 then
					voxelType = Tile.typeForName.Grass
				else
					voxelType = Tile.typeForName.Empty
				end

				local voxel = assert(map:getTile(i,j,k))
				voxel.type = voxelType.index
				voxel.tex = math.random(#voxelType.texrects)-1
			end
		end
	end

	local WoodTile = Tile.typeForName.Wood
	for i,buildingPos in ipairs(buildingPoss) do
		local buildingSize = buildingSizes[i]
		for x=buildingPos.x-buildingSize.x,buildingPos.x+buildingSize.x do
			for y=buildingPos.y-buildingSize.y, buildingPos.y+buildingSize.y do
				for z=buildingPos.z-buildingSize.z, buildingPos.z+buildingSize.z do
					local adx = math.abs(x - buildingPos.x)
					local ady = math.abs(y - buildingPos.y)
					local adz = math.abs(z - buildingPos.z)
					local linf = math.max(adx/buildingSize.x, ady/buildingSize.y, adz/buildingSize.z)
					if linf == 1 then
						local voxel = assert(map:getTile(x,y,z))
						voxel.type = WoodTile.index
						voxel.tex = math.random(#WoodTile.texrects)-1
						voxel.half = 0
					end
				end
			end
			local t = assert(map:getTile(buildingPos.x, buildingPos.y - buildingSize.y, buildingPos.z - buildingSize.z + 1))
			t.type = 0
			t.tex = 0
			local t = assert(map:getTile(buildingPos.x, buildingPos.y - buildingSize.y, buildingPos.z - buildingSize.z + 2))
			t.type = 0
			t.tex = 0
		end
	end

	-- don't require until app.game is created
	local plantTypes = require 'zelda.plants'
	map:newObj{
		class = NPC,
		pos = buildingPoss[1],
		interactInWorld = function(interact, player)
			local appPlayer = player.appPlayer
			appPlayer:storePrompt(
				table()
					:append(plantTypes)
			)
		end,
	}

	local animalTypes = require 'zelda.animals'
	map:newObj{
		class = NPC,
		pos = buildingPoss[2],
		interactInWorld = function(interact, player)
			local appPlayer = player.appPlayer
			appPlayer:storePrompt(
				table()
					:append(animalTypes)
			)
		end,
	}

	addPlants(map, buildingPoss:mapi(function(pos)
		return {pos=pos, radius=7.5}
	end))

	map:buildAlts()
	map:initLight()
	map:buildDrawArrays(
		0,0,0,
		map.size.x-1, map.size.y-1, map.size.z-1)

	return map
end


local Game = class()

Game.secondsPerMinute = 1

Game.minutesPerHour = 60
Game.secondsPerHour = Game.secondsPerMinute * Game.minutesPerHour

Game.hoursPerDay = 24
Game.secondsPerDay = Game.secondsPerHour * Game.hoursPerDay

Game.daysPerWeek = 7
Game.secondsPerWeek = Game.secondsPerDay * Game.daysPerWeek

Game.weeksPerMonth = 4
Game.secondsPerMonth = Game.secondsPerWeek * Game.weeksPerMonth

Game.monthsPerYear = 4
Game.secondsPerYear = Game.secondsPerMonth * Game.monthsPerYear

-- when to start / wake up
Game.wakeHour = 6

--[[
args:
	app = app
	srcdir = (optional) save game folder
--]]
function Game:init(args)
	self.app = assert(args.app)
	local app = self.app

	-- start at 6am on the first day
	self.time = self.wakeHour * self.secondsPerHour

	self.threads = ThreadManager()

	self.maps = table()

	-- NOTICE here's the load-game functionality
	-- the save-game functionality is in Map
	-- maybe move this to Map too?
	if args.srcdir then
		local fromlua = require 'ext.fromlua'
		local env = {
			math = {huge = math.huge},
			app = app,
		}
		for i=0,math.huge do
			local mapfile = args.srcdir/(i..'.map')
			if not mapfile:exists() then break end
			local mapdata = fromlua(assert(mapfile:read()), nil, 't', env)
			local map = Map{
				game = self,
				sizeInChunks = vec3i(mapdata.sizeInChunks),
				chunkData = mapdata.chunkData,
			}
			self.maps:insert(map)
			for _,objsrcinfo in ipairs(mapdata.objs) do
				local newobj = map:newObj(table(objsrcinfo, {
					game = game,
					map = map,
					class = require(objsrcinfo.classname),
				}))
				-- TODO what if it's a dif player?
				if objsrcinfo.appPlayer == app.players[1] then
					app.players[1].obj = newobj
				end
			end
		end
	else
		-- start off the map
		local farmMap = makeFarmMap(self)
		self.maps:insert(farmMap)

		local townMap = makeTownMap(self)
		self.maps:insert(townMap)

		-- [[ doors
		farmMap:newObj{
			class = require 'zelda.obj.door',
			pos = vec3f(
				farmMap.size.x-1,
				farmMap.size.y/2,
				farmMap.size.z/2+1),
			destMap = townMap,
			destMapPos = vec3f(
				1,
				townMap.size.y/2,
				townMap.size.z/2+1),
		}

		townMap:newObj{
			class = require 'zelda.obj.door',
			pos = vec3f(
				0,
				townMap.size.y/2,
				townMap.size.z/2+1),
			destMap = farmMap,
			destMapPos = vec3f(
				farmMap.size.x-2,
				farmMap.size.y/2,
				farmMap.size.z/2+1),
		}
		--]]

		do
			local PlayerObj = require 'zelda.obj.player'
			local vec2i = require 'vec-ffi.vec2i'
			local map = farmMap
			local playerPos2D = vec2i(
				bit.rshift(map.size.x, 1),
				bit.rshift(map.size.y, 1))
			local surf = map:getSurface(playerPos2D:unpack())
			app.players[1].obj = map:newObj{
				class = PlayerObj,
				pos = vec3f(
					playerPos2D.x+.5,
					playerPos2D.y+.5,
					surf.solidAlt+1),
				appPlayer = assert(app.players[1]),
			}
			print(app.players[1].obj.pos)
		end
	end

	self.viewFollow = app.players[1].obj
	--self.viewFollow = self.goomba
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

Game.numSpritesDrawn = 0
function Game:draw()
	local app = self.app
	local view = app.view

	-- before calling super.update and redoing the gl matrices, update view...
	--self.view.angle:fromAngleAxis(1,0,0,20)
	view.pos:set((self.viewFollow.pos + view.angle:zAxis() * app.viewDist):unpack())

	view:setup(app.width / app.height)
	--app.orbit.pos:set((app.view.angle:zAxis() * app.viewDist):unpack())

-- [==[

-- [[ sky
	do
		gl.glDisable(gl.GL_DEPTH_TEST)

		view.mvProjMat:setOrtho(0,1,0,1,-1,1)

		app.skySceneObj.uniforms.mvProjMat = view.mvProjMat.ptr
		app.skySceneObj.uniforms.timeOfDay = (self.time / self.secondsPerDay) % 1
		-- testing: 1 min = 1 day
		--app.skySceneObj.uniforms.timeOfDay = (self.time / 60) % 1
		

		local i = math.floor(self.viewFollow.pos.x)
		local j = math.floor(self.viewFollow.pos.y)
		local surface = self.viewFollow.map:getSurface(i,j)
	
	-- [=[
		app.skySceneObj.uniforms.inside = 
			surface
			and math.clamp(
				(tonumber(surface.lumAlt - 4) - self.viewFollow.pos.z) / 4,
				0,
				1
			)
			or 0
	--]=]
		app.skySceneObj:draw()

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

	-- prep draw lists
	-- with zero sprite rendering whatsoever i'm getting 30fps
	-- so sprite rendering might not be our bottleneck ...
	-- collect per-texture of sprites

	app.spritesBufCPU:resize(0)

--[[ draw all maps
	for _,map in ipairs(self.maps) do
		map:draw()
		map:drawObjs()
	end
--]]
-- [[ only draw the player's map
	self.viewFollow.map:draw()
	self.viewFollow.map:drawObjs()
--]]

	self.numSpritesDrawn = app.spritesBufCPU.size

	app.spritesBufGPU
		:bind()
		:updateData(0, app.spritesBufCPU.size * ffi.sizeof'sprite_t')
		:unbind()

	local shader = app.spriteShader
	shader:use()
	app.spriteSceneObj:enableAndSetAttrs()	-- enable vao
	gl.glUniformMatrix4fv(shader.uniforms.viewMat.loc, 1, gl.GL_FALSE, view.mvMat.ptr)
	gl.glUniformMatrix4fv(shader.uniforms.projMat.loc, 1, gl.GL_FALSE, view.projMat.ptr)
	gl.glUniform3fv(shader.uniforms.playerViewPos.loc, 1, self.playerViewPos.s)

	app.spriteAtlasTex:bind(0)

	--app.spriteSceneObj.geometry.count = 6 * app.spritesBufCPU.size
	--app.spriteSceneObj.geometry:draw()
	gl.glDrawArraysInstanced(gl.GL_TRIANGLE_STRIP, 0, 4, app.spritesBufCPU.size)

	app.spriteSceneObj:disableAttrs()
	shader:useNone()

	GLTex2D:unbind()
	GLProgram:useNone()
--]=]

--]==]

--[[ debug
	do
		local map = self.viewFollow.map
		local gl = require 'gl'
		gl.glColor3f(1,1,1)
		gl.glPointSize(10)
		gl.glDisable(gl.GL_TEXTURE_2D)
		gl.glUseProgram(0)
		gl.glDisable(gl.GL_CULL_FACE)
		gl.glDisable(gl.GL_DEPTH_TEST)

		--[=[ why doesn't glLoadMatrix work?
		gl.glMatrixMode(gl.GL_PROJECTION)
		gl.glLoadMatrixf(view.projMat.v)
		gl.glMatrixMode(gl.GL_MODELVIEW)
		gl.glLoadMatrixf(view.mvMat.v)
		--]=]
		-- [=[
		view.useBuiltinMatrixMath = false
		view:setup(app.width / app.height)
		view.useBuiltinMatrixMath = true
		--]=]

		--gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
		gl.glBegin(gl.GL_QUADS)
		--gl.glBegin(gl.GL_TRIANGLES)
		--gl.glBegin(gl.GL_POINTS)

		for _,obj in ipairs(map.objs) do
			--[=[
			gl.glVertex3f(obj.pos.x, obj.pos.y, obj.pos.z)
			--]=]
			-- [=[
			for faceIndex,faces in ipairs(Tile.cubeFaces) do
				-- [=[
				for _,vtxCoordFlags in ipairs(faces) do
					local v = Tile.cubeVtxs[vtxCoordFlags+1]
					gl.glVertex3f(
						obj.pos.x + (1 - v[1]) * obj.bbox.min.x + v[1] * obj.bbox.max.x,
						obj.pos.y + (1 - v[2]) * obj.bbox.min.y + v[2] * obj.bbox.max.y,
						obj.pos.z + (1 - v[3]) * obj.bbox.min.z + v[3] * obj.bbox.max.z)
				end
				--]=]
				--[=[
				for ti=1,6 do
					local vi = Tile.unitQuadTriIndexes[ti]
					local vtxindex = faces[vi]
					local v = Tile.cubeVtxs[vtxindex+1]
					gl.glVertex3f(
						obj.pos.x + (1 - v[1]) * obj.bbox.min.x + v[1] * obj.bbox.max.x,
						obj.pos.y + (1 - v[2]) * obj.bbox.min.y + v[2] * obj.bbox.max.y,
						obj.pos.z + (1 - v[3]) * obj.bbox.min.z + v[3] * obj.bbox.max.z)
				end
				--]=]
			end
			--]=]
			--[=[
			gl.glBegin(gl.GL_LINES)
			gl.glEnd()
			--]=]
		end

		gl.glEnd()
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
		gl.glEnable(gl.GL_CULL_FACE)
		gl.glEnable(gl.GL_DEPTH_TEST)
		gl.glPointSize(1)
	end
--]]
	glreport'here'
end

function Game:update(dt)
	--[[ update all maps?
	for _,map in ipairs(self.maps) do
		map:update(dt)
	end
	--]]
	-- [[ only update maps that the player is in?
	self.viewFollow.map:update(dt)
	-- ... and maybe update all other maps on larger dt's?
	--]]

	-- now threads
	self.threads:update()

	-- only after update do the removals
	for _,map in ipairs(self.maps) do
		for i=#map.objs,1,-1 do
			local obj = map.objs[i]
			if obj.removeFlag then
				obj:unlink()	-- should be already unlinked
				--assert(next(obj.tiles) == nil)
				table.remove(map.objs, i)
			end
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

function Game:event(event, ...)
	local app = self.app
	local appPlayer = app.players[1]
	if not appPlayer then return end
	if app.playingMenu.consoleOpen then return end

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
				appPlayer.selectedItem = event.key.keysym.sym - ('1'):byte() + 1
			elseif event.key.keysym.sym == ('0'):byte() then
				appPlayer.selectedItem = 10
			elseif event.key.keysym.sym == ('-'):byte() then
				appPlayer.selectedItem = 11
			elseif event.key.keysym.sym == ('='):byte() then
				appPlayer.selectedItem = 12
			end
		end
	end
end

return Game
