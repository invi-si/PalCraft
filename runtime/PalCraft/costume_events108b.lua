-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,Z)
 local E={pending={},events={},hooks={}};local UE,valid=ctx.UE,ctx.valid
 local T=dofile(ctx.base..'/timers.lua')
 local actions={
  PinkCat='/Game/Pal/Blueprint/Action/Waza/PinkCat/BP_Action_Unique_PinkCat_CatPunch',

 }
 local encounter='/Game/Pal/Blueprint/Action/Common/BP_ActionEncount'
 local golemAction='/Game/CustomPalsA1/BP_Action_Ac_Golem'
 E.golem=dofile(ctx.base..'/golemAc.lua')(ctx,Z)
 local function event(kind,s,data)
  data=data or{};data.kind=kind;data.at=os.clock();data.species=s and s.species
  E.events[#E.events+1]=data;if #E.events>64 then table.remove(E.events,1)end
 end

 T.hook('/Script/Pal.PalCopyMeshVisualEffect:SetupMainMesh',function()end,function(context,source)
  local mesh=source:get();if not valid(mesh)then return end
  local owner=mesh:GetOwner();if not valid(owner)then return end
  local s=Z.hosts[owner:GetAddress()]
  if s then if not valid(s.mesh)or s.mesh:GetAddress()~=mesh:GetAddress()then return end
  else
   
   local name=owner:GetClass():GetFullName()
   local moss=name:find('/Game/CustomPalsA1/BP_Mossback.BP_Mossback_C',1,true)

   if moss then
    local donor=owner.Mesh;if not valid(donor)or donor:GetAddress()~=mesh:GetAddress()then return end
   elseif not(name:find('/Game/MinecraftBossD/BP_MC_Hidden_',1,true)or name:find('/Game/MinecraftHosts99/BP_MC_Hidden_',1,true)or name:find('/Game/MinecraftParrot103/BP_MC_Hidden_',1,true)or name:find('/Game/MinecraftCreatures105/BP_MC_Hidden_',1,true))then return end
  end
  local copy=context:get();if not valid(copy)then return end
  local render=copy:GetMainMesh();if not valid(render)then return end
  render:SetVisibility(false,false);render:SetHiddenInGame(true,false)
  render:SetRenderInMainPass(false);render:SetRenderInDepthPass(false);render:SetRenderCustomDepth(false)
  copy:SetActorHiddenInGame(true)
  event('RECALL_COPY_SUPPRESSED',s,{copy=copy:GetAddress(),mesh=render:GetAddress(),source=owner:GetClass():GetFullName()})
 end)
 function E:hookAction(path,kind)
  if self.hooks[path]then return end
  local name=path:match('([^/]+)$');Z:asset(path..'.'..name..'_C')
  local fn=path..'.'..name..'_C:OnBeginAction'
  if not valid(StaticFindObject(fn))then
   self.hooks[path]='unavailable'
   event('ACTION_HOOK_UNAVAILABLE',nil,{path=fn})
   return 
  end
  T.hook(fn,function(context)
   if #E.pending<64 then E.pending[#E.pending+1]={action=context:get(),at=os.clock(),epoch=T.epoch,kind=kind}end
  end)
  self.hooks[path]=true
 end
 function E:bind(s)
  s.attackObject108b=nil;s.windup108b=nil
  E.golem:clear(s)
  local path=(s.kind=='irongolem'or s.kind=='warden'or s.definition.bossD)and golemAction or actions[s.definition.host];if path then self:hookAction(path,(s.kind=='irongolem'or s.kind=='warden'or s.definition.bossD)and'golem'or'attack')end
  if s.kind=='irongolem'then
   self:hookAction(encounter,'encounter')

   local ip=s.parameter:GetIndividualParameter();local old=false
   local values=ip:GetEquipWaza()
   if type(values)=='table'then for _,w in ipairs(values)do if w==20 then old=true end end
   else values:ForEach(function(_,w)if w:get()==20 then old=true end end)end
   if old then ip:RemoveEquipWaza(20);ip:AddEquipWaza(16);event('GOLEM_FAST_MELEE_MIGRATED',s)end
  end
 end
 function E:cadence(s,restart)
  if s.kind~='irongolem'then return end
  
  local ai=s.host:GetController();local slots=valid(ai)and ai.SkillSlot
  if not valid(slots)then return false end
  local changed=false
  local function tune(skill)
   if valid(skill)and skill.WazaType==16 then

    skill.DatabaseCoolTime=.65;skill.CoolDownTimeMax=.65;changed=true
   end
  end

  slots.SkillMap:ForEach(function(_,skill)tune(skill:get())end)
  if changed then
   if restart then slots:RestartCoolTime_ByWazaID(16)end
   if not s.golemCadenceA then event('GOLEM_CADENCE',s,{recoverySeconds=.65,targetInterval=1.75});s.golemCadenceA=true end
  end
  return changed
 end
 function E:golemAI(s)
  if s.kind~='irongolem'then return end
  local ai=s.host:GetController();local component=valid(ai)and ai.AIActionComponent
  if not valid(component)then return end
  local action=component:GetCurrentTopParentAction_BP()
  if valid(action)and action:GetClass():GetFullName():find('BP_AIAction_CombatPal_C',1,true)then

   if action.ShouldSelectWait then action.ShouldSelectWait=false end
   if action.NextIsProvocation then action.NextIsProvocation=false end
  end
 end
 function E:drain(e,now)
  if #self.pending==0 then return end
  local pending=self.pending;self.pending={}
  for _,row in ipairs(pending)do local a=row.action
   if row.epoch==T.epoch and valid(a)then
    local host=a:GetActionCharacter();local s=valid(host)and Z.hosts[host:GetAddress()]
    if s and valid(s.parameter)and not s.parameter:IsDead()and not s.parameter:GetIsCapturedProcessing()then
     if row.kind=='encounter'then

      if s.kind=='irongolem'then
       a.bIsEndAction=true

       local target=a:GetActionTarget()
       if not valid(target)and valid(host.DamageReactionComponent)then
        local utility=UE.Object('/Script/Pal.Default__PalUtility')
        local ip=utility:GetIndividualCharacterParameterByIstanceID(host,host.DamageReactionComponent:GetLastAttackerInstanceID())
        target=valid(ip)and ip:GetIndividualActor()or nil
       end
       if valid(target)then self.golem:engage(s,target,now)end
       event('GOLEM_QUICK_READY',s)
      end
     elseif row.kind=='golem'then
      if s.definition.bossD then Z.bossD:engage(s,a:GetActionTarget(),now)elseif s.kind=='warden'then Z.wardenC:engage(s,a:GetActionTarget(),now)else self.golem:engage(s,a:GetActionTarget(),now)end
      event('GOLEM_TIMER_TARGET',s,{nativeAt=row.at})
     elseif s.kind~='irongolem'then
      s.attackObject108b=a:GetAddress();s.windup108b={nativeAt=row.at,observedAt=now,object=s.attackObject108b}
       Z:beginAttack(s,e,row.at,a);s.aggressive=true
       Z:animate(s,now,0)
       event('WINDUP',s,{nativeAt=row.at,observedAt=now,delay=now-row.at,object=s.attackObject108b})
     end
    end
   end
  end
 end
 T.onEpoch('costume-events108b',function()E.pending={};E.events={}end)
 return E
end
