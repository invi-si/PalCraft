-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local P={tick=.05,maxCatchup=5}
local look=dofile((debug.getinfo(1,'S').source:sub(2):match('^(.*)[/\\]'))..'/lookT.lua')
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function angle(x)return(x+180)%360-180 end
local function approach(x,t,n)return x+clamp(t-x,-n,n)end
local function copy(p)return{X=p.X,Y=p.Y,Z=p.Z}end
local spiderOffsets={math.pi*1.5,math.pi/2,math.pi,0};local spiderBases={math.pi/4,math.pi/8,-math.pi/8,-math.pi/4}
local function lerp(a,b,t)return a+(b-a)*t end
function P.turn(yaw,target,dt)return look.approach(yaw,target,200,dt)end
function P.reset(s,now,def)
 s.vx=0;s.vy=0;s.vz=0;s.grounded=true;s.accumulator=0;s.simAt=now;s.simTicks=0;s.droppedSeconds=0
 s.attribute=def.attribute;s.goalSpeed=def.goalSpeed;s.friction=.6;s.headLimit=def.headLimit or 75
 s.entityYaw=s.yaw;s.headYaw=s.yaw;s.lastHeadYaw=s.yaw;s.stableHeadTicks=0;s.previous=copy(s.p)
 s.modelHeadYaw=nil;s.modelHeadPitch=nil
 s.previousYaw=s.yaw;s.previousHeadYaw=s.yaw;s.previousWalk=0;s.previousWeight=0;s.walk=0;s.walkWeight=0
 s.route=nil;s.routeAt=1;s.blockedTicks=0;s.routeReplan=true;s.render=nil;s.jump=nil;s.climbing=nil;s.climbIntent=nil;s.climbLogged=nil
 s.bowEquipped=s.kind=='skeleton';s.usingBow=false
end
function P.body(s,dx,dy)
 local target=s.lookYaw or s.entityYaw or s.yaw;local limit=math.min(75,s.headLimit or 75)
 local bodyTarget=s.yaw
 if dx*dx+dy*dy>.002500000278 then 
  bodyTarget=s.entityYaw;s.lastHeadYaw=s.headYaw;s.stableHeadTicks=0
 else
  if math.abs(angle(target-(s.lastHeadYaw or target)))>15 then s.stableHeadTicks=0;s.lastHeadYaw=target else s.stableHeadTicks=(s.stableHeadTicks or 0)+1 end
  if math.abs(angle(target-s.yaw))>limit or s.stableHeadTicks>10 then bodyTarget=target end
 end
 s.yaw,s.headYaw=look.couple(s.yaw,s.headYaw or s.yaw,bodyTarget,target,.05,limit)
end
function P.knockback(s,strength,towardX,towardY,resistance)
 local n=math.sqrt(towardX*towardX+towardY*towardY);if n<.0001 then return end
 local k=strength*(1-(resistance or 0));s.vx=(s.vx or 0)/2-k*towardX/n;s.vy=(s.vy or 0)/2-k*towardY/n
 if s.grounded then s.vz=math.min(.4,(s.vz or 0)/2+k);s.grounded=false end
end
function P.holdRoute(s)
 local q=s.route and s.route[s.routeAt or 1]
 
 return s.jump or(q and q.jump and(q.X-s.p.X)^2+(q.Y-s.p.Y)^2<240^2)
end
function P.tickStep(s,move)
 s.previous=copy(s.p);s.previousYaw=s.yaw;s.previousHeadYaw=s.headYaw;s.previousWalk=s.walk;s.previousWeight=s.walkWeight

 if math.abs(s.vx or 0)<.003 then s.vx=0 end;if math.abs(s.vy or 0)<.003 then s.vy=0 end;if math.abs(s.vz or 0)<.003 then s.vz=0 end
 local dx,dy=0,0;local target=s.route and s.route[s.routeAt or 1]or s.goal
 if target then
  dx,dy=target.X-s.p.X,target.Y-s.p.Y;local n=math.sqrt(dx*dx+dy*dy)
  if n<20 and s.route and s.routeAt<#s.route then s.routeAt=s.routeAt+1;target=s.route[s.routeAt];dx,dy=target.X-s.p.X,target.Y-s.p.Y;n=math.sqrt(dx*dx+dy*dy)end
  if n>8 then dx,dy=dx/n,dy/n else dx,dy=0,0 end
  if s.grounded and((n<180 and target.Z>s.p.Z+45)or(n<140 and n>25 and target.jump))then s.vz=.42;s.grounded=false;s.jump=true end
 end
 if s.moveIntent==false or s.fuse then dx,dy=0,0 end
 
 local input=(s.attribute or .25)*(s.goalSpeed or 1)
 local factor=s.grounded and input*.21600002/(s.friction or .6)^3 or .02
 s.vx=(s.vx or 0)+dx*factor*input*.98;s.vy=(s.vy or 0)+dy*factor*input*.98
 local desired={X=s.p.X+s.vx*100,Y=s.p.Y+s.vy*100,Z=s.p.Z+(s.vz or 0)*100}
 local q,grounded,hitX,hitY,hitZ=move(s,desired);s.p=q;s.grounded=grounded==true
 if hitX then s.vx=0 end;if hitY then s.vy=0 end;if hitZ then s.vz=0 end
 local actualX,actualY=q.X-s.previous.X,q.Y-s.previous.Y;local distance=math.sqrt(actualX^2+actualY^2)
 s.speed=distance*20;s.walkWeight=s.walkWeight+.4*(math.min(distance/100*4,1)-s.walkWeight);s.walk=s.walk+s.walkWeight
 if distance==0 and s.walkWeight<1e-6 then s.walkWeight=0 end 
 
 if s.climbing then s.vz=.2;s.grounded=false end
 if s.grounded then s.vz=0;s.jump=nil else s.vz=((s.vz or 0)-.08)*.98 end
 local drag=.91*(s.grounded and(s.friction or .6)or 1);s.vx=s.vx*drag;s.vy=s.vy*drag
 if dx*dx+dy*dy>0 then local facing=s.kind=='skeleton'and s.lookYaw or math.deg(math.atan(dy,dx));s.entityYaw=P.turn(s.entityYaw,facing,.05)end
 P.body(s,actualX,actualY);s.blockedTicks=(dx*dx+dy*dy>0 and distance<.5)and(s.blockedTicks+1)or 0

 if s.blockedTicks>=30 then
  s.routeReplan=true;s.stuckRepath=true;s.blockedTicks=0
  if s.grounded then s.vz=.42;s.grounded=false;s.jump=true end
 end;s.simTicks=s.simTicks+1
end
function P.advance(s,now,move)
 local elapsed=math.max(0,now-(s.simAt or now));s.simAt=now;s.accumulator=(s.accumulator or 0)+elapsed;local count=0
 while s.accumulator+1e-9>=P.tick and count<P.maxCatchup do P.tickStep(s,move);s.accumulator=s.accumulator-P.tick;count=count+1 end
 if s.accumulator+1e-9>=P.tick then local dropped=math.floor((s.accumulator+1e-9)/P.tick)*P.tick;s.droppedSeconds=(s.droppedSeconds or 0)+dropped;s.accumulator=math.max(0,s.accumulator-dropped)end
 s.renderScratch=s.renderScratch or{p={}};return P.sample(s,clamp(s.accumulator/P.tick,0,1),s.renderScratch),count
end
function P.sample(s,t,out)
 local a=s.previous or s.p;local r=out or{p={}};local p=r.p
 p.X=lerp(a.X,s.p.X,t);p.Y=lerp(a.Y,s.p.Y,t);p.Z=lerp(a.Z,s.p.Z,t)
 r.yaw=(s.previousYaw or s.yaw)+angle(s.yaw-(s.previousYaw or s.yaw))*t
 r.headYaw=(s.previousHeadYaw or s.headYaw)+angle(s.headYaw-(s.previousHeadYaw or s.headYaw))*t
 r.walk=lerp(s.previousWalk or s.walk,s.walk,t);r.walkWeight=lerp(s.previousWeight or s.walkWeight,s.walkWeight,t);return r
end

function P.matrix(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 return{cy*cx,-sy,cy*sx,cz*sy*cx+sz*sx,cz*cy,cz*sy*sx-sz*cx,sz*sy*cx-cz*sx,sz*cy,sz*sy*sx+cz*cx}
end
function P.rotation(x,y,z,out)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 local pitch=math.asin(clamp(sz*sy*cx-cz*sx,-1,1));local yaw,roll
 if math.abs(math.cos(pitch))>1e-7 then yaw=math.atan(cz*sy*cx+sz*sx,cy*cx);roll=math.atan(-sz*cy,sz*sy*sx+cz*cx)else yaw=math.atan(sy,cz*cy);roll=0 end
 local r=out or{};r.Pitch=math.deg(pitch);r.Yaw=math.deg(yaw);r.Roll=math.deg(roll);return r
end
function P.angles(kind,part,s,now,headYaw,headPitch)
 local pi=math.pi;local x,y,z=0,0,0;local r=s.render or s;local phase=(r.walk or 0)*.6662;local w=r.walkWeight or 0;local side=part.side or 0
 local age=(now-(s.bornAt or now))*20;local idleZ=math.cos(age*.09)*.05+.05;local idleX=math.sin(age*.067)*.05
 if part.name=='head'then x=-math.rad(headPitch);y=math.rad(headYaw)
 elseif (kind=='zombie'or kind=='husk')and part.name:find('_arm',1,true)then
  local a=s.attackStart and clamp((now-s.attackStart)/.3,0,1)or 0;local swing=math.sin(pi*a);local ease=math.sin((1-(1-a)^2)*pi)
  x=-pi/(s.aggressive and 1.5 or 2.25)+1.2*swing-.4*ease+side*idleX;y=side*(-.1+.6*swing);z=side*idleZ
 elseif kind=='skeleton'and part.name:find('_arm',1,true)then
  if s.bowEquipped and(s.usingBow or s.aggressive)then x=-pi/2-math.rad(headPitch);y=math.rad(headYaw)+(side<0 and .1 or -.5)
  elseif not s.bowEquipped and s.aggressive then
   local a=s.attackStart and clamp((now-s.attackStart)/.3,0,1)or 0;local swing=math.sin(pi*a);local ease=math.sin((1-(1-a)^2)*pi)
   x=-pi/2-1.2*swing+.4*ease;y=side*(-.1+.6*swing)
  else x=math.cos(phase+(side>0 and pi or 0))*w end;x=x+side*idleX;z=side*idleZ
 elseif kind=='spider'and part.name:find('leg',1,true)==1 then
  local pair=tonumber(part.name:sub(4))%4;local offset=spiderOffsets[pair+1];local b=spiderBases[pair+1]
  local spread=pi/4*((pair==1 or pair==2)and .74 or 1);y=-side*(b+.4*math.cos(phase*2+offset)*w);z=-side*(spread-math.abs(.4*math.sin(phase+offset))*w)
 elseif part.name:find('_leg',1,true)then x=math.cos(phase+(side>0 and 0 or pi))*1.4*w
 elseif (kind=='wolf'or kind=='fox'or kind=='cat'or kind=='panda'or kind=='ocelot'or kind=='creeper'or kind=='mooshroom'or kind=='cow'or kind=='sheep'or kind=='pig'or kind=='chicken')and part.name:find('leg',1,true)==1 then x=-math.cos(phase)*1.4*w*side end
 if(kind=='horse'or kind=='camel')and part.name:find('leg',1,true)==1 then
  local leg=tonumber(part.name:sub(4));local gallop=kind=='horse'and(s.speed or 0)>500
  local offset=gallop and(leg<2 and 0 or math.pi)+(leg%2)*.32 or(side>0 and 0 or math.pi)
  x=math.cos(phase*(gallop and 1.5 or 1)+offset)*(gallop and 1.15 or .8)*w
 end
 if kind=='warden'then
  
  local f=(r.walk or 0)*.8662;local a=math.min(.5,3*w);local small=math.min(.35,a);local idle=age*.1
  if part.name=='head'then x=x+1.2*math.cos(f+pi*.5)*small+.06*math.cos(idle);z=.3*math.sin(f)*a+.06*math.sin(idle)
  elseif part.name=='body'then x=math.cos(f)*small+.025*math.sin(idle);z=.1*math.sin(f)*a+.025*math.cos(idle)
  elseif part.name=='left_leg'then x=math.cos(f)*a
  elseif part.name=='right_leg'then x=math.cos(f+pi)*a
  elseif part.name=='left_arm'then x=-.8*math.cos(f)*a
  elseif part.name=='right_arm'then x=-.8*math.sin(f)*a
  elseif part.name:find('tendril',1,true)then x=side*.1*math.cos(age*2.25)end
  local pose=s.wardenPoseC;local elapsed=pose and now-pose.at or 10
  if elapsed<1.6 then
   if pose.kind=='SLAM'and part.name:find('_arm',1,true)then
    x=elapsed<.45 and(-2.4*math.sin(elapsed/.45*pi*.5))or(-2.4+3.1*math.min(1,(elapsed-.45)/.22));if elapsed>.9 then x=x*(1-math.min(1,(elapsed-.9)/.5))end
   elseif pose.kind=='SONIC'then
    local strength=math.min(1,elapsed/.4)*math.max(0,math.min(1,(1.6-elapsed)/.4))
    if part.name:find('_arm',1,true)then x=-.7*strength;z=side*.8*strength
    elseif part.name=='head'then x=-.3*strength
    elseif part.name:find('ribcage',1,true)then y=side*.38*strength end
   end
  end
 end
 if kind=='enderman'and part.name:find('_arm',1,true)then
  x=math.max(-.4,math.min(.4,math.cos(phase+(side>0 and pi or 0))*w))
  local swing=s.attackStart and clamp((now-s.attackStart)/.5,0,1)or 1
  x=x-1.5*math.sin(swing*pi)
 end
 if kind=='enderman'and part.name:find('_leg',1,true)then x=math.max(-.4,math.min(.4,x))end
 if kind=='witch'and part.name=='arms'then x=s.aggressive and -1.2 or -.75 end
 if kind=='horse'and part.name=='tail'then x=.15*w;y=.15*math.sin(phase)*w end
 if kind=='camel'and part.name=='tail'then z=.12*math.sin(phase)*w end
 if kind=='rabbit'and part.name:find('leg',1,true)==1 then
  
  local jump=math.max(0,math.sin((r.walk or 0)*1.5))*w
  x=math.rad(side>0 and 50 or -40)*jump
 end
 if kind=='wolf'and part.name=='tail'then y=math.cos(phase)*1.4*w end
 if kind=='cat'and part.name=='tail2'then x=math.cos(phase)*.2*w end
 if kind=='irongolem'then
  local triangle=function(v,p)return(math.abs(v%p-p*.5)-p*.25)/(p*.25)end
  if part.name:find('_arm',1,true)then
   local elapsed=s.attackStart and now-s.attackStart or 10

   if s.aggressive and elapsed>=.5 then elapsed=elapsed%.5 end
   local remaining=10-elapsed*20
   x=remaining>0 and(-2+1.5*triangle(remaining,10))or(-.2+side*1.5*triangle(r.walk or 0,13))*w
  elseif part.name:find('_leg',1,true)then x=-side*1.5*triangle(r.walk or 0,13)*w end
 end
 if kind=='ocelot'and part.name=='tail2'then x=math.cos(phase)*.2*w end
 if kind=='parrot'then
  if part.name:find('_wing',1,true)then z=side*(.8+.7*math.sin(age*.8));x=.1*math.sin(age*.8)
  elseif part.name:find('_leg',1,true)then x=.55 end
 end
 if kind=='chicken'and part.name:find('wing',1,true)==1 then z=side*math.sin(age*.3)*w*.25 end
 return x,y,z
end
function P.pose(kind,part,s,now,headYaw,headPitch,out)local x,y,z=P.angles(kind,part,s,now,headYaw,headPitch);return P.rotation(x,y,z,out)end
function P.death(elapsed)return 90*math.min(1,math.sqrt(math.max(0,(elapsed*20-1)/20*1.6)))end
function P.hurt(elapsed)
 local remaining=math.max(0,10-elapsed*20)/10
 return -14*math.sin(remaining^4*math.pi)
end
function P.fuse(progress)
 local t=clamp(progress,0,1);local pulse=1+math.sin(t*100)*t*.01;local power=t^4
 return{X=(1+.4*power)*pulse,Y=(1+.4*power)*pulse,Z=(1+.1*power)/pulse},math.floor(t*10)%2==1
end
function P.bow(s)
 local draw=s.usingBow
 return{X=draw and 74 or 0,Y=draw and -23.75 or -31.25,Z=draw and 145 or 78},
  {Pitch=draw and -8 or 0,Yaw=0,Roll=-45}
end
function P.origin(s)
 local b=P.bow(s);local y=math.rad(s.yaw or 0)
 return{X=s.p.X+b.X*math.cos(y)-b.Y*math.sin(y),Y=s.p.Y+b.X*math.sin(y)+b.Y*math.cos(y),Z=s.p.Z+b.Z}
end
function P.arrowVelocity(from,target,difficulty,random)

 local dx,dy=target.X-from.X,target.Y-from.Y
 local dz=target.Z-from.Z+math.sqrt(dx*dx+dy*dy)*.2
 local n=math.max(.001,math.sqrt(dx*dx+dy*dy+dz*dz));local spread=.0172275*(14-4*(difficulty or 2))
 random=random or math.random
 return{X=(dx/n+(random()-random())*spread)*3200,Y=(dy/n+(random()-random())*spread)*3200,Z=(dz/n+(random()-random())*spread)*3200}
end
function P.ballistic(from,target,speed,gravity)
 local dx,dy,dz=target.X-from.X,target.Y-from.Y,target.Z-from.Z;local h=math.sqrt(dx*dx+dy*dy)
 if h<1 then return{X=0,Y=0,Z=speed}end
 local v2=speed*speed;local discriminant=v2*v2-gravity*(gravity*h*h+2*dz*v2)
 local pitch=discriminant>=0 and math.atan((v2-math.sqrt(discriminant))/(gravity*h))or math.atan(dz,h)
 local horizontal=math.cos(pitch)*speed
 return{X=dx/h*horizontal,Y=dy/h*horizontal,Z=math.sin(pitch)*speed}
end
return P
