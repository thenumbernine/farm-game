#!/usr/bin/env luajit

--[[ what's the default jit optimization level?
require 'jit.opt'.start(2)
--]]
--[[ alternatively... this runs about 3x-4x slower
jit.off()
--]]

-- setup before running
-- configure your luajit ffi library locations here

local cmdline = require 'ext.cmdline'(...)

--[[ specify GL version first:
require 'gl.setup'()	-- for desktop GL.  Windows needs this.
--require 'gl.setup' 'OpenGLES1'	-- for GLES1 ... but GLES1 has no shaders afaik?
--require 'gl.setup' 'OpenGLES2'	-- for GLES2
--require 'gl.setup' 'OpenGLES3'	-- for GLES3.  Linux or Raspberry Pi can handle this.
--]]
-- [[ pick gl vs gles based on OS (Linux has GLES and includes embedded)
local glfn = nil	-- default gl
local ffi = require 'ffi'
if ffi.os == 'Linux' then
	glfn = 'OpenGLES3'	-- linux / raspi (which is also classified under ffi.os == 'Linux') can use GLES3
end
if cmdline.gl ~= nil then	-- allow cmdline override
	glfn = cmdline.gl
end
require 'gl.setup'(glfn)
--]]


-- hack vector, instead of resizing by 32 bytes (slowly)
-- how about increase by 20% then round up to nearest 32
local vector = require 'ffi.cpp.vector'
function vector:resize(newsize)
	newsize = tonumber(newsize)
	if newsize > self.capacity then
		local newcap = newsize + bit.rshift(newsize, 1)
		newcap = bit.lshift(bit.rshift(newcap, 5) + 1, 5)
--print('resizing from', self.capacity, 'to', newcap)
		self:reserve(newcap)
	end
	self.size = newsize
end


-- hack ext.table
-- t = table of {.weight=...}
local table = require 'ext.table'
function table.pickWeighted(t)
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


return require 'zelda.app'():run()
