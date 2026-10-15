-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local R={radius=2400,pending='background109',budgetMs=4}
function R.distance(c,p)return(c.x*100+50-p.X)^2+(c.y*100+50-p.Y)^2 end

R.alex={X=-336050,Y=267200,Z=5400,radius=500,name='alex'}
function R.anchors(cells,entities,registry,islands,spawn)
 local anchors={R.alex}
 local function add(c,r,name,dx,dy)
  anchors[#anchors+1]={X=c.x*100+50+(dx or 0),Y=c.y*100+50+(dy or 0),Z=c.z*100,radius=r,name=name}
 end
 for k,c in pairs(cells)do
  local name=registry[c.type or 1].name
  if name=='bed'then
   add(c,1200,'bed/base-waystone') 
  elseif entities[k]or name=='crafting_table'or name=='furnace'or name=='chest'then add(c,400,'owned:'..k)end
 end
 if spawn and spawn~=false and cells[spawn.key]then add(cells[spawn.key],1200,'saved-bed')end
 for k,i in pairs(islands or{})do
  for _,field in ipairs({'statue','arrival','dock'})do local p=i.data[field]
   if p then anchors[#anchors+1]={X=p.X,Y=p.Y,Z=p.Z,radius=500,name=k..':'..field}end
  end
 end
 return anchors
end
function R.priority(c,p,anchors)
 if R.distance(c,p)<=R.radius^2 then return true end
 for _,a in ipairs(anchors or{})do

  if (a.X-p.X)^2+(a.Y-p.Y)^2<=(R.radius+a.radius)^2 and R.distance(c,a)<=a.radius^2 then return true end
 end
 return false
end
function R.order(groups,p,anchors)
 local ordered,near={},0
 for k,g in pairs(groups)do
  table.sort(g,function(a,b)return R.distance(a,p)<R.distance(b,p)end)
  local d=R.distance(g[1],p);local priority=false
  for _,c in ipairs(g)do if R.priority(c,p,anchors)then priority=true;break end end
  ordered[#ordered+1]={group=g,key=k,d=d,priority=priority}
  if priority then near=near+1 end
 end
 table.sort(ordered,function(a,b)
  if a.priority~=b.priority then return a.priority end
  return a.d==b.d and a.key<b.key or a.d<b.d
 end)
 return ordered,near
end

function R.limit(cost,elapsed)
 local available=R.budgetMs-(elapsed or 0)-.5
 if available<=0 then return 0 end
 return math.max(1,math.min(8,math.floor(available/math.max(.25,cost or 3))))
end
function R.cost(previous,ms,n)return math.max(.25,(previous or 3)*.98,ms/math.max(1,n)*1.25)end
function R.batch(row,first,limit,cells,pending,key,chunkKey,intersects)
 local batch={};local last=math.min(#row.group,first+limit-1)
 for i=first,last do local c=row.group[i];local k=key(c.x,c.y,c.z)

  if cells[k]==c and pending[k]==R.pending then
   if chunkKey(c)~=row.key or intersects(c)then pending[k]=true
   else pending[k]=nil;batch[#batch+1]=c end
  end
 end
 return batch,last+1
end
return R
