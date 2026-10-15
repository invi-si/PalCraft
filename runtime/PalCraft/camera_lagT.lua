-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local L={}
local function angle(v)return(v+180)%360-180 end
function L.step(s,p,r,dt,reset)
 dt=math.max(0,math.min(.1,dt or 0));local a=1-math.exp(-12*dt);local b=1-math.exp(-6*dt);local pitchLag=1-math.exp(-4*dt)
 if reset or not s.p or (p.X-s.p.X)^2+(p.Y-s.p.Y)^2+(p.Z-s.p.Z)^2>2500^2 then
  s.p={X=p.X,Y=p.Y,Z=p.Z};s.r={Pitch=r.Pitch,Yaw=r.Yaw,Roll=0}
 else
  for _,k in ipairs({'X','Y','Z'})do s.p[k]=s.p[k]+(p[k]-s.p[k])*a end
  s.r.Pitch=angle(s.r.Pitch+angle(r.Pitch-s.r.Pitch)*pitchLag)
  s.r.Yaw=angle(s.r.Yaw+angle(r.Yaw-s.r.Yaw)*b);s.r.Roll=0
 end
 return s.p,s.r
end
return L
