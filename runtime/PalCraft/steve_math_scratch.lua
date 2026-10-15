-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(M)
 local pool,index,active={},0,false
 local function out(x,y,z,w)
  local t
  if active then index=index+1;t=pool[index];if not t then t={};pool[index]=t end else t={}end
  t.X=x;t.Y=y;t.Z=z;t.W=w;return t
 end
 function M.beginFrame()index=0;active=true end
 function M.endFrame()active=false;M.scratchTables=#pool end
 function M.mul(a,b)return out(a.W*b.X+a.X*b.W+a.Y*b.Z-a.Z*b.Y,a.W*b.Y-a.X*b.Z+a.Y*b.W+a.Z*b.X,a.W*b.Z+a.X*b.Y-a.Y*b.X+a.Z*b.W,a.W*b.W-a.X*b.X-a.Y*b.Y-a.Z*b.Z)end
 function M.inv(q)return out(-q.X,-q.Y,-q.Z,q.W)end
 function M.axis(x,y,z,a)local s=math.sin(a/2);return out(x*s,y*s,z*s,math.cos(a/2))end
 function M.add(a,b)return out(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
 function M.sub(a,b)return out(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
 function M.rotate(q,v)
  local x,y,z,w=q.X,q.Y,q.Z,q.W;local xx,yy,zz,ww=x*x,y*y,z*z,w*w
  return out((ww+xx-yy-zz)*v.X+2*(x*y-w*z)*v.Y+2*(x*z+w*y)*v.Z,2*(x*y+w*z)*v.X+(ww-xx+yy-zz)*v.Y+2*(y*z-w*x)*v.Z,2*(x*z-w*y)*v.X+2*(y*z+w*x)*v.Y+(ww-xx-yy+zz)*v.Z)
 end
 function M.blend(a,b,t)
  local dot=a.X*b.X+a.Y*b.Y+a.Z*b.Z+a.W*b.W;local s=dot<0 and-1 or 1
  local x,y,z,w=a.X+(b.X*s-a.X)*t,a.Y+(b.Y*s-a.Y)*t,a.Z+(b.Z*s-a.Z)*t,a.W+(b.W*s-a.W)*t
  local n=math.sqrt(x*x+y*y+z*z+w*w);return out(x/n,y/n,z/n,w/n)
 end
 return M
end
