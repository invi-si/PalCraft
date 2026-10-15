-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(cells,registry,entities,p)
 local list={}
 for key,c in pairs(cells)do
  local d=registry[c.type];local e=entities[key];local level=d.kind=='furnace'and e and(e.burn or 0)>0 and 13 or d.light or 0
  if level>0 then
   local q={X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+50}
   if d.kind=='torch'then q.Z=c.z*100+70 end
   local distance=(q.X-p.X)^2+(q.Y-p.Y)^2+(q.Z-p.Z)^2
   if distance<(level*100+2500)^2 then list[#list+1]={key=key,cell=c,point=q,level=level,distance=distance,name=d.name}end
  end
 end
 table.sort(list,function(a,b)if a.distance==b.distance then return a.key<b.key end;return a.distance<b.distance end)
 local selected={};for i=1,math.min(24,#list)do selected[i]=list[i]end;return selected,#list
end
