-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,costume)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local P={pending={},rows={},events={}}
 for _,kind in ipairs({'BowAndArrow','Arrow'})do
  local effectKind=kind
  NotifyOnNewObject('/Game/Pal/Blueprint/Skill/RobinHood_Snipe/BP_SkillEffect_Unique_RobinHood_Snipe_'..kind..'.BP_SkillEffect_Unique_RobinHood_Snipe_'..kind..'_C',function(object)
   if #P.pending<64 then P.pending[#P.pending+1]={actor=object,kind=effectKind,epoch=T.epoch}end
  end)
 end
 local function unwrap(v)local ok,o=pcall(function()return v:get()end);return ok and o or v end
 function P:tick(e)
  local pending=self.pending;self.pending={}
  for _,row in ipairs(pending)do
   if row.epoch==T.epoch and valid(row.actor)and row.actor:GetClass():GetFullName():find('BP_SkillEffect_Unique_RobinHood_Snipe_'..row.kind..'_C',1,true)then
    row.identityZ1=row.actor:GetFullName();row.classZ1=row.actor:GetClass():GetAddress()
    local world=row.actor:GetWorld()
    if valid(world)and world:GetAddress()==e.world:GetAddress()then
     local count=0;for _ in pairs(self.rows)do count=count+1 end
     if count<16 or self.rows[row.actor:GetAddress()]then self.rows[row.actor:GetAddress()]=row end
    end
   end
  end
  for address,row in pairs(self.rows)do
   local a=row.actor
   if not valid(a)or row.epoch~=T.epoch or a:GetFullName()~=row.identityZ1 or a:GetClass():GetAddress()~=row.classZ1 then
    if row.wasActive and row.witch and row.lastPosition then costume.hostiles107:burst(e,row.lastPosition);P.events[#P.events+1]={kind='splash',at=os.clock()}end
    self.rows[address]=nil else

    local resolved,owner=pcall(function()return a:GetOwnerCharacter()end)
    if not resolved then self.rows[address]=nil;ctx.log('MCZ1_PROJECTILE_RETIRED stale_owner_wrapper=true');owner=nil end
    local ours=false;local witch=false
    if valid(owner)and valid(owner.CharacterParameterComponent)then
     local ip=owner.CharacterParameterComponent:GetIndividualParameter()
     local id=valid(ip)and ip:GetCharacterID():ToString();witch=id=='MC_Witch';ours=id=='MC_Skeleton'or witch
    end
    if ours and not row.meshes then
     row.meshes={}
     for _,class in ipairs({'/Script/Engine.SkeletalMeshComponent','/Script/Niagara.NiagaraComponent'})do
      for _,v in ipairs(a:K2_GetComponentsByClass(UE.Object(class)))do
       local c=unwrap(v);if valid(c)then row.meshes[#row.meshes+1]={component=c,visible=c:IsVisible()}end
      end
     end
     if row.kind=='Arrow'then
      for _,v in ipairs(a:K2_GetComponentsByClass(UE.Object('/Script/Engine.StaticMeshComponent')))do
       local c=unwrap(v);if valid(c)and c:ComponentHasTag(UE.FindOrAddFName('MC91Arrow'))then row.arrow=c;break end
      end
      if not valid(row.arrow)then
       local tf={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
       local c=a:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,tf,false);row.arrow=c
       c.ComponentTags={UE.FindOrAddFName('MC91Arrow')};c:SetMobility(2);c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false)
       assert(c:K2_AttachToComponent(a.RootComponent,UE.FindOrAddFName('None'),2,2,2,false))
       c:SetStaticMesh(costume:asset(witch and'/Game/MinecraftHostiles107/SM_potion_body.SM_potion_body'or'/Game/MinecraftMobs/Task45/SM_arrow_shaft.SM_arrow_shaft'));row.witch=witch
      end
     end
    end
    if valid(row.arrow)and ours and row.witch~=witch then row.arrow:SetStaticMesh(costume:asset(witch and'/Game/MinecraftHostiles107/SM_potion_body.SM_potion_body'or'/Game/MinecraftMobs/Task45/SM_arrow_shaft.SM_arrow_shaft'));row.witch=witch end
    if row.meshes then
     for _,v in ipairs(row.meshes)do if valid(v.component)then
      if ours and v.component:IsVisible()then v.component:SetVisibility(false,false)
      elseif not ours and row.ours then v.component:SetVisibility(v.visible,false)end
     end end
     if valid(row.arrow)then row.arrow:SetVisibility(ours and not a.bHidden and not a.bIsInactiveInObjectPool,false)end
    end
    local active=ours and not a.bHidden and not a.bIsInactiveInObjectPool
    if (witch or row.witch)and row.kind=='Arrow'then
     if active then
      local p=a:K2_GetActorLocation();row.lastPosition={X=p.X,Y=p.Y,Z=p.Z}
      if not row.wasActive then P.events[#P.events+1]={kind='potion',at=os.clock(),owner=owner:GetAddress()};ctx.log('MC107_WITCH_POTION native_damage=true')end
     elseif row.wasActive and row.lastPosition then costume.hostiles107:burst(e,row.lastPosition);P.events[#P.events+1]={kind='splash',at=os.clock()};ctx.log('MC107_WITCH_SPLASH')end
    end
    row.wasActive=active;row.witch=witch
    if #P.events>40 then table.remove(P.events,1)end
    if ours~=row.ours then
     row.ours=ours
     if ours then ctx.log('MC91_PROJECTILE_SKIN kind='..row.kind..' native_damage=true')end
    end
   end
  end
 end
 T.onEpoch('pal_projectiles91',function()P.pending={};P.rows={};P.events={}end)
 return P
end
