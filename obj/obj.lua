local gl = require 'gl'
local class = require 'ext.class'
local vec2f = require 'vec-ffi.vec2f'
local vec3f = require 'vec-ffi.vec3f'
local vec4f = require 'vec-ffi.vec4f'
local anim = require 'zelda.anim'
local GLTex2D = require 'gl.tex2d'
local Tile = require 'zelda.tile'
local sides = require 'zelda.sides'

local Obj = class()

-- default
Obj.seq = 'stand'
Obj.frame = 1

function Obj:init(args)
	assert(args)
	self.game = assert(args.game)

	self.angle = 1.5 * math.pi
	
	if not self.drawSize then
		self.drawSize = vec2f(1,1)
	else
		self.drawSize = vec2f(self.drawSize:unpack())
	end
	if args.drawSize then self.darwSize:set(args.drawSize:unpack()) end

	self.pos = vec3f(0,0,0)
	if args.pos then self.pos:set(args.pos:unpack()) end
	self.oldpos = vec3f(self.pos:unpack())

	self.vel = vec3f(0,0,0)
	if args.vel then self.vel:set(args.vel:unpack()) end

	-- [[[ bbox
	self.min = vec3f(-.3, -.3, -.3)
	if args.min then self.min:set(args.min:unpack()) end
	
	self.max = vec3f(.3, .3, .3)
	if args.max then self.max:set(args.max:unpack()) end
	--]]

	self.color = vec4f(1,1,1,1)
	if args.color then self.color:set(args.color:unpack()) end
end

-- how to handle collision?
-- go back to start of trace?
-- find intersection and then redo collision over remaining timestep?
-- or just push? how about just push
local epsilon = 1e-5
local function push(pos, min, max, bmin, bmax, vel)
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
			vel.x = 0
			if pm == 1 then
				pos.x = bmin.x - max.x - epsilon
				return sides.flags.xp
			else
				pos.x = bmax.x - min.x + epsilon
				return sides.flags.xm
			end
		elseif side == 1 then 
			vel.y = 0 
			if pm == 1 then
				pos.y = bmin.y - max.y - epsilon
				return sides.flags.yp
			else
				pos.y = bmax.y - min.y + epsilon
				return sides.flags.ym
			end
		elseif side == 2 then 
			vel.z = 0
			if pm == 1 then
				pos.z = bmin.z - max.z - epsilon
				return sides.flags.zp
			else
				pos.z = bmax.z - min.z + epsilon
				return sides.flags.zm
			end
		end
	end
	return 0
end

Obj.gravity = -9.8
Obj.hitsides = 0
Obj.useGravity = true	-- or TODO just change the gravity value to zero?
Obj.collidesWithTiles = true

local epsilon = 1e-5
function Obj:update(dt)
	self.oldpos:set(self.pos:unpack())


-- [[
	self.pos.x = self.pos.x + self.vel.x * dt
	self.pos.y = self.pos.y + self.vel.y * dt
	self.pos.z = self.pos.z + self.vel.z * dt
--]]

	if self.useGravity then
		self.vel.z = self.vel.z + self.gravity * dt
	end

	self.collideFlags = 0

	if self.collidesWithTiles then
		local omin = vec3f()
		local omax = vec3f()
		for i=math.floor(math.min(self.pos.x, self.oldpos.x) + self.min.x - 1.5),math.floor(math.max(self.pos.x, self.oldpos.x) + self.max.x + .5) do
			for j=math.floor(math.min(self.pos.y, self.oldpos.y) + self.min.y - 1.5),math.floor(math.max(self.pos.y, self.oldpos.y) + self.max.y + .5) do
				for k=math.floor(math.min(self.pos.z, self.oldpos.z) + self.min.z - 1.5),math.floor(math.max(self.pos.z, self.oldpos.z) + self.max.z + .5) do
					local tiletype = app.game.map:get(i,j,k)
					if tiletype > 0 then
						local tile = Tile.types[tiletype]
						if tile.solid then
							omin:set(i,j,k)
							omax:set(i+1,j+1,k+1)
							
							-- TODO trace gravity fall downward separately
							-- then move horizontall
							-- if push fails then raise up, move, and go back down, to try and do steps
							local collided = push(self.pos, self.min, self.max, omin, omax, self.vel)
							self.collideFlags = bit.bor(self.collideFlags, collided)
						end
					end
				end
			end
		end
	end
end

-- ccw start at 0' (with 45' spread)
-- TODO use 8 points as well?
local dirSeqSuffixes = {'_r', '_u', '_l', '_d'}

local matrix_ffi = require 'matrix.ffi'
local modelMat = matrix_ffi({4,4},'float'):zeros():setIdent()

function Obj:draw()
	local game = self.game
	local view = game.app.view
--[[
	for faceIndex,faces in ipairs(Tile.cubeFaces) do
		if bit.band(self.hitsides, bit.lshift(1, faceIndex-1)) ~= 0 then
			gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
			gl.glColor3f(1,0,0)
		else
			gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
			gl.glColor3f(1,1,1)
		end
		gl.glBegin(gl.GL_QUADS)
		for f,face in ipairs(faces) do
			local v = Tile.cubeVtxs[face+1]
			gl.glVertex3f(
				self.pos.x + (1 - v[1]) * self.min.x + v[1] * self.max.x,
				self.pos.y + (1 - v[2]) * self.min.y + v[2] * self.max.y,
				self.pos.z + (1 - v[3]) * self.min.z + v[3] * self.max.z)
		end
		gl.glEnd()
	end
	gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
	gl.glColor3f(1,1,1)
--]]

--print('drawing', self.sprite, self.seq, self.frame, self.angle)
	if self.sprite then
		local sprite = anim[self.sprite]
		if sprite then
			local seqname = self.seq
			if seqname then
				if not sprite.dontUseDir then	-- enable this for sequences that use _u _d _l _r etc (TODO search by default?)
					local angleIndex = math.floor(self.angle / (.5 * math.pi) + .5) % 4 + 1
					seqname = seqname .. dirSeqSuffixes[angleIndex]
--print('angle', self.angle, 'index', angleIndex, 'seqname', seqname)
				end
				local seq = sprite[seqname]
--print('seqname', seqname, 'seq', seq)
				if seq and self.frame then
					local frame = seq[self.frame]
					if frame.tex then
						local shader = game.spriteShader
						shader:use()
						gl.glUniformMatrix4fv(shader.uniforms.mvProjMat.loc, 1, gl.GL_FALSE, view.mvProjMat.ptr)

						local uscale = -1
						local vscale = 1
						if frame.hflip then uscale = uscale * -1 end
						if self.vflip then vscale = vscale * -1 end
						frame.tex:bind()
						gl.glVertexAttrib4fv(shader.attrs.color.loc, self.color.s)
						gl.glBegin(gl.GL_QUADS)
						for _,uv in ipairs(Tile.unitquad) do
							gl.glVertexAttrib2f(
								shader.attrs.texcoord.loc,
								(uv[1] - .5) * uscale + .5,
								(uv[2] - .5) * vscale + .5)
							local x,y,z = (
								app.view.angle:xAxis() * (.5 - uv[1]) * self.drawSize.x
								+ app.view.angle:yAxis() * (.5 - uv[2]) * self.drawSize.y
								+ self.pos
							):unpack()
							gl.glVertex3f(x,y,z+.1)
						end
						gl.glEnd()
						frame.tex:unbind()

						shader:useNone()
					elseif frame.mesh then
						modelMat:setTranslate(self.pos:unpack())
						local shader = assert(game.meshShader)
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
									Kd = g.Kd and g.Kd.s or {1,1,1,1},
									Ks = g.Ks and g.Ks.s or {1,1,1,1},
									Ns = g.Ns or 10,
									
									objCOM = vec3f().s,
									groupCOM = vec3f().s,
									groupExplodeDist = 0,
									triExplodeDist = 0,
								}
							end,
						}
						shader:useNone()
						GLTex2D:unbind()
					else
						error("hmm error in frame table")
					end
				end
			end
		end
	end
end

return Obj
