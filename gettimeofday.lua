require 'ffi.c.sys.time'
local ffi = require 'ffi'

local gettimeofday_tv = ffi.new('struct timeval[1]')
local function gettimeofday()
	local results = ffi.C.gettimeofday(gettimeofday_tv, nil)
	return tonumber(gettimeofday_tv[0].tv_sec) + tonumber(gettimeofday_tv[0].tv_usec) / 1000000
end

return gettimeofday
