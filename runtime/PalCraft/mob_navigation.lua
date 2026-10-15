-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(cells,key,registry)
 local N={}
 function N:solid(x,y,z)
  local c=cells()[key(x,y,z)];if not c then return false end;local d=registry[c.type]
  return d and d.name~='water'and d.name~='lava'and(d.kind=='cube'or d.kind=='slab'or d.kind=='stairs'or d.kind=='fence'or d.kind=='pane')
 end
 function N:clear(x,y,z,r,h)
  for gx=math.floor((x-r)/100),math.floor((x+r)/100)do for gy=math.floor((y-r)/100),math.floor((y+r)/100)do
   local dx=math.max(gx*100-x,0,x-(gx+1)*100);local dy=math.max(gy*100-y,0,y-(gy+1)*100)
   if dx*dx+dy*dy<r*r-.01 then for gz=math.floor((z+.5)/100),math.floor((z+h-.5)/100)do if self:solid(gx,gy,gz)then return false end end end
  end end;return true
 end
 function N:surface(x,y,z,r,h,fallback)
  local gx,gy=math.floor(x/100),math.floor(y/100)
  for gz=math.floor((z+100)/100)-1,math.floor((z-310)/100),-1 do
   local top=(gz+1)*100+2
   if self:solid(gx,gy,gz)and top<=z+102 and self:clear(x,y,top,r,h)then return top end
  end
  if fallback and fallback<=z+102 and fallback>=z-310 and self:clear(x,y,fallback,r,h)then return fallback end
 end
 function N:supported(p,r)
  local z=math.floor((p.Z-3)/100)
  if math.abs((z+1)*100+2-p.Z)>3 then return false end
  for x=math.floor((p.X-r)/100),math.floor((p.X+r)/100)do for y=math.floor((p.Y-r)/100),math.floor((p.Y+r)/100)do
   local dx=math.max(x*100-p.X,0,p.X-(x+1)*100);local dy=math.max(y*100-p.Y,0,p.Y-(y+1)*100)
   if dx*dx+dy*dy<r*r and self:solid(x,y,z)then return true end
  end end;return false
 end
 function N:sweep(p,q,r,h)
  local v={X=p.X,Y=p.Y,Z=p.Z};local hits={};local grounded=false
  
  local count=math.max(1,math.ceil(math.max(math.abs(q.X-p.X),math.abs(q.Y-p.Y),math.abs(q.Z-p.Z))/10))
  for _=1,count do for _,axis in ipairs({'Z','X','Y'})do
   local d=(q[axis]-p[axis])/count
   if math.abs(d)>.00001 then local old=v[axis];v[axis]=old+d
    if not self:clear(v.X,v.Y,v.Z,r,h)then
     local lo,hi=0,1;for j=1,10 do local t=(lo+hi)/2;v[axis]=old+d*t;if self:clear(v.X,v.Y,v.Z,r,h)then lo=t else hi=t end end
     v[axis]=old+d*lo;hits[axis]=true;if axis=='Z'and d<0 then grounded=true;v.Z=math.floor((v.Z+2)/100)*100+2 end
    end
   end
  end end
  grounded=grounded or self:supported(v,r)
  return v,grounded,hits.X,hits.Y,hits.Z
 end
 function N:path(s,target,def)
  local radius,height=def.radius,def.height
  local start={X=s.p.X,Y=s.p.Y,Z=s.p.Z};local sx,sy=math.floor(start.X/100),math.floor(start.Y/100)
  local tx,ty=math.floor(target.X/100),math.floor(target.Y/100)
  
  local fallback=not s.ownedTerrain and not self:supported(start,radius)and s.nativeFloor or nil
  local function id(x,y,z)return x..','..y..','..math.floor(z/100)end
  local function heuristic(x,y)return math.sqrt((tx-x)^2+(ty-y)^2)end
  local first={x=sx,y=sy,z=start.Z,g=0,h=heuristic(sx,sy)};first.f=first.h
  local open={first};local known={[id(sx,sy,start.Z)]=first};local closed={};local best=first;local visits=0
  local dirs={{1,0},{0,1},{-1,0},{0,-1},{1,1},{-1,1},{-1,-1},{1,-1}}
  while #open>0 and visits<192 do
   local index=1;for i=2,#open do if open[i].f<open[index].f then index=i end end
   local a=table.remove(open,index);local aid=id(a.x,a.y,a.z)
   if not closed[aid]then closed[aid]=true;visits=visits+1
    if a.h<best.h then best=a end
    if a.x==tx and a.y==ty then best=a;break end
    for _,dir in ipairs(dirs)do
     local x,y=a.x+dir[1],a.y+dir[2];local px,py=x*100+50,y*100+50
     local z=self:surface(px,py,a.z,radius,height,fallback);local jump=false;local step=1
     if not z and(dir[1]==0 or dir[2]==0)then
      
      x,y=a.x+dir[1]*2,a.y+dir[2]*2;px,py=x*100+50,y*100+50
      z=self:surface(px,py,a.z,radius,height,fallback);jump=z~=nil;step=2
     end
     if z and math.abs(x-sx)<=20 and math.abs(y-sy)<=20 then
      local clear=true;local top=math.max(a.z,z)+(jump and 105 or 0)
      for j=1,step*4 do local t=j/(step*4);if not self:clear((a.x+.5)*100+(px-(a.x+.5)*100)*t,(a.y+.5)*100+(py-(a.y+.5)*100)*t,top,radius,height)then clear=false;break end end
      local nid=id(x,y,z);local g=a.g+math.sqrt(dir[1]^2+dir[2]^2)*step+math.abs(z-a.z)/200+(jump and .6 or 0)
      if clear and not closed[nid]and(not known[nid]or g<known[nid].g)then local b={x=x,y=y,z=z,g=g,h=heuristic(x,y),parent=a,jump=jump};b.f=g+b.h;known[nid]=b;open[#open+1]=b end
     end
    end
   end
  end
  local route={};local n=best
  while n and n.parent do table.insert(route,1,{X=n.x*100+50,Y=n.y*100+50,Z=n.z,jump=n.jump});n=n.parent end
  return route,visits,best.h==0
 end
 return N
end
