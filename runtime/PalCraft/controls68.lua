-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local C={};local harvest=dofile(ctx.base..'/native_harvestR.lua')(ctx);local H=dofile(ctx.base..'/hand_motion66.lua')
 function C:owns(id)return type(id)=='string'and id:sub(1,3)=='MC_'and(id:find('Sword',1,true)or id:find('Axe',1,true)or id:find('Pickaxe',1,true)or id:find('Shovel',1,true)or id:find('Hoe',1,true))~=nil end
 function C:sync(env)
  local id=ctx.items:hotbar(env,ctx.phaseA.selected).id;local own=self:owns(id)and not env.controller:IsRiding()
  local shooter=env.player.ShooterComponent;local addr=shooter:GetAddress()
  local input=env.controller.PlayerInput;local action=ctx.UE.FindOrAddFName('WeaponUse')
  local now=os.clock()
  if self.address==addr and self.own==own and self.input==input:GetAddress()and now<(self.verifyAtZ1 or 0)then return end
  self.verifyAtZ1=now+.5
  local transitionZ1=self.address~=addr or self.own~=own;local repairedZ1=false
  if not self.keys or self.input~=input:GetAddress()then
   local keys=input:GetActionConfigKeys(action,0);self.keys={main=keys.MainKey.KeyName:ToString(),secondary=keys.SecondaryKey.KeyName:ToString()};self.input=input:GetAddress()

   if self.keys.main=='None'and self.keys.secondary=='None'then
    local settings=ctx.UE.Object('/Script/Engine.Default__InputSettings')
    if ctx.valid(settings)then settings.ActionMappings:ForEach(function(_,v)local m=v:get();if m.ActionName:ToString()=='WeaponUse'and m.Key.KeyName:ToString()~='None'and self.keys.main=='None'then self.keys.main=m.Key.KeyName:ToString()end end)end
   end
   ctx.log('MCQ4_ATTACK_KEYS main='..self.keys.main..' secondary='..self.keys.secondary)
  end
  local function key(n)return{KeyName=ctx.UE.FindOrAddFName(n)}end
  if self.keys.main~='None'or self.keys.secondary~='None'then
   local main,secondary=own and'None'or self.keys.main,own and'None'or self.keys.secondary
   local actual=input:GetActionConfigKeys(action,0)
   if actual.MainKey.KeyName:ToString()~=main or actual.SecondaryKey.KeyName:ToString()~=secondary or self.address~=addr or self.own~=own then
    input:UpdateActionMapping(action,{MainKey=key(main),SecondaryKey=key(secondary)},0)
    repairedZ1=true
    ctx.log('MCZ1_WEAPON_INPUT_RESTORED main='..main..' secondary='..secondary..' own='..tostring(own))
   end
  end
  if not transitionZ1 and not repairedZ1 then return end
  shooter:SetDisableShootFlag(ctx.UE.FindOrAddFName('MinecraftMelee68'),own)
  if own then shooter:ReleaseTrigger()end
  self.address=addr;self.own=own;ctx.log('MC68_ATTACK_OWNER own='..tostring(own)..' item='..tostring(id)..' movement_untouched=true')
 end
 function C:hit(env,pressedAt,swing)
  local id=ctx.items:hotbar(env,ctx.phaseA.selected).id
  if env.controller:IsRiding()then return true end
  local resource=harvest:press(env,id,self:owns(id));if resource then return true end
  if not self:owns(id)then return nil end
  if not ctx.gameplayInput(env)then return true end
  local now=os.clock();if now<(self.nextHit or 0)then return true end
  self.nextHit=now+H.cooldown(id);ctx.UE.attack66={at=now,period=H.cooldown(id)}
  if self.mobs:hit(env,pressedAt,swing)then return true end

  local camera=env.controller.PlayerCameraManager;local start=camera:GetCameraLocation();local rot=camera:GetCameraRotation()
  local pitch,yaw=math.rad(rot.Pitch),math.rad(rot.Yaw);local finish={X=start.X+900*math.cos(pitch)*math.cos(yaw),Y=start.Y+900*math.cos(pitch)*math.sin(yaw),Z=start.Z+900*math.sin(pitch)}
  local hit={};local color={R=0,G=0,B=0,A=0};local system=ctx.UE.GetKismetSystemLibrary()
  self.trace73={result='miss',start={X=start.X,Y=start.Y,Z=start.Z},finish=finish}
  if not _G.MC_OUT_K('SphereTraceSingleForObjects',system,env.player,start,finish,28,{2},false,{env.player},0,hit,true,color,color,0)then return false end
  local comp=hit.Component:Get();local target=ctx.valid(comp)and comp:GetOwner()
  self.trace73.result='object';self.trace73.target=ctx.valid(target)and target:GetFullName()or'none'
  if not ctx.valid(target)or target==env.player or not target:IsA(ctx.UE.Object('/Script/Pal.PalCharacter'))then return false end
  local p=env.player:K2_GetActorLocation();local h=hit.ImpactPoint
  self.trace73.result='range';self.trace73.point={X=h.X,Y=h.Y,Z=h.Z};self.trace73.distance=math.sqrt((p.X-h.X)^2+(p.Y-h.Y)^2+(p.Z-h.Z)^2)
  if(p.X-h.X)^2+(p.Y-h.Y)^2+(p.Z-h.Z)^2>350^2 then return false end
  local obstruction={};local eye={X=p.X,Y=p.Y,Z=p.Z+40}
  self.trace73.result='occlusion'
  if _G.MC_OUT_K('LineTraceSingle',system,env.player,eye,h,0,false,{env.player,target},0,obstruction,true,color,color,0)then return false end
  local weapon=env.player.ShooterComponent:GetHasWeapon();if not ctx.valid(weapon)then return false end

  local power=math.floor(weapon:GetWeaponDamage()*(id:find('Sword',1,true)and .8 or 1))
  local info={Attacker=env.player,Defender=target,HitComponent=comp,Power=power,Category=0,Element=0,AttackType=1,WeaponType=weapon.WeaponType,
   HitLocation={X=h.X,Y=h.Y,Z=h.Z},HitInfo={bBlockingHit=true,ImpactPoint={X=h.X,Y=h.Y,Z=h.Z},Location={X=h.X,Y=h.Y,Z=h.Z}},IsLeanBack=true,IsBlow=false,BlowVelocity={X=0,Y=0,Z=0},SneakAttackRate=1,DamageRatePerCollision=2/3,
   PvPBuildingDamageRate=1,PvPPlayerToGuildPalDamageRate=1,CollectionObjectDamageRate=1,WeaponDamageRatePvP=1,AttackStaticItemID=ctx.UE.FindOrAddFName(id),bAttackableToFriend=false}
  self.trace73.result='damage'
  local before=target.CharacterParameterComponent:GetHP().Value

  ctx.UE.Object('/Script/Pal.Default__PalUtility'):ProcessDamageAndPlayEffects(env.player,target,info)
  if ctx.UE.effects66 then ctx.UE.effects66:emit(env,env.player.CharacterMovement:IsFalling()and'crit'or'hit',h)end
  self.hits73=self.hits73 or{};self.hits73[#self.hits73+1]={target=target:GetFullName(),item=id,before=before,after=target.CharacterParameterComponent:GetHP().Value,power=info.Power};if #self.hits73>32 then table.remove(self.hits73,1)end
  ctx.log('MC68_NATIVE_HIT item='..id..' before='..before..' after='..target.CharacterParameterComponent:GetHP().Value..' power='..info.Power)
  return true
 end

 function C:reset()self.address=nil;self.own=nil;self.nextHit=nil end
 local T=dofile(ctx.base..'/timers.lua')
 T.onEpoch('controls68',function()C:reset();C.bowHeldZ1=nil end)

 T.frame('bow-input-Z1',function()
  local e=ctx.environment();if not e then C.bowHeldZ1=nil;return end
  local shooter=e.player.ShooterComponent
  local selected=ctx.items:hotbar(e,ctx.phaseA.selected).id
  local weapon=shooter:GetHasWeapon()
  local available=selected=='MC_Bow'and ctx.valid(weapon)and weapon:GetItemId().StaticId:ToString()=='MC_Bow'and not e.controller:IsRiding()and ctx.gameplayInput(e)
  C.bowKeysZ1=C.bowKeysZ1 or{{KeyName=ctx.UE.FindOrAddFName('LeftMouseButton')},{KeyName=ctx.UE.FindOrAddFName('RightMouseButton')}}
  local down=available and(e.controller:IsInputKeyDown(C.bowKeysZ1[1])or e.controller:IsInputKeyDown(C.bowKeysZ1[2]))
  if down and not C.bowHeldZ1 and shooter:CanShoot()then
   shooter:PullTrigger();C.bowHeldZ1=true;ctx.log('MCZ1_BOW_DRAW native_trigger=true')
  elseif not down and C.bowHeldZ1 then
   local cancel=not available;local tag=ctx.UE.FindOrAddFName('MinecraftBowZ1Cancel')
   if cancel then shooter:SetDisableShootFlag(tag,true)end
   shooter:ReleaseTrigger()
   if cancel then shooter:SetDisableShootFlag(tag,false)end
   C.bowHeldZ1=nil;ctx.log(cancel and'MCZ1_BOW_CANCEL ui_or_selection=true'or'MCZ1_BOW_RELEASE native_projectile=true')
  end
 end)
 return C
end
