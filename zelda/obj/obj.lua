local ffi = require 'ffi'
local table = require 'ext.table'
local class = require 'ext.class'
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local box3f = require 'vec-ffi.box3f'
local matrix_ffi = require 'matrix.ffi'
local gl = require 'gl'
local glreport = require 'gl.report'
local GLTex2D = require 'gl.tex2d'
local anim = require 'zelda.anim'
local Tile = require 'zelda.tile'
local sides = require 'zelda.sides'

local math = require 'ext.math'
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
Obj.drawCenter = vec2f(.5, 1)

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



function Obj:init(args)
	assert(args)
	self.game = assert(args.game)
	self.map = assert(args.map)

	-- what was the game clock when the object was created?
	-- this will need to be explicitly set for objects being loaded from save games etc 
	self.createTime = args.createTime or self.game.time

	self.rotation = args.rotation

	self.drawSize = vec2f(self.class.drawSize)
	if args.drawSize then self.drawSize = vec2f(args.drawSize) end
	
	self.drawCenter = vec2f(self.class.drawCenter)
	if args.drawCenter then self.drawCenter = vec2f(args.drawCenter) end
	
	self.spritePosOffset = vec3f(self.class.spritePosOffset)
	if args.spritePosOffset then self.spritePosOffset = vec3f(args.spritePosOffset) end

	self.pos = vec3f(0,0,0)
	if args.pos then self.pos:set(args.pos:unpack()) end
	self.oldpos = vec3f(self.pos:unpack())

	self.vel = vec3f(0,0,0)
	if args.vel then self.vel:set(args.vel:unpack()) end

	self.bbox = box3f(self.class.bbox)
	if args.bbox then self.bbox = box3f(args.bbox) end

	self.colorMatrix = matrix_ffi(assert(args.colorMatrix or self.class.colorMatrix), 'float')

	self.sprite = args.sprite
	self.seq = args.seq

	self.interactInWorld = args.interactInWorld

	-- what tile indexes -> obj lists this object is a part of 
	self.tiles = {}

	self:setPos(self.pos:unpack())

	-- TODO not until after subclass ctor is done
	--self:move(vec3f(), 1)
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
	self.removeFlag = true
end

function Obj:setPos(x,y,z)
	self:unlink()
	self.pos:set(x,y,z)	
	self:link()
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
		elseif side == 1 then 
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
		elseif side == 2 then 
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
	return 0
end

Obj.gravity = -9.8
Obj.useGravity = true	-- or TODO just change the gravity value to zero?
Obj.collidesWithTiles = true
Obj.collidesWithObjects = true
Obj.itemTouch = false	-- for items only, to add a touch test upon creation
Obj.collideFlags = 0

local epsilon = 1e-5
function Obj:update(dt)
	local game = self.game

	if self.removeDuration
	and game.time >= self.createTime + self.removeDuration
	then
		self:remove()
		return
	end

	self.angle = self.angle + self.rotation * dt

	if self.vel.x ~= 0
	or self.vel.y ~= 0
	or self.vel.z ~= 0
	or self.itemTouch
	then
		self:move(self.vel, dt)
	end

	if self.useGravity
	and 0 == bit.band(self.collideFlags, sides.flags.zm)
	then
		self.vel.z = self.vel.z + self.gravity * dt
	end
end

local omin = vec3f()
local omax = vec3f()
function Obj:move(vel, dt)
	local map = self.map
	
	self:unlink()

	self.oldpos:set(self.pos:unpack())

-- [[
	self.pos.x = self.pos.x + vel.x * dt
	self.pos.y = self.pos.y + vel.y * dt
	self.pos.z = self.pos.z + vel.z * dt
--]]

	self.collideFlags = 0

	if self.collidesWithTiles
	or self.collidesWithObjects
	or self.itemTouch
	then
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
					if i >= 0 and i < map.size.x and j >= 0 and j < map.size.y and k >= 0 and k < map.size.z then
						local voxelIndex = i + map.size.x * (j + map.size.y * k)
						local voxel = map:getTile(i,j,k)
						if self.collidesWithTiles
						and voxel
						and voxel.type > 0
						then
							local voxelType = Tile.types[voxel.type]
							if not voxelType then error("failed to find voxelType for type "..tostring(tiletype)) end
							if voxelType.solid then
								omin:set(i,j,k)
								omax:set(i+1,j+1,k+.5*(2-voxel.half))
								
								-- TODO trace gravity fall downward separately
								-- then move horizontall
								-- if push fails then raise up, move, and go back down, to try and do steps
								local collided = push(self.pos, self.bbox.min, self.bbox.max, omin, omax, vel)
								self.collideFlags = bit.bor(self.collideFlags, collided)
							end
						end
						local objs = map.objsPerTileIndex[voxelIndex]
						if objs then
							for _, obj in ipairs(objs) do
								if not obj.removeFlag then
									-- TODO if obj.solid
									if obj.collidesWithObjects 
									or obj.itemTouch
									or self.itemTouch
									then
										local collided = push(self.pos, self.bbox.min, self.bbox.max, obj.pos + obj.bbox.min, obj.pos + obj.bbox.max, vel, self.itemTouch or obj.itemTouch)
										self.collideFlags = bit.bor(self.collideFlags, collided)
										if collided ~= 0 then
											-- TODO set obj.collideFlags also?
											if self.touch then
												self:touch(obj)
											end
											if not obj.removeFlag 
											and not self.removeFlag 
											and obj.touch then
												obj:touch(self)
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
	end

	self:link()
end

-- ccw start at 0' (with 45' spread)
-- TODO use 8 points as well?
local dirSeqSuffixes = {'_r', '_u', '_l', '_d'}

local matrix_ffi = require 'matrix.ffi'
local modelMat = matrix_ffi({4,4},'float'):zeros():setIdent()

function Obj:draw()
	local map = self.map
	local game = self.game
	local app = game.app

--print('drawing', self.sprite, self.seq, self.frame, self.angle)
	if self.sprite then
		local sprite = anim[self.sprite]
		if sprite then
			local seqname = self.seq
			if seqname then
				if sprite.useDirs then	-- enable this for sequences that use _u _d _l _r etc (TODO search by default?)
					local relAngle = self.angle - app.viewYaw
					local angleIndex = math.floor(relAngle / (.5 * math.pi) + .5) % 4 + 1
					seqname = seqname .. dirSeqSuffixes[angleIndex]
--print('angle', self.angle, 'index', angleIndex, 'seqname', seqname)
				end
				local seq = sprite[seqname]
--print('seqname', seqname, 'seq', seq)
				if seq and self.frame then
					local frame = seq[self.frame]
					self.currentFrame = frame
					if frame.atlasTcPos then
						--[[ draw immediately
						self:drawSprite()
						--]]
						-- [[
						game.spriteDrawList:insert(self)
						--]]
					elseif frame.mesh then
						--[[
						self:drawMesh()
						--]]
						-- [[
						game.meshDrawList:insert(self)
						--]]
					else
						error("hmm error in frame table")
					end
				end
			end
		end
	end
end

local identMat4 = matrix_ffi({4,4},'float'):lambda(function(i,j) return i==j and 1 or 0 end)
function Obj:drawSprite(index)
	local frame = self.currentFrame
	local map = self.map
	local game = self.game
	local app = game.app
	local view = app.view

--[=[ old GL uniform way
	local shader = app.spriteShader
	local uscale = -1
	local vscale = 1
	if frame.hflip then uscale = uscale * -1 end
	if self.vflip then vscale = vscale * -1 end
	
	gl.glUniform2f(shader.uniforms.uvscale.loc, uscale, vscale)
	gl.glUniform2f(shader.uniforms.drawCenter.loc, self.drawCenter:unpack()) 
	gl.glUniform2f(shader.uniforms.drawSize.loc, self.drawSize:unpack()) 
	gl.glUniform1f(shader.uniforms.disableBillboard.loc, self.disableBillboard and 1 or 0)
	
	-- angle to apply relative to billboard in view space
	gl.glUniform2f(shader.uniforms.drawAngleDir.loc, math.cos(self.drawAngle), math.sin(self.drawAngle))
	
	-- angle cos&sin ... angle is for models, but for sprites will be used when disableBillboard is set. 
	gl.glUniform2f(shader.uniforms.angleDir.loc, math.cos(self.angle), math.sin(self.angle))
	
	gl.glUniform3f(shader.uniforms.pos.loc,
		self.pos.x + self.spritePosOffset.x,
		self.pos.y + self.spritePosOffset.y,
		self.pos.z + self.spritePosOffset.z)
	
-- [[ 
	-- vector
	--gl.glUniform4f(shader.uniforms.color.loc, self.color:unpack())
	-- matrix
	gl.glUniformMatrix4fv(shader.uniforms.colorMatrix.loc, 1, gl.GL_FALSE, self.colorMatrix.ptr)
--]] 
--[[ cheap hack for cheap lighting
	-- TODO update for colorMatrix
	local cr, cg, cb, ca = self.color:unpack()
	local x = math.floor(self.pos.x)
	local y = math.floor(self.pos.y)
	local z = math.floor(self.pos.z)
	if x >= 0 and x < map.size.x
	and y >= 0 and y < map.size.y
	then
		local cx = bit.rshift(x, map.Chunk.bitsize.x)
		local dx = bit.band(x, map.Chunk.bitmask.x)
		local cy = bit.rshift(y, map.Chunk.bitsize.y)
		local dy = bit.band(y, map.Chunk.bitmask.y)
		local cz = map.sizeInChunks.z-1
		local chunk = map.chunks[cx + map.sizeInChunks.x * (cy + map.sizeInChunks.y * cz)]
		local surface = chunk.surface[dx + map.Chunk.size.x * dy]
		local sunAngle = 2 * math.pi * ((game.time / game.secondsPerDay) % 1)
		local sunlight = sunAngle > surface.minAngle and sunAngle < surface.maxAngle and 1 or .2
		
		local sunWidthInRadians = .1	-- also in map shader
		local sunlight = (
			smoothstep(surface.minAngle - sunWidthInRadians, surface.minAngle + sunWidthInRadians, sunAngle)
			- smoothstep(surface.maxAngle - sunWidthInRadians, surface.maxAngle + sunWidthInRadians, sunAngle)
		) * .9 + .1
	
		if sunlight < 1 then
			cr = cr * sunlight
			cg = cg * sunlight
			cb = cb * sunlight
		end
	end
	gl.glUniform4f(shader.uniforms.color.loc, cr, cg, cb, ca)
--]]	
	
	gl.glUniform1i(shader.uniforms.useSeeThru.loc, self.useSeeThru and 1 or 0)

	-- TODO buffer all these?
	-- or store positions (or 4x for vertexes) in a GL buffer?
	app.spriteSceneObj.geometry:draw()

	--glreport'here'
--]=]
-- [=[ next: write all props to an attribute buffer
-- write as we go and just update the whole buffer
-- TODO later map objs <-> loc in buffer and only update what we need

	-- until I get divisors working
	for i=1,6 do
		local sprite = app.spritesBufCPU:emplace_back()
		sprite.atlasTcPos:set(frame.atlasTcPos:unpack())
		sprite.atlasTcSize:set(frame.atlasTcSize:unpack())
		sprite.hflip = frame.hflip and 1 or 0
		sprite.vflip = self.vflip and 1 or 0
		sprite.disableBillboard = self.displayBillboard and 1 or 0
		sprite.useSeeThru = self.useSeeThru and 1 or 0
		sprite.drawCenter:set(self.drawCenter:unpack())
		sprite.drawSize:set(self.drawSize:unpack())
		sprite.drawAngle = self.drawAngle
		sprite.angle = self.angle
		sprite.pos:set(self.pos:unpack())
		sprite.spritePosOffset:set(self.spritePosOffset:unpack())
		-- TODO store the color as mat4 
		--ffi.copy(sprite.colorMatrix, self.colorMatrix.ptr, ffi.sizeof'float' * 16)
		-- until then ...
		-- col-major or row-major?
		ffi.copy(sprite.colorMatrixR.s, self.colorMatrix.ptr + 0, ffi.sizeof'float' * 4)
		ffi.copy(sprite.colorMatrixG.s, self.colorMatrix.ptr + 4, ffi.sizeof'float' * 4)
		ffi.copy(sprite.colorMatrixB.s, self.colorMatrix.ptr + 8, ffi.sizeof'float' * 4)
		ffi.copy(sprite.colorMatrixA.s, self.colorMatrix.ptr + 12, ffi.sizeof'float' * 4)
	end
--]=]
end

function Obj:drawMesh()
	local frame = self.currentFrame
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
