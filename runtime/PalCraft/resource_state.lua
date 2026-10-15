-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local S={}
function S.empty()return{version=1,clock=0,nodes={}}end
function S.validate(d)
 if d==nil then return S.empty()end
 if type(d)~='table'or d.version~=1 or type(d.clock)~='number'or d.clock~=d.clock or d.clock<0 or d.clock>1e12 or type(d.nodes)~='table'then return nil end
 local n=0
 for id,r in pairs(d.nodes)do
  local ore=type(id)=='string'and id:match('^island_ore_(%d%d%d)$');ore=ore and tonumber(ore)
  local plains=id=='x8_plains_coal'or id=='x8_plains_copper'or id=='x8_plains_iron'
  n=n+1;if n>67 or type(id)~='string'or not(id:match('^island_tree_%d%d$')or id:match('^island_ore_%d%d$')or(ore and ore>=101 and ore<=139)or plains)then return nil end
  if type(r)~='table'or not({new=true,growing=true,active=true,waiting=true})[r.phase]or type(r.cycle)~='number'or r.cycle%1~=0 or r.cycle<0 or r.cycle>1e8 then return nil end
  if r.due~=nil and(type(r.due)~='number'or r.due~=r.due or r.due<0 or r.due>1e12)then return nil end
  if r.phase=='waiting'and r.due==nil then return nil end
 end
 return d
end
return S
