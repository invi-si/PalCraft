-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local M={}
local pi=math.pi
function M.wrap(a)return(a+180)%360-180 end

function M.facingStep(previous,camera,vx,vy,attacking)
 local speed=math.sqrt(vx*vx+vy*vy);local target=previous or camera;local backwards=false
 if speed>100 then
  target=math.deg(math.atan(vy,vx));local d=math.abs(M.wrap(camera-target))
  if d>95 and d<265 then target=target+180;backwards=true end
 end
 if attacking then target=camera end
 local body=(previous or camera)+M.wrap(target-(previous or camera))*.3
 local offset=M.wrap(camera-body);body=camera-math.max(-75,math.min(75,offset))
 return M.wrap(body),backwards
end
function M.mul(a,b)return{X=a.W*b.X+a.X*b.W+a.Y*b.Z-a.Z*b.Y,Y=a.W*b.Y-a.X*b.Z+a.Y*b.W+a.Z*b.X,Z=a.W*b.Z+a.X*b.Y-a.Y*b.X+a.Z*b.W,W=a.W*b.W-a.X*b.X-a.Y*b.Y-a.Z*b.Z}end
function M.inv(q)return{X=-q.X,Y=-q.Y,Z=-q.Z,W=q.W}end
function M.axis(x,y,z,a)local s=math.sin(a/2);return{X=x*s,Y=y*s,Z=z*s,W=math.cos(a/2)}end

function M.euler(x,y,z)return M.mul(M.axis(0,1,0,z or 0),M.mul(M.axis(0,0,1,y or 0),M.axis(1,0,0,-(x or 0))))end
function M.rotate(q,v)
 
 local x,y,z,w=q.X,q.Y,q.Z,q.W;local xx,yy,zz,ww=x*x,y*y,z*z,w*w
 return{X=(ww+xx-yy-zz)*v.X+2*(x*y-w*z)*v.Y+2*(x*z+w*y)*v.Z,
  Y=2*(x*y+w*z)*v.X+(ww-xx+yy-zz)*v.Y+2*(y*z-w*x)*v.Z,
  Z=2*(x*z-w*y)*v.X+2*(y*z+w*x)*v.Y+(ww-xx-yy+zz)*v.Z}
end
function M.add(a,b)return{X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z}end
function M.sub(a,b)return{X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z}end
function M.down(v)
 local len=math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z);local x,y,z=v.X/len,v.Y/len,v.Z/len
 local q={X=-y,Y=x,Z=0,W=1-z};local n=math.sqrt(q.X*q.X+q.Y*q.Y+q.W*q.W)
 if n<.00001 then return M.axis(1,0,0,pi)end;return{X=q.X/n,Y=q.Y/n,Z=0,W=q.W/n}
end
function M.blend(a,b,t)
 local dot=a.X*b.X+a.Y*b.Y+a.Z*b.Z+a.W*b.W;local s=dot<0 and-1 or 1
 local q={X=a.X+(b.X*s-a.X)*t,Y=a.Y+(b.Y*s-a.Y)*t,Z=a.Z+(b.Z*s-a.Z)*t,W=a.W+(b.W*s-a.W)*t};local n=math.sqrt(q.X*q.X+q.Y*q.Y+q.Z*q.Z+q.W*q.W)
 q.X=q.X/n;q.Y=q.Y/n;q.Z=q.Z/n;q.W=q.W/n;return q
end
function M.pose(v)
 local walk,amount,age=v.limb or 0,v.amount or 0,v.age or 0
 local p={body={x=0,y=0,z=0},head={x=v.pitch or 0,y=v.yaw or 0,z=0},rarm={x=math.cos(walk*.6662+pi)*amount,y=0,z=0},larm={x=math.cos(walk*.6662)*amount,y=0,z=0},rleg={x=math.cos(walk*.6662)*1.4*amount,y=0,z=0},lleg={x=math.cos(walk*.6662+pi)*1.4*amount,y=0,z=0},crouch=v.crouch==true}
 if v.riding then p.rarm.x=-pi/5;p.larm.x=-pi/5 end
 if v.held then p.rarm.x=p.rarm.x*.5-pi/10 end
 if v.crouch then p.body.x=.5;p.rarm.x=p.rarm.x+.4;p.larm.x=p.larm.x+.4 end
 local swing=v.swing or 0
 if swing>0 then
  p.body.y=math.sin(math.sqrt(swing)*2*pi)*.2;p.rarm.y=p.rarm.y+p.body.y;p.larm.y=p.larm.y+p.body.y;p.larm.x=p.larm.x+p.body.y
  local wave=math.sin((1-(1-swing)^4)*pi);local look=math.sin(swing*pi)*-(p.head.x-.7)*.75
  p.rarm.x=p.rarm.x-wave*1.2-look;p.rarm.y=p.rarm.y+p.body.y*2;p.rarm.z=p.rarm.z-math.sin(swing*pi)*.4
 end
 if v.use=='bow'then
  p.rarm.y=-.1+p.head.y;p.larm.y=.1+p.head.y+.4;p.rarm.x=-pi/2+p.head.x;p.larm.x=-pi/2+p.head.x
 elseif v.use=='eat'then
  p.rarm.x=-1.3+.12*math.abs(math.sin(age*1.8));p.rarm.y=-.35;p.rarm.z=.2
 elseif v.use=='use'then p.rarm.x=-1.2;p.rarm.y=-.2 end
 p.rarm.z=p.rarm.z+math.cos(age*.09)*.05+.05;p.larm.z=p.larm.z-math.cos(age*.09)*.05-.05
 p.rarm.x=p.rarm.x+math.sin(age*.067)*.05;p.larm.x=p.larm.x-math.sin(age*.067)*.05
 
 if v.riding then
  p.body={x=0,y=0,z=0};p.crouch=false
  p.rleg={x=-1.4137167,y=pi/10,z=.07853982};p.lleg={x=-1.4137167,y=-pi/10,z=-.07853982}
 elseif v.falling then
  p.body={x=0,y=0,z=0};p.crouch=false
  p.rarm={x=-.55,y=0,z=.35};p.larm={x=-.55,y=0,z=-.35}
  p.rleg={x=.08,y=0,z=.04};p.lleg={x=-.08,y=0,z=-.04}
 elseif v.swimming or(v.swimAmount or 0)>0 then
  
  local cycle=walk%26;local z,x
  if cycle<14 then z=pi+1.8707964*(cycle*cycle-65*cycle)/(196-910);x=0
  elseif cycle<22 then local t=(cycle-14)/8;z=5.012389-1.8707964*t;x=pi/2*t
  else z=pi;x=pi/2*(1-(cycle-22)/4)end
  local a=v.swimAmount or 1
  local function lerpAngle(from,to)return from+((to-from+pi)%(2*pi)-pi)*a end
  local function blendArm(old,target)return{x=lerpAngle(old.x,target.x),y=lerpAngle(old.y,target.y),z=lerpAngle(old.z,target.z)}end
  p.body={x=(pi/2-(v.swimPitch or 0))*a,y=0,z=0};p.head.x=lerpAngle(p.head.x,-pi/4);p.crouch=false;p.wholeBody=true
  if swing<=0 and not v.use then p.rarm=blendArm(p.rarm,{x=x,y=pi,z=2*pi-z})end
  if v.use~='bow'then p.larm=blendArm(p.larm,{x=x,y=pi,z=z})end
  p.rleg={x=p.rleg.x+(.3*math.cos(walk/3)-p.rleg.x)*a,y=0,z=0};p.lleg={x=p.lleg.x+(.3*math.cos(walk/3+pi)-p.lleg.x)*a,y=0,z=0}
 elseif v.climbing then
  p.body={x=.15,y=0,z=0};p.head={x=-.15,y=v.yaw or 0,z=0};p.wholeBody=true;p.crouch=false
  p.rarm={x=-2.6+.25*math.sin(age*.35),y=0,z=.12};p.larm={x=-2.6-.25*math.sin(age*.35),y=0,z=-.12}
  p.rleg={x=-.25+.3*math.sin(age*.35),y=0,z=.06};p.lleg={x=-.25-.3*math.sin(age*.35),y=0,z=-.06}
 elseif v.gliding and v.elytra then
  p.body={x=math.pi/2-.12,y=0,z=0};p.head={x=-math.pi/4,y=v.yaw or 0,z=0};p.wholeBody=true;p.crouch=false
  p.rarm={x=.18,y=0,z=.12};p.larm={x=.18,y=0,z=-.12}
  p.rleg={x=0,y=0,z=.03};p.lleg={x=0,y=0,z=-.03}
 elseif v.gliding then
  
  p.body={x=.2,y=0,z=0};p.head={x=-.2,y=v.yaw or 0,z=0};p.wholeBody=true;p.crouch=false
  p.rarm={x=-2.7,y=0,z=.25};p.larm={x=-2.7,y=0,z=-.25}
  p.rleg={x=.15,y=0,z=.05};p.lleg={x=.15,y=0,z=-.05}
 end
 return p
end
return M
