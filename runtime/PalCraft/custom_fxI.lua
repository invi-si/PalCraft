-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
 local F={pending={},pool={},events={}};local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local function v(x,y,z)return{X=x,Y=y,Z=z}end
 local function live(a,e)
  if not valid(a)or not valid(a.CharacterParameterComponent)then return false end
  local w=a:GetWorld();local cp=a.CharacterParameterComponent
  return valid(w)and w:GetAddress()==e.world:GetAddress()and a:GetActiveActorFlag()and not a.bHidden and not cp:IsDead()and not cp:GetIsCapturedProcessing()
 end
 function F:queue(a,at,native)
  if #self.pending>=8 then return end
  self.pending[#self.pending+1]={actor=a,at=at or os.clock(),epoch=T.epoch,native=native}
 end
 function F:install()
  if self.installed then return end
  self.installed=true;ctx.log('MCI_SPORE_READY shared_action_selection=true extra_hooks=0')
 end
 function F:burst(a,e,now)
  local slot
  for _,s in ipairs(self.pool)do if not s.active then slot=s;break end end
  if not slot then if #self.pool>=3 then return end;slot={};self.pool[#self.pool+1]=slot end
  if not valid(slot.actor)then
   local tf={Rotation={X=0,Y=0,Z=0,W=1},Translation=v(0,0,0),Scale3D=v(1,1,1)};local g=UE.Object('/Script/Engine.Default__GameplayStatics')
   local actor=g:BeginDeferredActorSpawnFromClass(e.world,UE.Object('/Script/Engine.Actor'),tf,1,nil);actor=g:FinishSpawningActor(actor,tf);actor:SetActorEnableCollision(false)
   actor:AddComponentByClass(UE.Object('/Script/Engine.SceneComponent'),false,tf,false)
   local c=actor:AddComponentByClass(UE.Object('/Script/Engine.InstancedStaticMeshComponent'),false,tf,false)
   c:SetMobility(2);c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false);c:SetCastShadow(false)
   local mesh=UE.zombie77:asset('/Game/MinecraftBlocks/SM_MC_LimeWool.SM_MC_LimeWool');c:SetStaticMesh(mesh);c:SetMaterial(0,mesh:GetMaterial(0))
   slot.materialPath=mesh:GetMaterial(0):GetFullName()
   for i=1,36 do c:AddInstance(tf,false)end
   slot.actor=actor;slot.cubes=c
  end
  local p=a.Mesh:GetSocketLocation(UE.FindOrAddFName('head'));p={X=p.X,Y=p.Y,Z=p.Z+45}
  _G.MC_OUT_K('K2_SetActorLocation',slot.actor,p,false,ignoredHitJ(),true);slot.actor:SetActorHiddenInGame(false)
  slot.active=true;slot.started=now;slot.owner=a;slot.epoch=T.epoch
  self.events[#self.events+1]={actor=a:GetAddress(),at=now,cubes=36,origin=p,kind='SPORE_BURST',material=slot.materialPath,materialSource='particles73 lime_wool',tint='lime'}
  if #self.events>32 then table.remove(self.events,1)end
  ctx.log('MCI_SPORE_BURST cubes=36 actor='..a:GetAddress())
 end
 function F:tick(e,now)
  local pending={}
  for _,p in ipairs(self.pending)do if p.epoch==T.epoch then
   local a=p.actor or(valid(p.action)and p.action:GetActionCharacter())
   if live(a,e)then
    if now-p.at>=.4 then
     local selected=true
     if p.native then local ac=a:GetActionComponent();local action=valid(ac)and ac:GetCurrentAction();selected=valid(action)and action:GetClass():GetFullName():find('BP_Action_A_FungalHost_C',1,true)~=nil end
     if now-p.at<1 and selected then self:burst(a,e,now)end
    else p.actor=a;p.action=nil;pending[#pending+1]=p end
   end
  end end
  self.pending=pending
  for _,s in ipairs(self.pool)do if s.active then
   local t=now-s.started
   if s.epoch~=T.epoch or t>=1.25 or not live(s.owner,e)then
    if valid(s.actor)then s.actor:SetActorHiddenInGame(true)end;s.active=false;s.owner=nil
   else
    for i=1,36 do
     local angle=i*2.399963;local radius=(25+90*t)*math.sqrt(i/36);local size=(.085+.025*(i%3))*math.max(.05,1-t/1.25)
     local tf={Rotation={X=0,Y=0,Z=0,W=1},Translation=v(math.cos(angle)*radius,math.sin(angle)*radius,12*math.sin(i*1.7)+70*t-22*t*t),Scale3D=v(size,size,size)}
     s.cubes:UpdateInstanceTransform(i-1,tf,false,i==36,true)
    end
   end
  end end
 end
 T.onEpoch('custom-fxI',function()
  F.pending={};for _,s in ipairs(F.pool)do if valid(s.actor)then s.actor:SetActorHiddenInGame(true)end end;F.pool={}
 end)
 return F
end
