-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local T=dofile(ctx.base..'/timers.lua')
 local G={};local UE,valid=ctx.UE,ctx.valid
 local now=ctx.now or os.clock
 local function log(s)ctx.log('MCCM_'..s)end
 function G:available()return ctx.config.creative_mode==true and ctx.config.creative~=false end
 function G:mode()return ctx.readMode()=='creative'and'creative'or'survival'end
 function G:enabled()return self:available()and self:mode()=='creative'end
 function G:protects(env)return self:enabled()and env~=nil and env.status~='dead'end
 function G:identity(env)
  return ctx.world()..':'..env.player:GetAddress()..':'..env.player.CharacterParameterComponent:GetAddress()..':'..env.player:GetFullName()
 end
 function G:tag()return UE.FindOrAddFName('PalCraftCreativeMode')end
 function G:restoreFlight(env,reason)
  local f=self.fly or self.retiredFly
  if f and f.owner==self:identity(env)then
   local m=env.player.CharacterMovement
   m.MaxFlySpeed=f.speed
   if m.MovementMode==5 then m:StopMovementImmediately();m:SetMovementMode(m:IsMovingOnGround()and 1 or 3,0)end
   log('FLIGHT_OFF reason='..tostring(reason))
  end
  self.fly=nil;self.retiredFly=nil
 end
 function G:release(env,reason)
  if not env or not valid(env.player)then return end
  local owner=self:identity(env);local g=self.guard or self.retiredGuard
  local p=env.player.CharacterParameterComponent;local individual=p:GetIndividualParameter()
  
  p:SetMuteki(self:tag(),false)
  individual:RemoveDecreaseFullStomachRates(self:tag())
  if g and g.owner==owner then p.bIsInfinitySP=g.infinity end
  self:restoreFlight(env,reason)
  self.guard=nil;self.retiredGuard=nil;self.cleanOwner=owner
  self.cleanEpoch=ctx.epoch();self.cleanPlayer=env.playerAddress or env.player:GetAddress()
  self.spaceDown=nil;self.lastSpace=nil;self.middleDown=nil
  log('GUARDS_OFF reason='..tostring(reason)..' native_caps_unchanged=true')
 end
 function G:bind(env)
  local owner=self:identity(env)
  if self.guard and self.guard.owner==owner then return end

  self:release(env,'rebind')
  local p=env.player.CharacterParameterComponent;local individual=p:GetIndividualParameter()
  self.guard={owner=owner,infinity=p.bIsInfinitySP,epoch=ctx.epoch(),food=individual:GetFullStomach(),sp=p:GetSP().Value,regenAt=now()+.25}
  assert(type(self.guard.infinity)=='boolean','Creative stamina guard unavailable')
  p:SetMuteki(self:tag(),true)
  individual:SetDecreaseFullStomachRates(self:tag(),0)
  p.bIsInfinitySP=true
  self.cleanOwner=nil
  log('GUARDS_ON world='..ctx.world()..' damage=false hunger=false stamina=false')
 end
 function G:switch(target,env)
  if target~='survival'and target~='creative'then return false,'Invalid game mode'end
  if target=='creative'and not self:available()then return false,'Creative mode is unavailable'end
  if target==self:mode()then return true end
  if target=='creative'and ctx.canSwitch and not ctx.canSwitch()then return false,'Finish the current block action first.'end
  local previous=self:mode()
  
  local saved,saveError=pcall(ctx.writeMode,target)
  if not saved then log('SAVE_FAILED '..tostring(saveError));return false,'Game mode could not be changed. See the log.'end
  local ok,err=pcall(function()
   if target=='creative'then self:bind(env)else self:release(env,'survival')end
  end)
  if not ok then
   local restored,restoreError=pcall(self.release,self,env,'activation-failed')
   ctx.writeMode(previous)
   log('SWITCH_FAILED '..tostring(err)..' restored='..tostring(restored)..' '..tostring(restoreError))
   return false,'Game mode could not be changed. See the log.'
  end
  self.lastSpace=nil;self.spaceDown=nil;self.middleDown=nil
  if ctx.changed then ctx.changed(target,env)end
  log('MODE world='..ctx.world()..' value='..target..' saved=true')
  return true
 end
 function G:grounded(env)
  if ctx.grounded then return ctx.grounded(env)end
  local p=env.player:K2_GetActorLocation();local half=env.player.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local hit={};local color={R=0,G=0,B=0,A=0}
  local found=_G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),env.player,
   {X=p.X,Y=p.Y,Z=p.Z-half+4},{X=p.X,Y=p.Y,Z=p.Z-half-9},0,false,{env.player},0,hit,true,color,color,0)
  return found and hit.ImpactNormal.Z>.6
 end
 function G:toggleFlight(env)
  if not self:enabled()or env.controller:IsRiding()then return false end
  if self.fly then self:restoreFlight(env,'double-tap');return true end
  local m=env.player.CharacterMovement

  local glider=m.MovementMode==6 and m:GetCustomMovementMode()==4
  if m.MovementMode~=1 and m.MovementMode~=3 and not glider then return false end
  self.fly={owner=self:identity(env),epoch=ctx.epoch(),speed=m.MaxFlySpeed,at=now()}
  m.MaxFlySpeed=ctx.config.creative_fly_speed or 900
  m:StopMovementImmediately();m:SetMovementMode(5,0)
  log('FLIGHT_ON native_mode=5');return true
 end
 function G:tick(env)
  if not env then self.spaceDown=nil;self.lastSpace=nil;self.middleDown=nil;return end
  if not self:enabled()then
   if self.guard or self.retiredGuard or self.fly or self.retiredFly or self.cleanEpoch~=ctx.epoch()or self.cleanPlayer~=(env.playerAddress or env.player:GetAddress())then self:release(env,'survival-or-disabled')end
   return
  end
  self:bind(env)

  local g=self.guard
  if now()>=g.regenAt then
   g.regenAt=now()+.25
   local p=env.player.CharacterParameterComponent;local individual=p:GetIndividualParameter()
   local food=individual:GetFullStomach();local sp=p:GetSP().Value
   g.food=math.min(individual:GetMaxFullStomach(),math.max(g.food,food));g.sp=math.min(p:GetMaxSP().Value,math.max(g.sp,sp))
   if food<g.food then individual:SetFullStomach(g.food)end
   if sp<g.sp then p:SetSP({Value=g.sp})end
  end
  local pc=env.controller;local allowed=ctx.gameplayInput(env)and not pc:IsRiding()
  if not allowed then
   self.spaceDown=nil;self.lastSpace=nil;self.middleDown=nil
   if self.fly and not pc:IsRiding()then env.player.CharacterMovement:StopMovementImmediately()
   elseif self.fly then self:restoreFlight(env,'mounted')end
   return
  end
  self.keys=self.keys or{space={KeyName=UE.FindOrAddFName('SpaceBar')},shift={KeyName=UE.FindOrAddFName('LeftShift')},rshift={KeyName=UE.FindOrAddFName('RightShift')},middle={KeyName=UE.FindOrAddFName('MiddleMouseButton')}}
  local space=pc:IsInputKeyDown(self.keys.space)
  if space and not self.spaceDown then
   local t=now()
   if self.lastSpace and t-self.lastSpace<=(ctx.config.creative_double_tap_seconds or .3)then self:toggleFlight(env);self.lastSpace=nil else self.lastSpace=t end
  end
  self.spaceDown=space
  local middle=pc:IsInputKeyDown(self.keys.middle)
  if middle and not self.middleDown and ctx.pickBlock then ctx.pickBlock(env)end
  self.middleDown=middle
  if self.fly then
   local m=env.player.CharacterMovement
   if m.MovementMode~=5 then self:restoreFlight(env,'native-mode-change');return end
   local vertical=(space and 1 or 0)-((pc:IsInputKeyDown(self.keys.shift)or pc:IsInputKeyDown(self.keys.rshift))and 1 or 0)
   if now()-self.fly.at>.35 and vertical<=0 and m.Velocity.Z<=0 and self:grounded(env)then
    self:restoreFlight(env,'landing');m:SetMovementMode(1,0)
   elseif vertical~=0 then env.player:AddMovementInput({X=0,Y=0,Z=1},vertical,false)end
  end
 end
 T.frame('creative-mode',function()
  if ctx.quiesced()or(ctx.ready and not ctx.ready())then return end
  G:tick(ctx.environment())
 end)
 T.onEpoch('creative-mode',function()

  G.retiredGuard=G.guard or G.retiredGuard;G.retiredFly=G.fly or G.retiredFly
  G.guard=nil;G.fly=nil;G.cleanOwner=nil;G.cleanEpoch=nil;G.cleanPlayer=nil;G.keys=nil;G.spaceDown=nil;G.lastSpace=nil;G.middleDown=nil
 end)
 return G
end
