-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local H={}
local pi=math.pi
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
function H.cooldown(id)
 if id and id:find('Sword',1,true)then return 1/1.6 end
 if id and id:find('Axe',1,true)then return (id:find('Wooden',1,true)or id:find('Stone',1,true))and 1/.8 or id:find('Iron',1,true)and 1/.9 or 1 end
 return .3
end
function H.swing(age)return age and age>=0 and age<.3 and age/.3 or 0 end
function H.step(s,id,now,pitch,yaw,speed,dt)
 s.height=s.height or 1;s.visible=s.visible or id;s.pitch=s.pitch or pitch;s.yaw=s.yaw or yaw;s.walk=s.walk or 0;s.bob=s.bob or 0
 s.pitch=s.pitch+(pitch-s.pitch)*(1-.5^(dt*20))
 s.yaw=s.yaw+((yaw-s.yaw+180)%360-180)*(1-.5^(dt*20))
 s.bob=s.bob+(math.min(speed/1000,.1)-s.bob)*(1-.6^(dt*20));s.walk=s.walk+speed/100*dt*.6
 local target=s.visible==id and 1 or 0;s.height=s.height+clamp(target-s.height,-8*dt,8*dt)
 if s.height<.1 then s.visible=id end
 s.at=now;return s
end
function H.view(M,s,v)
 local q={X=0,Y=0,Z=0,W=1};local p={X=0,Y=0,Z=0}
 local function turn(x,y,z,a)q=M.mul(q,M.axis(x,y,z,math.rad(a)))end
 local function move(x,y,z)p=M.add(p,M.rotate(q,{X=x,Y=y,Z=z}))end
 
 turn(1,0,0,(v.pitch-s.pitch)*.1);turn(0,1,0,((v.yaw-s.yaw+180)%360-180)*.1)
 local walk=-s.walk;move(math.sin(walk*pi)*s.bob*.5,-math.abs(math.cos(walk*pi)*s.bob),0)
 turn(0,0,1,math.sin(walk*pi)*s.bob*3);turn(1,0,0,math.abs(math.cos(walk*pi-.2)*s.bob)*5)
 local a=v.swing or 0;local root=math.sqrt(a);local wave=math.sin(root*pi)
 if v.use=='eat'then
  local f=clamp((v.useAge or 0)/1.6,0,1);local remaining=1-f
  if remaining<.8 then move(0,math.abs(math.cos((v.useAge or 0)*20/4*pi))*.1,0)end
  local e=1-remaining^27;move(e*.6,-e*.5,0);turn(0,1,0,e*90);turn(1,0,0,e*10);turn(0,0,1,e*30)
 end
 move(-.4*wave,.2*math.sin(root*2*pi),-.2*math.sin(a*pi))
 move(.56,-.52-(1-s.height)*.6,-.72)
 if v.use=='bow'then
  move(-.2785682,.18344387,.15731531);turn(1,0,0,-13.935);turn(0,1,0,35.3);turn(0,0,1,-9.785)
  local t=clamp(v.useAge or 0,0,1);local draw=clamp((t*t+t*2)/3,0,1)
  if draw>.1 then move(0,math.sin(((v.useAge or 0)*20-.1)*1.3)*(draw-.1)*.004,0)end
  move(0,0,draw*.04)
 elseif v.use=='block'then move(-.14142136,.08,.14142136);turn(1,0,0,-102.25);turn(0,1,0,13.365);turn(0,0,1,78.05)
 else turn(0,1,0,45-math.sin(a*a*pi)*20);turn(0,0,1,-wave*20);turn(1,0,0,-wave*80);turn(0,1,0,-45)end
 return p,q
end
return H
