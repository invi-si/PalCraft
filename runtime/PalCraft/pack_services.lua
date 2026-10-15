-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local P={}
function P.disabledMobs()
 return {slots={},arrows={},events={},combat=nil,
  start=function()end,cancel=function()end,captureSwing=function()return nil end,
  hit=function()return false end}
end
function P.start(flags,pack,name,object,env)
 if not flags:has(pack)then return false end
 assert(object and type(object.start)=='function','Missing PalCraft service: '..name)
 object:start(env);return true
end
return P
