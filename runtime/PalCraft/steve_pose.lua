-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local T=dofile(ctx.base..'/timers.lua')
 local H66=dofile(ctx.base..'/hand_motion66.lua')
 local M=dofile(ctx.base..'/steve_motion.lua');local N=dofile(ctx.base..'/steve_native_rest.lua');local P={limb=0,amount=0,age=0}
 M=dofile(ctx.base..'/steve_math_scratch.lua')(M)
 local unitScale={X=1,Y=1,Z=1}
 local names={'root','pelvis','spine_01','spine_02','spine_03','neck_01','head','upperarm_r','lowerarm_r','hand_r','upperarm_l','lowerarm_l','hand_l','thigh_r','foot_r','thigh_l','foot_l'}
 local function copy(t)return{Rotation={X=t.Rotation.X,Y=t.Rotation.Y,Z=t.Rotation.Z,W=t.Rotation.W},Translation={X=t.Translation.X,Y=t.Translation.Y,Z=t.Translation.Z},Scale3D={X=1,Y=1,Z=1}}end
 function P:bind(mesh)
  self.rest={};self.previous={};self.desired={};self.fnames={};self.inputKeys61={};for _,n in ipairs({'LeftMouseButton','RightMouseButton','Q'})do self.inputKeys61[n]={KeyName=ctx.UE.FindOrAddFName(n)}end
  for _,n in ipairs(names)do local f=ctx.UE.FindOrAddFName(n);self.fnames[n]=f;self.rest[n]=copy(mesh:GetBoneTransformByName(f,1))end
  self.armDown={};for _,s in ipairs({'r','l'})do self.armDown[s]=M.down(M.sub(self.rest['hand_'..s].Translation,self.rest['upperarm_'..s].Translation))end
  self.mesh=mesh;self.last=os.clock();self.mode=nil;self.limb=0;self.amount=0;self.snapshot=nil;self.bodyYaw=nil;self.lastRootYaw=nil;self.turnTime=0;self.turnNow=nil;self.turnOld=nil;self.swimAmount=0;self.lmb66=false;self.nextSwing66=0;self.hand66=nil
 end
 function P:tick(env,S,weapon)
  if T.test54 and T.test54.steve==false then return end
  local mesh=S.mesh;if self.mesh~=mesh or not self.rest then self:bind(mesh)end
  local now=os.clock();local dt=math.min(.1,math.max(0,now-self.last));self.last=now;self.age=self.age+dt*20
  if env.controller.bShowMouseCursor then return end
  M.beginFrame()
  local vel=env.player.CharacterMovement.Velocity;local speed=math.sqrt(vel.X*vel.X+vel.Y*vel.Y);self.amount=self.amount+(math.min(1,speed/500)-self.amount)*(1-.6^(dt*20));self.limb=self.limb+self.amount*dt*20
  local lmb,rmb,q=env.controller:IsInputKeyDown(self.inputKeys61.LeftMouseButton),env.controller:IsInputKeyDown(self.inputKeys61.RightMouseButton),env.controller:IsInputKeyDown(self.inputKeys61.Q);local mode=env.player.CharacterMovement.MovementMode;local custom=env.player.CharacterMovement.CustomMovementMode
  ctx.UE.rightDown68=rmb
  local id=ctx.valid(weapon)and weapon:GetItemId().StaticId:ToString()or'';local bow=id:lower():find('bow',1,true)~=nil
  if lmb and not self.lmb66 and not bow and now>=(self.nextSwing66 or 0)then self.attackAt=now;self.nextSwing66=now+H66.cooldown(id);if id:sub(1,3)=='MC_'then ctx.UE.attack66={at=now,period=H66.cooldown(id)}end end
  self.lmb66=lmb
  local swing=self.attackAt and(now-self.attackAt)/.3 or 0;if swing>=1 then swing=0 end
  local rotation=env.controller:GetControlRotation();local actor=env.player:K2_GetActorRotation();local riding=env.controller:IsRiding()
  if ctx.UE.mount76 then ctx.UE.mount76:observe(riding)end
  self.turnNow=self.turnNow or rotation.Yaw;self.turnOld=self.turnOld or self.turnNow;self.turnTime=self.turnTime+dt
  while self.turnTime>=.05 do
   self.turnTime=self.turnTime-.05;self.turnOld=self.turnNow
   self.turnNow,self.backwards=M.facingStep(self.turnNow,rotation.Yaw,vel.X,vel.Y,swing>0)
  end
  self.bodyYaw=self.turnOld+M.wrap(self.turnNow-self.turnOld)*(self.turnTime/.05)
  self.bodyYaw=rotation.Yaw-math.max(-75,math.min(75,M.wrap(rotation.Yaw-self.bodyYaw)))
  if riding then self.bodyYaw=actor.Yaw;self.turnNow=actor.Yaw;self.turnOld=actor.Yaw;self.turnTime=0 end
  local backwards=self.backwards
  self.swimAmount=math.max(0,math.min(1,self.swimAmount+(mode==4 and 1 or-1)*dt*1.8))
  local yaw=math.max(-75,math.min(75,M.wrap(rotation.Yaw-self.bodyYaw)))

  local rootYaw=M.wrap(self.bodyYaw-(mesh:K2_GetComponentRotation().Yaw+90))
  local selected=ctx.items:hotbar(env,ctx.phaseA.selected)
  local fp66=S.firstPerson and S.held66:supports(selected.id)
  if fp66 then rootYaw=0 end
  local rootTurn=M.axis(0,0,1,math.rad(rootYaw))
  local crouch=env.player.bIsCrouched;local sprint=env.player.CharacterMovement:IsSprint();local use=bow and(lmb or rmb)and'bow'or(rmb and'use'or nil)
  if S.foodId and rmb then use='eat'end
  local climbing=env.player.CharacterMovement:IsClimbing()
  if self.qDown and not q then self.throwUntil=now+.65 end;self.qDown=q
  local throwing=q or(self.throwUntil and now<self.throwUntil)
  local fallback=throwing
  local glider=env.player:GetPropertyValue('BP_GliderComponent');if ctx.valid(glider)and glider:IsGliding()then fallback=false;mode=7 end
  if riding then fallback=false end
  local falling=not fallback and not riding and mode==3 and vel.Z < -100
  local pose=M.pose({limb=self.limb,amount=self.amount*(backwards and-1 or 1),age=self.age,pitch=-math.rad(M.wrap(rotation.Pitch)),yaw=math.rad(yaw),swimAmount=self.swimAmount,swimPitch=math.atan(vel.Z,math.max(1,speed)),crouch=crouch,swing=swing,use=use,held=id~=''or ctx.valid(ctx.phaseC:handVisual()),falling=falling,riding=riding,swimming=mode==4,climbing=climbing,gliding=mode==7,elytra=ctx.UE.elytra104 and ctx.UE.elytra104.equipped})
  if fp66 then pose.body={x=0,y=0,z=0};pose.head={x=0,y=0,z=0};pose.rarm={x=-math.pi/2,y=0,z=0};pose.larm={x=-math.pi/2,y=0,z=0};pose.wholeBody=false;pose.crouch=false;crouch=false end
  local label=riding and'ride'or(mode==4 and'swim'or(climbing and'climb'or(mode==7 and'glide'or(falling and'fall'or(fallback and'throw'or(use or(swing>0 and'swing'or(crouch and'sneak'or(mode==3 and'jump'or(sprint and'run'or(speed>10 and'walk'or'idle')))))))))))
  if label~=self.mode then self.mode=label;ctx.log('MC52_STEVE_MODE '..label..' rigid=true');end
  local nativeAngles
  if fallback then nativeAngles={};for _,n in ipairs({'spine_03','head','upperarm_r','upperarm_l','thigh_r','thigh_l'})do local t=env.player.Mesh:GetSocketTransform(self.fnames[n],1);local r=t.Rotation;nativeAngles[n]=M.mul({X=r.X,Y=r.Y,Z=r.Z,W=r.W},M.inv(N[n]))end end
  local desired=self.desired;local pelvis=self.rest.pelvis.Translation;local body=nativeAngles and nativeAngles.spine_03 or M.euler(pose.body.x,pose.body.y,0)
  local function put(n,q,p)local r=self.rest[n];local t=desired[n]or{};desired[n]=t;t.Rotation=M.mul(q,r.Rotation);t.Translation=p or r.Translation;t.Scale3D=unitScale end
  for _,n in ipairs({'root','pelvis','spine_01','spine_02','spine_03','neck_01'})do local p=M.add(pelvis,M.rotate(body,M.sub(self.rest[n].Translation,pelvis)));if crouch then p.Z=p.Z-12 end;put(n,body,p)end
  local head=M.add(pelvis,M.rotate(body,M.sub(self.rest.head.Translation,pelvis)));if crouch then head.Z=head.Z-12 end;local hq=M.euler(pose.head.x,pose.head.y,0);if pose.wholeBody then hq=M.mul(body,hq)end;put('head',nativeAngles and nativeAngles.head or hq,head)
  for _,side in ipairs({'r','l'})do
   local arm=pose[side..'arm'];local leg=pose[side..'leg'];local shoulder=self.rest['upperarm_'..side].Translation
   local base=M.add(pelvis,M.rotate(body,M.sub(shoulder,pelvis)));if crouch then base.Z=base.Z-12 end
   local aq=M.mul(M.euler(arm.x,arm.y,arm.z),self.armDown[side]);local lq=M.euler(leg.x,leg.y,leg.z)
   if pose.wholeBody then aq=M.mul(body,aq);lq=M.mul(body,lq)end
   if nativeAngles then aq=nativeAngles['upperarm_'..side];lq=nativeAngles['thigh_'..side]end
   for _,n in ipairs({'upperarm_'..side,'lowerarm_'..side,'hand_'..side})do put(n,aq,M.add(base,M.rotate(aq,M.sub(self.rest[n].Translation,shoulder))))end
   local hip=self.rest['thigh_'..side].Translation;local baseHip=(nativeAngles or pose.wholeBody)and M.add(pelvis,M.rotate(body,M.sub(hip,pelvis)))or hip;for _,n in ipairs({'thigh_'..side,'foot_'..side})do local p=M.add(baseHip,M.rotate(lq,M.sub(self.rest[n].Translation,hip)));if crouch then p.Y=p.Y-10;p.Z=p.Z-12 end;put(n,lq,p)end
  end
  local seatOffset=riding and M.sub(env.player.Mesh:GetSocketTransform(self.fnames.pelvis,1).Translation,pelvis)or nil
  local blend=fp66 and 1 or math.min(1,dt*15)
  for _,n in ipairs(names)do local t=desired[n];local old=self.previous[n]
   if old and n~='head'then t.Rotation=M.blend(old.Rotation,t.Rotation,blend);t.Translation={X=old.Translation.X+(t.Translation.X-old.Translation.X)*blend,Y=old.Translation.Y+(t.Translation.Y-old.Translation.Y)*blend,Z=old.Translation.Z+(t.Translation.Z-old.Translation.Z)*blend}end
   local delta=not old and math.huge or math.abs(old.Rotation.X-t.Rotation.X)+math.abs(old.Rotation.Y-t.Rotation.Y)+math.abs(old.Rotation.Z-t.Rotation.Z)+math.abs(old.Rotation.W-t.Rotation.W)+.01*(math.abs(old.Translation.X-t.Translation.X)+math.abs(old.Translation.Y-t.Translation.Y)+math.abs(old.Translation.Z-t.Translation.Z))
   if delta>.0002 or self.lastRootYaw~=rootYaw or riding or self.wasRiding then
    local rendered={Rotation=M.mul(rootTurn,t.Rotation),Translation=M.add(pelvis,M.rotate(rootTurn,M.sub(t.Translation,pelvis))),Scale3D=t.Scale3D}
    if seatOffset then rendered.Translation=M.add(rendered.Translation,seatOffset)end
    mesh:SetBoneTransformByName(self.fnames[n],rendered,1)
    if n=='hand_r'then self.hand66=rendered end
    local previous=old or{Rotation={},Translation={}};local r,p=previous.Rotation,previous.Translation
    r.X=t.Rotation.X;r.Y=t.Rotation.Y;r.Z=t.Rotation.Z;r.W=t.Rotation.W
    p.X=t.Translation.X;p.Y=t.Translation.Y;p.Z=t.Translation.Z
    previous.Scale3D=unitScale;self.previous[n]=previous
   end
  end
  self.lastRootYaw=rootYaw;self.wasRiding=riding
  self.snapshot={seatOffset=seatOffset,mode=label,cameraYaw=rotation.Yaw,bodyYaw=self.bodyYaw,headYaw=rotation.Yaw,headRelativeYaw=yaw,componentCorrection=rootYaw,backwards=backwards,velocity={X=vel.X,Y=vel.Y,Z=vel.Z},speed=speed,verticalSpeed=vel.Z,limb=self.limb,amount=self.amount,swing=swing,crouch=crouch,use=use,native=fallback,climbing=climbing,riding=riding,falling=falling,gliding=mode==7,weapon=id,keys={attack=lmb,use=rmb,throw=q},bones=self.previous}
  M.endFrame()
 end
 return P
end
