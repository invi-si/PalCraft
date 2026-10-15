-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local R={};local UE,valid=ctx.UE,ctx.valid
 local T=dofile(ctx.base..'/timers.lua')

 T.hook('/Script/Pal.PalUtility:ProcessDamageAndPlayEffects',function(_,_,defender,value)
  local pending=R.pendingArraysS
  if not pending and not R.probeS then return end
  local d=value:get()
  if pending then
   if pending.foliage then d.HitFoliageIndex={pending.index}end
   if #pending.rates>0 then d.SpecialAttackRateInfos=pending.rates end
  end
  if R.probeS then R.probeS.make(d,defender:get())end
 end,function()end)
 local function counts(e)
  local n=ctx.items.native
  return 'Stone='..n:count(e,'Stone')..' Paldium='..n:count(e,'Pal_crystal_S')..' Wood='..n:count(e,'Wood')
 end
 local tiers={['MC_WoodenPickaxe']='Pickaxe_Tier_00',['MC_WoodenAxe']='Axe_Tier_00',['MC_StonePickaxe']='Pickaxe_Tier_01',['MC_StoneAxe']='Axe_Tier_01',['MC_IronPickaxe']='Pickaxe_Tier_02',['MC_IronAxe']='Axe_Tier_02',['MC_GoldenPickaxe']='Pickaxe_Tier_01',['MC_GoldenAxe']='Axe_Tier_01',['MC_DiamondPickaxe']='Pickaxe_Tier_03',['MC_DiamondAxe']='Axe_Tier_03',['MC_NetheritePickaxe']='Pickaxe_Tier_03',['MC_NetheriteAxe']='Axe_Tier_03'}
 function R:tier(id)return tiers[id]end
 function R:hit(e,id,owned,receipt)
  if self.suppressS then return false end
  if not ctx.gameplayInput(e)or e.controller:IsRiding()then return false end
  local hit=ctx.trace(e,true);local comp=hit and hit.Component:Get()
  local actor=valid(comp)and comp:GetOwner()
  local w=e.player.ShooterComponent:GetHasWeapon()
  local wid=valid(w)and w:GetItemId().StaticId:ToString()or'None'
  if receipt then ctx.log('MCR_LMB_ROUTE selected='..tostring(id)..' native_weapon='..wid..' native_disabled='..tostring(owned)..' component='..(valid(comp)and comp:GetFullName()or'miss')..' actor='..(valid(actor)and actor:GetFullName()or'none')..' instance='..tostring(hit and hit.Item)..' mc_block_handler=target_only')end
  if not valid(comp)or not valid(actor)then return false end
  local foliage=comp:IsA(UE.Object('/Script/Pal.PalFoliageISMComponent'))
  local model
  if actor:IsA(UE.Object('/Script/Pal.PalMapObject'))then
   local m=actor:GetModel();local concrete=valid(m)and m:GetConcreteModel(false)
   if valid(concrete)and concrete:IsA(UE.Object('/Script/Pal.PalMapObjectItemDropOnDamagModel'))then model=m end
  end
  if not foliage and not model then return false end

  if not owned and id~=nil and id~=''and wid~='None'then return false end
  local p,h=e.player:K2_GetActorLocation(),hit.ImpactPoint
  if(p.X-h.X)^2+(p.Y-h.Y)^2+(p.Z-h.Z)^2>350^2 or(foliage and(type(hit.Item)~='number'or hit.Item<0))then return false end
  local now=os.clock();if now<(self.nextHit or 0)then return true end
  self.nextHit=now+.6
  local tier=self:tier(id);local power=valid(w)and w:GetWeaponDamage()or 10
  if not owned then power=10 end

  local rates={};local rateText={}
  if valid(w)then w.SpecialAttackRateInfos:ForEach(function(_,v)
   local r=v:get();rates[#rates+1]={Type=r.Type,Rate=r.Rate};rateText[#rateText+1]=tostring(r.Type)..':'..r.Rate
  end)end
  local nativeData=tier and ctx.items:data(tier)
  if valid(nativeData)then power=nativeData.AttackValue end

  local info={Attacker=e.player,Defender=actor,HitComponent=comp,Power=power,Category=0,Element=0,AttackType=1,WeaponType=valid(w)and w.WeaponType or 7,
   HitLocation={X=h.X,Y=h.Y,Z=h.Z},HitInfo={bBlockingHit=true,Item=hit.Item,ImpactPoint={X=h.X,Y=h.Y,Z=h.Z},Location={X=h.X,Y=h.Y,Z=h.Z}},
   IsLeanBack=false,IsBlow=false,BlowVelocity={X=0,Y=0,Z=0},SneakAttackRate=1,DamageRatePerCollision=1,PvPBuildingDamageRate=1,PvPPlayerToGuildPalDamageRate=1,CollectionObjectDamageRate=1,WeaponDamageRatePvP=1,
   AttackStaticItemID=UE.FindOrAddFName(tier or wid),bAttackableToFriend=false}
  local hp=valid(model)and model:GetHP().CurrentValue or'foliage'
  ctx.log('MCR_NATIVE_RESOURCE_HIT before '..counts(e)..' item='..tostring(id)..' tier='..tostring(tier or'fist')..' power='..power..' special='..table.concat(rateText,',')..' instance='..tostring(hit.Item)..' hp='..tostring(hp))
  self.pendingArraysS={foliage=foliage,index=hit.Item,rates=rates}
  local ok,err=pcall(function()UE.Object('/Script/Pal.Default__PalUtility'):ProcessDamageAndPlayEffects(e.player,actor,info)end)
  self.pendingArraysS=nil;if not ok then error(err)end
  ctx.log('MCR_NATIVE_RESOURCE_DAMAGE hp_before='..tostring(hp)..' hp_after='..tostring(valid(model)and model:GetHP().CurrentValue or'destroyed'))
  self.pendingReceipt=true
  return true
 end
 function R:press(e,id,owned)
  local handled=self:hit(e,id,owned,true)
  if not handled then return false end
  if self.handle then T.cancel(self.handle)end
  local epoch=T.epoch
  self.handle=T.loop(100,function()
   if epoch~=T.epoch then self.handle=nil;return true end
   local current=ctx.environment()
   if not current then self.handle=nil;return true end
   if self.pendingReceipt then self.pendingReceipt=nil;ctx.log('MCR_NATIVE_RESOURCE_COUNTS '..counts(current))end
   if not current.controller:IsInputKeyDown({KeyName=UE.FindOrAddFName('LeftMouseButton')})or ctx.items:hotbar(current,ctx.phaseA.selected).id~=id then self.handle=nil;return true end
   if not self:hit(current,id,owned,false)then self.handle=nil;return true end
   return false
  end,'native-resource-R')
  return true
 end
 T.hook('/Script/Pal.PalFoliageISMComponentBase:OnReceiveDamageInClient',function(_,value)
  local d=value:get();ctx.log('MCR_NATIVE_NODE_DAMAGE value='..d.NativeDamageValue..' base='..d.BasePower..' item='..d.AttackStaticItemID:ToString())
 end)
 T.onEpoch('native-resource-R',function()R.nextHit=nil;R.handle=nil;R.pendingReceipt=nil;R.pendingArraysS=nil end)

 return R
end
