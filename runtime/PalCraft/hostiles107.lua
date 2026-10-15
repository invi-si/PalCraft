-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx,costume)
 local UE,valid=ctx.UE,ctx.valid;local H={events={}}
 local function v(x,y,z)return{X=x,Y=y,Z=z}end
 function H:event(kind,s,extra)
  local d=extra or{};d.kind=kind;d.host=s.address;d.at=os.clock();self.events[#self.events+1]=d
  if #self.events>48 then table.remove(self.events,1)end
  ctx.log('MC107_'..kind..' host='..tostring(s.address))
 end
 function H:burst(e,p,kind)
  if UE.effects66 then UE.effects66:emit(e,kind or'explosion',p,ctx.types and ctx.types.purple_wool)end
 end
 function H:clear(s)
  s.teleport107=nil;s.teleportDue107=nil;s.split107=nil;s.headOpen107=nil;s.hop107=nil
  for _,c in ipairs(s.splitParts107 or{})do if valid(c)then c:SetVisibility(false,false)end end
 end
 function H:sample(s,e,now,hp,dead,capturing,p,attacking)
  if s.kind~='enderman'and s.kind~='slime'then return end
  if capturing then self:clear(s);return end
  if s.kind=='enderman'and dead then self:clear(s);return end
  if s.kind=='slime'and not dead and s.split107 then
   self:clear(s)
   for i=1,#s.models do s.parts[i]:SetVisibility(true,false)end
  end
  if s.kind=='enderman'and not dead then
   local hurt=s.lastHP and hp<s.lastHP
   local between=s.attackStart and now-s.attackStart>1.4 and now-s.attackStart<2.2 and not attacking
   if(hurt or between)and now>=(s.teleportDue107 or 0)then
    s.teleportDue107=now+4
    local k=UE.GetKismetSystemLibrary();local color={R=0,G=0,B=0,A=0}

    for i=1,4 do
     local angle=now*1.7+i*math.pi*.5;local q=v(p.X+math.cos(angle)*320,p.Y+math.sin(angle)*320,p.Z)
     local hit={};local half=s.capsule:GetScaledCapsuleHalfHeight()
     local ground=_G.MC_OUT_K('LineTraceSingle',k,e.player,v(q.X,q.Y,p.Z+120),v(q.X,q.Y,p.Z-half-160),0,false,{e.player,s.host},0,hit,true,color,color,0)
     if ground and hit.ImpactNormal.Z>.75 and math.abs(hit.ImpactPoint.Z-(p.Z-half))<100 then
      q.Z=hit.ImpactPoint.Z+half+3
      if s.host:K2_TeleportTo(q,s.host:K2_GetActorRotation())then
       s.host.CharacterMovement:StopMovementImmediately();s.teleport107={untilAt=now+.3,destination=q};s.lastMotionPosition=nil
       self:burst(e,p);self:event('ENDERMAN_TELEPORT',s,{before=v(p.X,p.Y,p.Z),after=q});break
      end
     end
    end
   end
  elseif s.kind=='slime'and dead and not s.deadAt then
   s.split107={at=now};s.splitParts107=s.splitParts107 or{}
   for i=1,2 do
    local c=s.splitParts107[i]
    if not valid(c)then
     local t={Rotation={X=0,Y=0,Z=0,W=1},Translation=v(0,0,0),Scale3D=v(1,1,1)}
     c=s.actor:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,t,false);s.splitParts107[i]=c
     c.ComponentTags={UE.FindOrAddFName('MC107Split')};c:SetMobility(2);c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false)
     assert(c:K2_AttachToComponent(s.root,UE.FindOrAddFName('None'),2,2,2,false))
     c:SetStaticMesh(costume:asset('/Game/MinecraftHostiles107/SM_slime_child.SM_slime_child'))
    end
    c:SetVisibility(true,false)
   end
   self:burst(e,p,'death');self:event('SLIME_SPLIT',s,{children=2,visualOnly=true,duration=2})
  end
 end
 function H:animate(s,e,now)
  if s.kind=='enderman'then
   local t=s.teleport107
   if t then
    s.actor:SetActorHiddenInGame(now<t.untilAt or s.capturing)
    if now>=t.untilAt then self:burst(e,t.destination);s.teleport107=nil end
   end
   local open=s.aggressive or now<(s.panicUntil or 0)
   if not s.x4 and open~=s.headOpen107 then
    for i,d in ipairs(s.models)do if d.name=='head'then _G.MC_OUT_K('K2_SetRelativeLocation',s.parts[i],v(d.location.X,d.location.Y,d.location.Z+(open and 18 or 0)),false,ignoredHitJ(),true)end end
    s.headOpen107=open
   end
  elseif s.kind=='slime'then
   local split=s.split107
   if split then
    local age=now-split.at
    for _,c in ipairs(s.parts)do c:SetVisibility(false,false)end
    
    for i,c in ipairs(s.splitParts107)do
     c:SetVisibility(age<2,false)
     if age<2 then
      local size=age<1 and .5 or .25;c:SetRelativeScale3D(v(size,size,size))
      _G.MC_OUT_K('K2_SetRelativeLocation',c,v(0,(i==1 and -1 or 1)*(55+age*55),math.abs(math.sin(age*7))*45),false,ignoredHitJ(),true)
     end
    end
   elseif not s.x4 and not s.deadAt and not s.capturing then
    local hop=math.max(0,math.sin((now-s.bornAt)*5));local squash=1+.18*math.cos((now-s.bornAt)*10)
    local b=s.scale or v(1,1,1);s.root:SetRelativeScale3D(v(b.X*squash,b.Y*squash,b.Z/squash))
    _G.MC_OUT_K('K2_SetRelativeLocation',s.root,v(0,0,-s.capsule:GetUnscaledCapsuleHalfHeight()+hop*38/math.max(.01,math.abs(s.host:GetActorScale3D().Z))),false,ignoredHitJ(),true)
    s.hop107={bob=hop*38,squash=squash}
   end
  end
 end
 return H
end
