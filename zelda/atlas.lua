-- TODO maybe just generate this file?
-- but idk idun wanna generated files in the zelda folder...
-- and the fromlua() doesn't like 'return's so ...
-- bleh i'm lazy
local path = require 'ext.path'
local fromlua = require 'ext.fromlua'
return assert(fromlua(assert(path'sprites/atlas.lua':read())))
