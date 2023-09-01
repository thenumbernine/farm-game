local vec3i = require 'vec-ffi.vec3i'
return {
	-- 1-based ... for table index sake
	-- should it be 0-based for flags' sake?
	indexes = {
		xm = 1,
		ym = 2,
		zm = 3,
		xp = 4,
		yp = 5,
		zp = 6,
	},
	flags = {
		xm = 1,
		ym = 2,
		zm = 4,
		xp = 8,
		yp = 16,
		zp = 32,
	},
	dirs = {
		vec3i(-1,0,0),
		vec3i(0,-1,0),
		vec3i(0,0,-1),
		vec3i(1,0,0),
		vec3i(0,1,0),
		vec3i(0,0,1),
	},
}
