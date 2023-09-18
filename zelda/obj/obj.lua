local ffi = require 'ffi'
local table = require 'ext.table'
local math = require 'ext.math'
local class = require 'ext.class'
local vec2f = require 'vec-ffi.vec2f'
local vec3i = require 'vec-ffi.vec3i'
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local matrix_ffi = require 'matrix.ffi'
local gl = require 'gl'
local glreport = require 'gl.report'
local GLTex2D = require 'gl.tex2d'
local anim = require 'zelda.anim'
local Voxel = require 'zelda.voxel'
local sides = require 'zelda.sides'

local function smoothstep(edge0,edge1,x)
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local Obj = class()
Obj.classname = 'zelda.obj.obj'

-- default
Obj.seq = 'stand'
Obj.frame = 1

Obj.bbox = box3f{
	min = {-.49, -.49, 0},
	max = {.49, .49, .98},
}

-- model rotation, or used for picking sprite billboard direction index
Obj.angle = 0

-- d/dt of angle
Obj.rotation = 0

-- rotation of the sprite in billboard space.  not the model rotation, which is "angle".
Obj.drawAngle = 0

-- sprite 2D tex anchor point
Obj.drawCenter = vec3f(.5, 1, 0)

-- TODO spriteScale?
Obj.drawSize = vec2f(1,1)

-- added to obj.pos for determining sprite center
Obj.spritePosOffset = vec3f(0,0,0)

-- false = use map x y basis
-- true = use view x y basis
Obj.disableBillboard = false

-- whether we use see-thru
-- default to no
-- yes for not-so-interactable sprites like plants
Obj.useSeeThru = false

Obj.colorMatrix = matrix_ffi({4,4}, 'float'):lambda(function(i,j)
	return i==j and 1 or 0
end)

-- once we set a light, set this field, and use it to determine where to recalculate light
Obj.lastlightpos = nil

function Obj:init(args)
	assert(args)
	self.game = assert(args.game)
	self.map = assert(args.map)
	self.uid = assert(args.uid)

	-- what was the game clock when the object was created?
	-- this will need to be explicitly set for objects being loaded from save games etc
	self.createTime = args.createTime or self.game.time

	self.rotation = args.rotation

	self.drawSize = vec2f(self.class.drawSize)
	if args.drawSize then self.drawSize = vec2f(args.drawSize) end

	self.drawCenter = vec3f(self.class.drawCenter)
	if args.drawCenter then self.drawCenter = vec3f(args.drawCenter) end

	self.spritePosOffset = vec3f(self.class.spritePosOffset)
	if args.spritePosOffset then self.spritePosOffset = vec3f(args.spritePosOffset) end

	self.pos = vec3f(0,0,0)
	if args.pos then self.pos:set(args.pos:unpack()) end
	self.oldpos = vec3f(self.pos:unpack())

	self.vel = vec3f(0,0,0)
	if args.vel then self.vel:set(args.vel:unpack()) end
	self.oldvel = vec3f(self.vel:unpack())

	self.bbox = box3f(self.class.bbox)
	if args.bbox then self.bbox = box3f(args.bbox) end

	self.colorMatrix = matrix_ffi(assert(args.colorMatrix or self.class.colorMatrix), 'float')

	self.sprite = args.sprite
	self.seq = args.seq

	self.interactInWorld = args.interactInWorld

	-- what tile indexes -> obj lists this object is a part of
	self.tiles = {}

	-- NOTICE this calls :link
	-- that means Obj ctor sets args before link
	-- but all Obj subclass args set after link
	self:setPos(self.pos:unpack())

	-- TODO not until after subclass ctor is done
	--self:move(vec3f(), 1)
end

Obj.light = 0

-- have both this - and all the voxel-and-light-modification routines - call another function "updateLight" which stretches by MAX_LUM and then does the light calcs
-- call this upon unlink+link (i.e. relink?)
-- or call this upon unlink() if it's not getting relinked ...
function Obj:updateLightOnMove()
	local map = self.map
	local lightposx = math.floor(self.pos.x)
	local lightposy = math.floor(self.pos.y)
	local lightposz = math.floor(self.pos.z)
-- [[
-- or should each light contain their own overlay, and then just max() them on one another?
-- that'd mean the (2*light size) ^3 mem requ
-- so if light values are 4 bits, then falloff is 15, each direction makes 31, and that's the entire chunk size ...
-- but how about if I do 3 bits <-> 8 values <-> 16^3 each ... only half a chunk
-- I'm thinking maybe I should use a dif light model than minecraft uses ...

	if not self.lastlightpos then
		map:updateLightAtPos(lightposx, lightposy, lightposz)
		self.lastlightpos = vec3i(lightposx, lightposy, lightposz)
	else
		if lightposx ~= self.lastlightpos.x
		or lightposy ~= self.lastlightpos.y
		or lightposz ~= self.lastlightpos.z
		then
			local unlum = next(self.tiles) == nil
print('relighting at', self.pos)
			-- TODO only if |pos-lastlightpos| is < 1 or < the size of a lightbox or < some epsilon ...
			-- otherwise update each region separately
			local lastlightposx = tonumber(self.lastlightpos.x)
			local lastlightposy = tonumber(self.lastlightpos.y)
			local lastlightposz = tonumber(self.lastlightpos.z)
			-- TODO calculate this and find where the tradeoff is best
			if math.max(
				math.abs(lightposx - lastlightposx),
				math.abs(lightposy - lastlightposy),
				math.abs(lightposz - lastlightposz)) < .5 * ffi.C.MAX_LUM
			then
				map:updateLight(
					math.floor(math.min(lastlightposx, lightposx) - ffi.C.MAX_LUM),
					math.floor(math.min(lastlightposy, lightposy) - ffi.C.MAX_LUM),
					math.floor(math.min(lastlightposz, lightposz) - ffi.C.MAX_LUM),
					math.floor(math.max(lastlightposx, lightposx) + ffi.C.MAX_LUM),
					math.floor(math.max(lastlightposy, lightposy) + ffi.C.MAX_LUM),
					math.floor(math.max(lastlightposz, lightposz) + ffi.C.MAX_LUM))
			else
print("relighting pos and oldpos: ", self.pos, self.lastlightpos)
				map:updateLightAtPos(lastlightposx, lastlightposy, lastlightposz)
				map:updateLightAtPos(lightposx, lightposy, lightposz)
			end
		end
		
		-- TODO i could be using this for fast relinking
		-- but right now it's just used for lighting
		self.lastlightpos:set(lightposx, lightposy, lightposz)
	end
--]]
end

function Obj:link()
	local map = self.map

	-- always unlink before you link
	assert(next(self.tiles) == nil)

	for k =
		math.max(math.floor(self.pos.z + self.bbox.min.z), 0),
		math.min(math.floor(self.pos.z + self.bbox.max.z), map.size.z - 1)
	do
		for j =
			math.max(math.floor(self.pos.y + self.bbox.min.y), 0),
			math.min(math.floor(self.pos.y + self.bbox.max.y), map.size.y - 1)
		do
			for i =
				math.max(math.floor(self.pos.x + self.bbox.min.x), 0),
				math.min(math.floor(self.pos.x + self.bbox.max.x), map.size.x - 1)
			do
				local voxelIndex = i + map.size.x * (j + map.size.y * k)
				local tileObjs = map.objsPerTileIndex[voxelIndex]

				if not tileObjs then
					tileObjs = table()
					map.objsPerTileIndex[voxelIndex] = tileObjs
				end

				tileObjs:insertUnique(self)

				self.tiles[voxelIndex] = tileObjs
			end
		end
	end

	if self.light > 0 then
		self:updateLightOnMove()
	end
end

function Obj:setLight(newLight)
	-- prevent setLight(nil) from calling this a lot
	if newLight == nil then
		newLight = self.class.light
	end
	if newLight ~= self.light then
		self.light = newLight
		self.map:updateLightAtPos(
			math.floor(self.pos.x),
			math.floor(self.pos.y),
			math.floor(self.pos.z)
		)
	end
end

function Obj:unlink()
	local map = self.map
	-- self.tiles = list of tile-links that this obj is attached to ...
	if self.tiles then
		for voxelIndex,tileObjs in pairs(self.tiles) do
			tileObjs:removeObject(self)
			if #tileObjs == 0 then
				map.objsPerTileIndex[voxelIndex] = nil
			end
			self.tiles[voxelIndex] = nil
		end
	end

	assert(next(self.tiles) == nil)
end

function Obj:remove()
	if self.removeFlag then return end
	self.removeFlag = true
	self:unlink()
	local x = math.floor(self.pos.x)
	local y = math.floor(self.pos.y)
	local z = math.floor(self.pos.z)
	if self.light > 0 then
		self.map:updateLightAtPos(x,y,z)
	end
	return self
end

function Obj:setPos(x,y,z)
	self.pos:set(x,y,z)
	self:unlink()
	self:link()
	
	-- TODO here, lighting ...
	-- if the obj has a light level
	-- and its new pos is a dif tile (floor'd) from its old pos
	-- then relight the old & new pos's

	return self
end

-- how to handle collision?
-- go back to start of trace?
-- find intersection and then redo collision over remaining timestep?
-- or just push? how about just push.
-- Writes to vel
local epsilon = 1e-5
local function push(pos, min, max, bmin, bmax, vel, dontPush)
	-- TODO cache these as 'worldmin'/max?
	local amin = pos + min
	local amax = pos + max
	--[[
	how to detect convex simplex collison?
	check all sides, find closest vtx on obj A to side on B
	if it separates (plane dist > 0) then we have no collision
	if no planes separate (all dists are positive) then we have collision somewhere
	and in that case, use the *most shallow* (greatest negative #) penetration to push back ... not the deepest?  because deepest plane dist could be out the other side?  hmm ...
	but what about rects resting on one another? edge/edge collision?

	what's an aabb way to do collision?
	for each side, for each +-,
		find the subset rect of each side
		if it is non-null ...
		look at the side of obj A's pos along the axis, whether it is in bounds of obj B
		if so
			then we have a collision
	--]]
	-- do the boxes intersect on the plane of axis j & k ?
	if amin.x <= bmax.x
	and amax.x >= bmin.x
	and amin.y <= bmax.y
	and amax.y >= bmin.y
	and amin.z <= bmax.z
	and amax.z >= bmin.z
	then
		-- find the center of the intersecting region
		-- find the largest axis of the center
		-- use that as the collision axis
		local iminx = math.max(amin.x, bmin.x)
		local iminy = math.max(amin.y, bmin.y)
		local iminz = math.max(amin.z, bmin.z)

		local imaxx = math.min(amax.x, bmax.x)
		local imaxy = math.min(amax.y, bmax.y)
		local imaxz = math.min(amax.z, bmax.z)

		local midx = (iminx + imaxx) * .5
		local midy = (iminy + imaxy) * .5
		local midz = (iminz + imaxz) * .5

		local dx = imaxx - iminx
		local dy = imaxy - iminy
		local dz = imaxz - iminz

		local side, pm
		if dx < dy then
			if dx < dz then
				side, pm = 0, .5 * (amin.x + amax.x) < midx and 1 or -1
			else
				side, pm = 2, .5 * (amin.z + amax.z) < midz and 1 or -1
			end
		else
			if dy < dz then
				side, pm = 1, .5 * (amin.y + amax.y) < midy and 1 or -1
			else
				side, pm = 2, .5 * (amin.z + amax.z) < midz and 1 or -1
			end
		end

		if side == 0 then
			do -- if math.sign(vel.x) == pm then
				if not dontPush then
					vel.x = 0
				end
				if pm == 1 then
					if not dontPush then
						pos.x = bmin.x - max.x - epsilon
					end
					return sides.flags.xp
				else
					if not dontPush then
						pos.x = bmax.x - min.x + epsilon
					end
					return sides.flags.xm
				end
			end
		elseif side == 1 then
			do -- if math.sign(vel.y) == pm then
				if not dontPush then
					vel.y = 0
				end
				if pm == 1 then
					if not dontPush then
						pos.y = bmin.y - max.y - epsilon
					end
					return sides.flags.yp
				else
					if not dontPush then
						pos.y = bmax.y - min.y + epsilon
					end
					return sides.flags.ym
				end
			end
		elseif side == 2 then
			do -- if math.sign(vel.z) == pm then
				if not dontPush then
					vel.z = 0
				end
				if pm == 1 then
					if not dontPush then
						pos.z = bmin.z - max.z - epsilon
					end
					return sides.flags.zp
				else
					if not dontPush then
						pos.z = bmax.z - min.z + epsilon
					end
					return sides.flags.zm
				end
			end
		end
	end
	return 0
end

Obj.useGravity = true	-- or TODO just change the gravity value to zero?
Obj.gravity = -9.8

Obj.collidesWithTiles = true
Obj.collidesWithObjects = true
Obj.itemTouch = false	-- for items only, to add a touch test upon creation

Obj.collideFlags = 0

-- for walking=true:
Obj.stepHeight = .6

function Obj:update(dt)
--print('0', self.pos)
	local game = self.game

	if self.removeDuration
	and game.time >= self.createTime + self.removeDuration
	then
		if self.onremove then
			self:onremove()
		end
		self:remove()
		return
	end

	self.angle = self.angle + self.rotation * dt

	if self.vel.x ~= 0
	or self.vel.y ~= 0
	or self.vel.z ~= 0
	or self.itemTouch
	then
		-- TODO call this 'lastmovepos' instead
		-- since I'm only using it for the pos/lastpos bounds in :move()
		-- I might have another cached 'lastlinkpos' for determining when link() / lighting has changed
		self.oldpos:set(self.pos:unpack())
		self.oldvel:set(self.vel:unpack())
		self.collideFlags = 0
		self:move(self.vel, dt)

		-- HERE - if we got collideFlags for any sides
		-- and we're .walking
		-- then ... instead ... move up, move along vel, move back down
		-- and if that movement
		if self.walking
		-- ... and we're on ground
		and 0 ~= bit.band(self.collideFlags, sides.flags.zm)
		-- ... and touching a wall
		and 0 ~= bit.band(self.collideFlags, bit.bor(
			sides.flags.xm,
			sides.flags.ym,
			sides.flags.xp,
			sides.flags.yp
		))
		then
			self.oldvel.z = 0
			local oldold = self.oldpos:clone()
			self.pos:set(self.oldpos:unpack())
--print('bbox', box3f(self.bbox.min + self.pos, self.bbox.max + self.pos))
--print('1', self.pos)
			self:move(vec3f(0, 0, self.stepHeight), 1)
			
			-- for each :move() make sure pos==oldpos
--print('2', self.pos)			
			self.oldpos:set(self.pos:unpack())
			self.collideFlags = 0
			self.vel:set(self.oldvel:unpack())
--print('vel', self.vel)
			self:move(self.vel, dt)
			
			-- [[ when pushing down, it also pushes outward
			-- so disable push ...
			-- but this still makes the final position sunk tiny bit into the floor ...
			-- but disabling it and you hop when you hit walls
			local pushFlags = self.collideFlags
--print('3', self.pos)			
			self.oldpos:set(self.pos:unpack())
			self:move(vec3f(0, 0, -self.stepHeight), 1, true)
			self.collideFlags = pushFlags
--print('4', self.pos)
			--]]
		
			-- for the rest, use 'oldpos' as the start of this update
			self.oldpos:set(oldold:unpack())
--print('vel', self.vel)
		end

		self:unlink()
		self:link()

		if self.removeFlag then return end

		-- TODO always check?
		-- or if only upon move, also check upon init?
		self.inWater = false
		-- store pointer to voxel at obj origin ...
		self.voxel = self.map:getTile(
			math.floor(self.pos.x),
			math.floor(self.pos.y),
			math.floor(self.pos.z))
		if self.voxel then
			local voxelType = self.voxel:tileClass()
			if voxelType
			and voxelType.contents == 'water'
			then
				self.inWater = true
				local velVisc = .7
				self.vel.x = self.vel.x * velVisc
				self.vel.y = self.vel.y * velVisc
				self.vel.z = self.vel.z * velVisc
			end
		end
	end

	if self.useGravity
	and 0 == bit.band(self.collideFlags, sides.flags.zm)
	then
		local gravity = self.gravity
		if self.inWater then
			gravity = gravity * .3
		end
		self.vel.z = self.vel.z + self.gravity * dt
	end
--print('5', self.pos)
end

local omin = vec3f()
local omax = vec3f()
function Obj:move(vel, dt, dontPush)
	local map = self.map

	self.pos.x = self.pos.x + vel.x * dt
	self.pos.y = self.pos.y + vel.y * dt
	self.pos.z = self.pos.z + vel.z * dt
--print('a', self.pos)
	if not (
		self.collidesWithTiles
		or self.collidesWithObjects
		or self.itemTouch
	) then
		return
	end

	local objIterUID = map:getNextObjIterUID()
	for k =
		math.floor(math.min(self.pos.z, self.oldpos.z) + self.bbox.min.z - 1.5),
		math.floor(math.max(self.pos.z, self.oldpos.z) + self.bbox.max.z + .5)
	do
		for j =
			math.floor(math.min(self.pos.y, self.oldpos.y) + self.bbox.min.y - 1.5),
			math.floor(math.max(self.pos.y, self.oldpos.y) + self.bbox.max.y + .5)
		do
			for i =
				math.floor(math.min(self.pos.x, self.oldpos.x) + self.bbox.min.x - 1.5),
				math.floor(math.max(self.pos.x, self.oldpos.x) + self.bbox.max.x + .5)
			do
				if i >= 0 and i < map.size.x
				and j >= 0 and j < map.size.y
				and k >= 0 and k < map.size.z
				then
					local voxelIndex = i + map.size.x * (j + map.size.y * k)
					local voxel = map:getTile(i,j,k)
					if self.collidesWithTiles
					and voxel
					and voxel.type > 0
					then
						local voxelType = Voxel.types[voxel.type]
						if not voxelType then
							error("failed to find voxelType for type "..tostring(tiletype))
						end
						if voxelType.solid then
							omin:set(i,j,k)
							omax:set(i+1,j+1,k+.5*(2-voxel.shape))

							-- TODO trace gravity fall downward separately
							-- then move horizontall
							-- if push fails then raise up, move, and go back down, to try and do steps
--print('b', self.pos)
							local collided = push(self.pos, self.bbox.min, self.bbox.max, omin, omax, vel, dontPush)
--print('c', self.pos, collided)
							self.collideFlags = bit.bor(self.collideFlags, collided)
						end
					end
					local objs = map.objsPerTileIndex[voxelIndex]
					if objs then
						for _, obj in ipairs(objs) do
							if not obj.removeFlag
							and obj ~= self
							and obj.iterUID ~= objIterUID
							then
								obj.iterUID = objIterUID
								-- TODO if obj.solid
								if obj.collidesWithObjects
								or obj.itemTouch
								or self.itemTouch
								then
--print('d', self.pos)
									local collided = push(self.pos, self.bbox.min, self.bbox.max, obj.pos + obj.bbox.min, obj.pos + obj.bbox.max, vel, dontPush or self.itemTouch or obj.itemTouch)
--print('e', self.pos, collided)
									self.collideFlags = bit.bor(self.collideFlags, collided)
									if collided ~= 0 then
										-- TODO set obj.collideFlags also?
										if not self.removeFlag
										and not obj.removeFlag
										and self.touch
										then
											self:touch(obj)
											if self.removeFlag then return end
										end
										if not self.removeFlag
										and not obj.removeFlag
										and obj.touch
										then
											obj:touch(self)
											if self.removeFlag then return end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
--print('f', self.pos)
end

-- ccw start at 0' (with 45' spread)
-- TODO use 8 points as well?
local dirSeqSuffixes = {'_r', '_u', '_l', '_d'}

local matrix_ffi = require 'matrix.ffi'
local modelMat = matrix_ffi({4,4},'float'):zeros():setIdent()
local identMat4 = matrix_ffi({4,4},'float'):lambda(function(i,j) return i==j and 1 or 0 end)
Obj.identMat4 = identMat4

-- static method, no class, convenient to have in the namespace
function Obj.getFrame(spriteName, seqName, frameIndex, angle, app)
	if not spriteName then return end
	if not seqName then return end
	if not frameIndex then return end
	local sprite = anim[spriteName]
	if not sprite then return end
	if sprite.useDirs then	-- enable this for sequences that use _u _d _l _r etc (TODO search by default?)
		local relAngle = angle - app.viewYaw
		local angleIndex = math.floor(relAngle / (.5 * math.pi) + .5) % 4 + 1
		seqName = seqName .. dirSeqSuffixes[angleIndex]
--print('angle', self.angle, 'index', angleIndex, 'seqName', seqName)
	end
	local seq = sprite[seqName]
--print('seqName', seqName, 'seq', seq)
	if not seq then return end
	return seq[frameIndex]
end

function Obj:draw()
--print('drawing', self.sprite, self.seq, self.frame, self.angle)
	local frame = Obj.getFrame(
		self.sprite,
		self.seq,
		self.frame,
		self.angle,
		self.game.app)
	if not frame then return end

	if frame.atlasTcPos then
		self:drawSprite(frame)
	elseif frame.mesh then
		error'here'
		self:drawMesh()
		--self.game.meshDrawList:insert(self)
	else
		error("hmm error in frame table")
	end
end

function Obj:drawSprite(frame)
	local app = self.game.app

	-- write all props to an attribute buffer
	-- write as we go and just update the whole buffer
	-- TODO later map objs <-> loc in buffer and only update what we need
	local sprite = app.spritesBufCPU:emplace_back()
	sprite.atlasTcPos:set(frame.atlasTcPos:unpack())
	sprite.atlasTcSize:set(frame.atlasTcSize:unpack())
	sprite.hflip = frame.hflip and 1 or 0
	sprite.vflip = self.vflip and 1 or 0
	sprite.disableBillboard = self.disableBillboard and 1 or 0
	sprite.useSeeThru = self.useSeeThru and 1 or 0
	sprite.drawCenter:set(self.drawCenter:unpack())
	sprite.drawSize:set(self.drawSize:unpack())
	sprite.drawAngle = self.drawAngle
	sprite.angle = self.angle
	sprite.pos:set(self.pos:unpack())
	sprite.spritePosOffset:set(self.spritePosOffset:unpack())
	-- col or row major?
	ffi.copy(sprite.colorMatrix[0].s, self.colorMatrix.ptr, ffi.sizeof'float' * 16)
end

function Obj:drawMesh(frame)
	local map = self.map
	local game = self.game
	local app = game.app
	local view = app.view

	modelMat:setTranslate(self.pos:unpack())
		:applyScale(self.drawSize.x, self.drawSize.x, self.drawSize.y)
		:applyRotate(self.angle, 0, 0, 1)
	local shader = app.meshShader
	--[[
	shader
		:use()
		:setUniforms{
			modelMatrix = modelMat.ptr,
			viewMatrix = view.mvMat.ptr,
			projectionMatrix = view.projMat.ptr,
		}
		:useNone()
	--]]
	-- [[
	shader:use()
	gl.glUniformMatrix4fv(shader.uniforms.modelMatrix.loc, 1, gl.GL_FALSE, modelMat.ptr)
	gl.glUniformMatrix4fv(shader.uniforms.viewMatrix.loc, 1, gl.GL_FALSE, view.mvMat.ptr)
	gl.glUniformMatrix4fv(shader.uniforms.projectionMatrix.loc, 1, gl.GL_FALSE, view.projMat.ptr)
	--shader:useNone()	-- why does shader need to be :use()'d here?
	--]]
	frame.mesh:draw{
		shader = shader,
		beginGroup = function(g)
			if g.tex_Kd then g.tex_Kd:bind() end
			shader:setUniforms{
				useFlipTexture = 0,
				useLighting = 0,
				useTextures = g.tex_Kd and 1 or 0,
				Ka = {0,0,0,0},
				Kd = g.Kd and {g.Kd.x, g.Kd.y, g.Kd.z, 1} or {1,1,1,1},
				Ks = g.Ks and g.Ks.s or {1,1,1,1},
				Ns = g.Ns or 10,

				objCOM = vec3f().s,
				groupCOM = vec3f().s,
				groupExplodeDist = 0,
				triExplodeDist = 0,
			}
		end,
	}
end

-- TODO this matches Item.toItemObj
-- but since both Obj and Item can separately be items ... meh?
function Obj:toItem()
	self.map:newObj{
		class = require 'zelda.obj.item',
		itemClass = self.class,
		pos = self.pos,
	}
	self:remove()
end

return Obj
