#!/usr/bin/env luajit
-- cycle through all sprites in jpeg
-- histogram to find their greatest color
-- replace it with alpha
-- downsize too i.g. but what targt size?
local ffi = require 'ffi'
local path = require 'ext.path'
local table = require 'ext.table'
local string = require 'ext.string'
local Image = require 'image'

local srcdir = path'src_online'
local fs = srcdir:rdir()		-- TODO will rdir use / or \ in Windows? I'm assuming / always, like path() uses
for _,srcfn in ipairs(fs) do
	local _, sprite, frame = string.split(srcfn, '/'):unpack()
	local src = path(srcfn)
	local dstfn = assert(srcfn:gsub('^src_online', 'sprites'))
	local dst = path(dstfn):setext'png'
	path((dst:getdir())):mkdir(true)

	print('convert "'..src..'" "'..dst..'"')
	--[[ imagemagick looks like it takes a lot of work to do this ...
	-- https://stackoverflow.com/a/27194202/2714073
	--]]
	-- [[ here's another attempt
	-- https://stackoverflow.com/a/73428638/2714073
	-- looks good but you gotta know the background beforehand
	--]]
	-- [[ so I'll just use my own 
	local srcimg = Image(tostring(src))
	--print(require 'ext.tolua'(srcimg))

	-- don't cut background out of 'maptiles'
	local dstimg
	if sprite == 'maptiles' then
		dstimg = srcimg
			:setChannels(4)
		-- make water transparent
		if frame:match'^water' then
			local r,g,b,a = dstimg:split()
			a = a * .7
			dstimg = Image.combine(r,g,b,a)
		end
	else
		local hist = srcimg:getHistogram()
		local bgcount, bgcolor = table.sup(hist)
		local br, bg, bb = bgcolor:byte(1,3)

		dstimg = srcimg
			:setChannels(4)
		
		-- [=[
		for j=0,dstimg.height-1 do
			for i=0,dstimg.width-1 do
				local p = dstimg.buffer + 4 * (i + dstimg.width * j)
				local r,g,b = p[0], p[1], p[2]
				-- TODO colorspace for measuring distance?
				local dist = math.sqrt((br - r)^2 + (bg - g)^2 + (bb - b)^2)
				if dist < 30 then
					p[0] = 0
					p[1] = 0
					p[2] = 0
					p[3] = 0
				else
					p[3] = 255
				end
			end
		end
		--]=]
		
	-- [[ blob-detection because it looks like there's a lot of pixel blobs that could stand to be filtered out
		local blobs = dstimg:getBlobs{
			classify = function(p)
				return p[3]			-- classify blobs by alpha
			end,
		}
	--]]

		print('#blobs', #blobs)
		--print(table(blobs):map(function(blob,k,t) return blob:calcArea(), #t+1 end):sort():concat', ')

	-- [=[
		local tmp = Image(dstimg.width, dstimg.height, 4, 'unsigned char')
			:clear()
		-- [[
		for _,blob in pairs(blobs) do
			if blob.cl > 0 then
				local area = blob:calcArea()
				if area > 3000 then
					blob:copyToImage(tmp, dstimg)
				end
			end
		end
		--]]
		dstimg = tmp
	--]=]

	-- [=[
		-- zealous-crop
		dstimg = dstimg:zealousCrop()
	end

	local w, h = dstimg:size()
	local s = math.max(w, h)
	
	--[[ recenter? 
	dstimg = Image(s, s, dstimg.channels, dstimg.format):paste{
		image = dstimg,
		x = math.floor((s - w) / 2),
		y = math.floor((s - h) / 2),
	}
	--]]

	local targetsize = 64
	local planttype = 'plant'
	if tostring(src):find'fruit' then
		planttype = 'fruit'	-- really this is not a plantType, but it goes in this sprite folder
	elseif tostring(src):find'item' then
		planttype = 'item'	-- really this is not a plantType, but it goes in this sprite folder
	elseif tostring(src):find'tree' then
		targetsize = 128
		planttype = 'tree'
	elseif tostring(src):find'bush' then
		planttype = 'bush'
	end
print('targetsize', targetsize)

	dstimg = dstimg:resize(math.ceil(targetsize*w/s), math.ceil(targetsize*h/s))
--]=]

	dstimg:save(tostring(dst))
	--]]
	
	--[[ last, copy it into its dst live folder ... ?
	local dst2 = path(assert(dst.path:gsub('^sprites', '../sprites'))):setext'png'
	path((dst2:getdir())):mkdir(true)
	
	print('also saving to', dst2)
	dstimg:save(tostring(dst2))
	--]]
end
