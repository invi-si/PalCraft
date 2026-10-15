-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local T=dofile(ctx.base..'/timers.lua');local F={events={},teleports=0,dockRecoveries=0}
 local water=dofile(ctx.base..'/water86.lua')
 local function v(x,y,z)return{X=x,Y=y,Z=z}end
 local function copy(p)return v(p.X,p.Y,p.Z)end
 local function dist(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)end
 local color={R=0,G=0,B=0,A=0}
 function F:reset()
  self.identity=nil;self.anchor=nil;self.since=nil;self.pendingSummon=false;self.onOwned=false;self.lastReason=nil
 end
 function F:owned(component)
  if not ctx.valid(component)then return false end
  local a=component:GetOwner();return ctx.valid(a)and ctx.island:owned(a)
 end
 function F:dry(p)
  if p.Z<=-2095 then return false end
  local i=ctx.island;if i.at then i=i:at(p)end;if not i then return false end
  local d=i.data;local x=math.floor((p.X-d.origin.X)/100);local z=math.floor((d.origin.Y-p.Y)/100)
  local h=(d.water or water)[x..':'..z];return not h or p.Z>d.origin.Z+h*100+5
 end
 function F:ground(e,x,y,top,bottom,ignored)
  local h={};local ok=_G.MC_OUT_K('LineTraceSingle',ctx.UE.GetKismetSystemLibrary(),e.player,v(x,y,top),v(x,y,bottom),0,false,ignored,0,h,true,color,color,0)
  if not ok or h.ImpactNormal.Z<.65 or not self:owned(h.Component:Get())then return end
  local p=copy(h.ImpactPoint);if not self:dry(p)then return end;return p
 end
 function F:clear(e,p,radius,half,ignored)

  if ctx.cells then
   local cells=ctx.cells()
   for x=math.floor((p.X-radius)/100),math.floor((p.X+radius)/100)do
    for y=math.floor((p.Y-radius)/100),math.floor((p.Y+radius)/100)do
     for z=math.floor((p.Z-half+1)/100),math.floor((p.Z+half-1)/100)do
      if cells[ctx.key(x,y,z)]then return false end
     end
    end
   end
  end
  local hit={};return not _G.MC_OUT_K('CapsuleTraceSingle',ctx.UE.GetKismetSystemLibrary(),e.player,p,v(p.X,p.Y,p.Z+1),radius,half,0,false,ignored,0,hit,true,color,color,0)
 end
 function F:safe(e,a,p,foot)
  local cap=a.CapsuleComponent;local radius=cap:GetScaledCapsuleRadius();local half=cap:GetScaledCapsuleHalfHeight()
  local ignored={e.player,a};local range=math.max(230,radius+e.player.CapsuleComponent:GetScaledCapsuleRadius()+90)
  local fallback
  local lib=ctx.UE.Object('/Script/NavigationSystem.Default__NavigationSystemV1')
  for i=1,8 do
   local angle=(i-1)*math.pi/4;local x=p.X+math.cos(angle)*range;local y=p.Y+math.sin(angle)*range
   local q=self:ground(e,x,y,foot+100,foot-160,ignored)
   if q then
    local supported=true
    for _,o in ipairs({{radius*.75,0},{-radius*.75,0},{0,radius*.75},{0,-radius*.75}})do
     local edge=self:ground(e,x+o[1],y+o[2],q.Z+35,q.Z-35,ignored)
     if not edge or math.abs(edge.Z-q.Z)>25 then supported=false;break end
    end
    local goal=v(x,y,q.Z+half+5)
    if supported and self:clear(e,goal,radius,half,ignored)then
     fallback=fallback or goal

     local projected={}
     if _G.MC_OUT_K('K2_ProjectPointToNavigation',lib,e.player,q,projected,nil,nil,{X=50,Y=50,Z=100})and
        math.abs(projected.X-q.X)<40 and math.abs(projected.Y-q.Y)<40 and math.abs(projected.Z-q.Z)<60 then return goal end
    end
   end
  end
  return fallback
 end
 function F:reason(now,id,p,q)
  if self.identity~=id then self.identity=id;self.anchor=copy(q);self.since=now;self.pendingSummon=true
  elseif not self.anchor then self.anchor=copy(q);self.since=now end
  local distance=dist(p,q)
  if dist(q,self.anchor)>50 then self.anchor=copy(q);self.since=now end
  if now<(self.cooldown or 0)then return end
  if distance>2500 then return 'distance' end
  if distance>400 and now-self.since>=4 then return 'stuck' end
 end
 function F:receipt(reason,from,to,now)
  self.lastReason=reason;self.events[#self.events+1]={reason=reason,from=copy(from),to=copy(to),at=now}
  if #self.events>32 then table.remove(self.events,1)end
  ctx.log('MC86_TELEPORT reason='..reason..' from='..from.X..','..from.Y..','..from.Z..' to='..to.X..','..to.Y..','..to.Z)
 end
 function F:dock(e,p,now)
  local i=ctx.island;if i.at then i=i:at(p)end;if not i then return false end
  local d=i.data;local x=(p.X-d.dock.X)/100;local z=(d.dock.Y-p.Y)/100
  local half=e.player.CapsuleComponent:GetScaledCapsuleHalfHeight();local foot=p.Z-half
  if x< -4 or x>4 or z< -9 or z>9 or foot>=d.dock.Z-25 or foot<d.dock.Z-1800 then return false end
  local q=self:ground(e,d.dock.X,d.dock.Y,d.dock.Z+150,d.dock.Z-80,{e.player})
  if not q then return false end
  local goal=v(q.X,q.Y,q.Z+half+5)
  if not self:clear(e,goal,e.player.CapsuleComponent:GetScaledCapsuleRadius(),half,{e.player})then return false end
  e.player.CharacterMovement:StopMovementImmediately()
  if _G.MC_OUT_K('K2_SetActorLocation',e.player,goal,false,{},true)then
   e.player.CharacterMovement:SetMovementMode(1,0);self.dockRecoveries=self.dockRecoveries+1;self:receipt('dock',p,goal,now);return true
  end
 end
 function F:tick(now)
  
  if not ctx.ready()then self:reset();return end
  local e=ctx.environment();if not e or e.status~='alive'then self:reset();return end
  if ctx.UE.waystones83 and ctx.UE.waystones83.busy then self:reset();return end
  if ctx.UE.mount76 then ctx.UE.mount76:resolve(e);if ctx.UE.mount76.riding then self:reset();return end end
  local p=copy(e.player:K2_GetActorLocation())
  if self:dock(e,p,now)then p=copy(e.player:K2_GetActorLocation())end
  local holder=e.controller.BP_OtomoPalHolderComponent
  local a=ctx.valid(holder)and holder:TryGetSpawnedOtomo()or nil
  if not ctx.valid(a)or not a:GetActiveActorFlag()then self.identity=nil;self.onOwned=false;return end
  local half=e.player.CapsuleComponent:GetScaledCapsuleHalfHeight();local foot=p.Z-half
  local floor=self:ground(e,p.X,p.Y,foot+35,foot-120,{e.player})
  self.onOwned=floor~=nil
  if not floor then self.anchor=nil;self.since=nil;return end 
  local island=ctx.island:at(p)
  if island and island.probePathingB then self.anchor=nil;self.since=nil;return end
  if a:GetWorld():GetAddress()~=e.world:GetAddress()then self:reset();return end
  local param=a.CharacterParameterComponent
  if not ctx.valid(param)or param:IsDead()or param:IsInactiveOtomo()or not ctx.valid(a.CapsuleComponent)then self.identity=nil;return end
  if ctx.combat.controlled then self.anchor=nil;self.identity=nil;return end
  local q=copy(a:K2_GetActorLocation());local id=tostring(ctx.epoch())..':'..a:GetAddress()
  if island then
   local ai=a:GetController();local nav=ctx.valid(ai)and ai:IsOnNavMesh()
   if nav then
    local probe=self.nativeProbeB
    if not probe or probe.id~=id or probe.island~=island then probe={id=id,island=island,p=q,at=now,travel=0};self.nativeProbeB=probe end
    local delta=dist(q,probe.p);local velocity=a.CharacterMovement:GetVelocity();probe.p=q
    if delta<250 and velocity.X^2+velocity.Y^2>64 then probe.travel=probe.travel+delta end
    if probe.travel>=200 and not island.nativePathingB then island.nativePathingB=true;ctx.log('MCB_NATIVE_FOLLOW island='..(island.data.key or 'plains')..' cm='..probe.travel)end
   else self.nativeProbeB=nil end
  end
  local reason=self:reason(now,id,p,q);if not reason then return end
  local goal=self:safe(e,a,p,floor.Z);if not goal then return end
  a.CharacterMovement:StopMovementImmediately()
  if not _G.MC_OUT_K('K2_SetActorLocation',a,goal,false,{},true)then return end
  a.CharacterMovement:SetMovementMode(1,0);self.cooldown=now+3;self.anchor=copy(goal);self.since=now;self.pendingSummon=false;self.teleports=self.teleports+1
  if ctx.UE.effects66 then ctx.UE.effects66:emit(e,'death',goal)end
  self:receipt(reason,q,goal,now)
 end
 function F:status()return{teleports=self.teleports,dockRecoveries=self.dockRecoveries,onOwned=self.onOwned,reason=self.lastReason,events=self.events,intervalMs=500,cooldownSeconds=3,distanceThresholdCm=2500,stuckSeconds=4}end
 local function schedule()
  
  if F.handle then T.cancel(F.handle)end
  F:reset();F.nativeProbeB=nil;F.cooldown=0;F.handle=T.loop(500,function()F:tick(os.clock());return false end,'follow86')end
 T.onEpoch('follow86',schedule);schedule()
 return F
end
