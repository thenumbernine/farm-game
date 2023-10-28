-- applies functions in-order 
local function behaviors(x, ...)
	for i=1,select('#', ...) do
		local f = select(i, ...)
		x = f(x)
	end
	return x
end
return behaviors
