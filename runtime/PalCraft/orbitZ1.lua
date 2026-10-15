-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local O={}
local function angle(a)return(a+180)%360-180 end
local function clamp(a,l,h)return math.max(l,math.min(h,a))end
function O.step(s,control,heading,now,dt,first,reset)
 local p=angle(control.Pitch);local y=angle(control.Yaw)
 if reset or not s.control then
  s.yaw=y;s.pitch=clamp(p,-70,65);s.lastMouse=now;s.control={yaw=y,pitch=p}
 end
 local dy,dp=angle(y-s.control.yaw),angle(p-s.control.pitch)
 s.control.yaw,s.control.pitch=y,p
 local moved=math.abs(dy)+math.abs(dp)>.015
 if moved then s.lastMouse=now;s.yaw=angle(s.yaw+dy);s.pitch=clamp(s.pitch+dp,-70,65)end
 s.following=not first and now-s.lastMouse>=1.5
 if first then
  s.yaw=angle(heading+clamp(angle(s.yaw-heading),-100,100));s.pitch=clamp(s.pitch,-65,65)
 elseif s.following then
  local a=1-math.exp(-1.6*clamp(dt,0,.1));s.yaw=angle(s.yaw+angle(heading-s.yaw)*a)
 end
 return{Yaw=s.yaw,Pitch=s.pitch,Roll=0},moved
end
return O
