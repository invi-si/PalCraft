-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local S={}
local numbers={age=7,moist=7,dry=120,distance=7,facing=3,half=1,embed=35,cookLeft=30}
local flags={persistent=true,decay=true,lit=true,cooked=true}
function S.copy(state,name,saving)
 if state==nil then assert(name~='bed','Bed requires facing and half');return nil end
 assert(type(state)=='table','Cell state must be a table');local result={};local n=0
 for k,v in pairs(state)do
  if numbers[k]then assert(type(v)=='number'and v%1==0 and v>=0 and v<=numbers[k],'Invalid state '..k);if k=='facing'or k=='half'then assert(name=='bed'or(k=='half'and(name=='sunflower'or name=='lilac'or name=='rose_bush'or name=='peony'or name=='tall_grass')),'Invalid paired state')end;if k=='embed'then assert((name=='coal_ore'or name=='iron_ore')and state.resource and state.resource:match('^island_ore_%d%d$'),'Embedded offset outside resource ore')end;result[k]=v;n=n+1
  elseif flags[k]then assert(type(v)=='boolean','Invalid state '..k);if not(saving and name=='tnt'and k=='lit')then result[k]=v;n=n+1 end
  elseif k=='plant'then assert(name=='flower_pot'and type(v)=='string'and v:match('^MC_[A-Za-z]+$'),'Invalid pot item');result[k]=v;n=n+1
  elseif k=='cookItem'or k=='cookResult'then assert(name=='campfire'and type(v)=='string'and v:match('^MC_[A-Za-z]+$'),'Invalid campfire item');result[k]=v;n=n+1
  elseif k=='resource'then
   local ore=type(v)=='string'and v:match('^island_ore_(%d%d%d)$');ore=ore and tonumber(ore)
   local plains=v=='x8_plains_coal'or v=='x8_plains_copper'or v=='x8_plains_iron'
   assert(type(v)=='string'and(v:match('^island_tree_%d%d$')or v:match('^island_ore_%d%d$')or(ore and ore>=101 and ore<=139)or plains),'Invalid resource node');result[k]=v;n=n+1
  elseif k=='fuse'then assert(type(v)=='number'and v>=0 and v<=80,'Invalid fuse')
  else error('Unknown cell state '..tostring(k))end
 end
 if name=='bed'then assert(result.facing~=nil and result.half~=nil,'Bed requires facing and half')end
 return n>0 and result or nil
end
function S.row(c,name)
 local state=S.copy(c.state,name,true)
 return {c.x,c.y,c.z,c.debug and 1 or 0,name,name=='tnt'and 0 or(c.variant or 0),c.support or'',c.open and 1 or 0,state or false}
end
function S.load(row,name)
 local state=row[9];if state==false then state=nil end
 local result=S.copy(state,name,false)
 if name=='tnt'and result then result.lit=nil;result.fuse=nil end
 return result
end
return S
