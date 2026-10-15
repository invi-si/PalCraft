-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local M={};local pi=math.pi;local deg=math.deg
local function angle(x)return(x+180)%360-180 end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function pose(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 local pitch=math.asin(clamp(sz*sy*cx-cz*sx,-1,1));local yaw,roll
 if math.abs(math.cos(pitch))>1e-7 then yaw=math.atan(cz*sy*cx+sz*sx,cy*cx);roll=math.atan(-sz*cy,sz*sy*sx+cz*cx)else yaw=math.atan(sy,cz*cy);roll=0 end
 return{Pitch=deg(pitch),Yaw=deg(yaw),Roll=deg(roll)}
end
local function loc(x,y,z,k,offset)return{X=-z*k,Y=-x*k,Z=offset-y*k}end
function M.frame(kind,models,now,born,yaw,targetYaw,targetPitch,history)
 local age=(now-born)*20;local phase=(now-born)*2*pi*.65;local out={};local by={}
 for i,d in ipairs(models)do by[d.name]=i;out[i]={rotation=d.rotation,location=d.location}end
 local function set(name,rotation,location)local i=by[name];if i then out[i]={rotation=rotation or out[i].rotation,location=location or out[i].location}end end
 if kind=='wither'then
  local f=math.cos(age*.1);local rib=(.065+.05*f)*pi;local tail=(.265+.1*f)*pi;local k=6.25*models[1].scaleMC
  set('ribcage',pose(rib,0,0));set('tail',pose(tail,0,0),loc(-2,6.9+math.cos(rib)*10,-.5+math.sin(rib)*10,k,24*k))
  for _,name in ipairs({'center_head','right_head','left_head'})do
   local side=name=='right_head'and-1 or name=='left_head'and 1 or 0
   local turn=clamp(angle((targetYaw or yaw)-yaw)+side*math.sin(now*1.2)*5,-65,65)
   set(name,pose(math.rad(-(targetPitch or 0)),math.rad(turn),0))
  end
  return out,math.sin(age*.1)*9
 end
 local flap=(math.sin(phase-1)+1);flap=(flap*flap+flap*2)*.05
 set('jaw',pose((math.sin(phase)+1)*.2,0,0))
 local x=.125-math.cos(phase)*.2;local y=-.25;local z=-(math.sin(phase)+.125)*.8;local tip=(math.sin(phase+2)+.5)*.75
 set('left_wing',pose(x,y,z));set('left_wing_tip',pose(0,0,tip));set('right_wing',pose(x,-y,-z));set('right_wing_tip',pose(0,0,-tip))
 for _,side in ipairs({'left','right'})do
  set(side..'_front_leg',pose(1.3+flap*.1,0,0));set(side..'_front_leg_tip',pose(-.5-flap*.1,0,0));set(side..'_front_foot',pose(.75+flap*.1,0,0))
  set(side..'_hind_leg',pose(1+flap*.1,0,0));set(side..'_hind_leg_tip',pose(.5+flap*.1,0,0));set(side..'_hind_foot',pose(.75-flap*.1,0,0))
 end
 local function previous(back)return history and history[math.max(1,#history-back)]or yaw end
 local turn=angle(previous(5)-previous(10));local k=6.25*models[1].scaleMC;local offset=320
 set('body',pose(0,0,-math.rad(turn)*1.5))
 local nx,ny,nz=0,20,-12
 for i=0,4 do
  local a=math.cos(i*.45+phase)*.15;local b=math.rad(angle(previous(5-i)-previous(6)))*1.5
  set('neck'..i,pose(a,b,0),loc(nx,ny,nz,k,offset))
  nx=nx-math.sin(b)*math.cos(a)*10;ny=ny+math.sin(a)*10;nz=nz-math.cos(b)*math.cos(a)*10
 end
 set('head',pose(math.rad(-(targetPitch or 0))*.4,math.rad(clamp(angle((targetYaw or yaw)-yaw),-35,35)),0),loc(nx,ny,nz,k,offset))
 nx,ny,nz=0,10,60;local wave=0
 for i=0,11 do
  wave=wave+math.sin(i*.45+phase)*.05;local b=math.rad(angle(previous(12+i)-previous(11)))*1.5+pi
  set('tail'..i,pose(wave,b,0),loc(nx,ny,nz,k,offset))
  nx=nx-math.sin(b)*math.cos(wave)*10;ny=ny+math.sin(wave)*10;nz=nz-math.cos(b)*math.cos(wave)*10
 end
 return out,flap*12
end
return M
