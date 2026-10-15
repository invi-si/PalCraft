-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local H={}
 function H:forget()self.active=nil;self.inputPending=nil;self.player=nil;self.epoch=nil;self.p=nil;self.mode=nil;self.custom=nil;self.gravity=nil;self.at=nil;self.maxDelta=nil end
 function H:owns(env)
  
  if self.epoch~=ctx.epoch()or not env or(env.epoch~=nil and env.epoch~=ctx.epoch())then self:forget();return false end
  if not ctx.valid(env.player)or env.player:GetAddress()~=self.player then self:forget();return false end
  return true
 end
 function H:begin(env)
  if self.active and self:owns(env)then return end
  if self.epoch~=ctx.epoch()then self:forget()end
  self:finish(env)
  if not env or(env.epoch~=nil and env.epoch~=ctx.epoch())or not ctx.valid(env.player)or not ctx.valid(env.controller)then self:forget();return false end
  local m=env.player.CharacterMovement;assert(ctx.valid(m),'Entry movement unavailable')
  self.player=env.player:GetAddress();self.epoch=ctx.epoch();self.at=os.clock();local p=env.player:K2_GetActorLocation();self.p={X=p.X,Y=p.Y,Z=p.Z}
  self.mode=m.MovementMode;self.custom=m.CustomMovementMode;self.gravity=m.GravityScale;self.active=true;self.maxDelta=0
  m.GravityScale=0;m:SetMovementMode(0,0);m.Velocity={X=0,Y=0,Z=0};env.controller:SetIgnoreMoveInput(true)
  ctx.log('MC51_ENTRY_HOLD_BEGIN epoch='..self.epoch..' z='..self.p.Z)
 end
 function H:release(env,reason)
  if not self.active then return end
  if self:owns(env)then
   local m=env.player.CharacterMovement;if not ctx.valid(m)or not ctx.valid(env.controller)then self:forget();return end;m.GravityScale=self.gravity;local p=env.player:K2_GetActorLocation();local moved=(p.X-self.p.X)^2+(p.Y-self.p.Y)^2+(p.Z-self.p.Z)^2>100^2
   m:SetMovementMode(reason=='world-ready'and moved and 3 or self.mode,reason=='world-ready'and moved and 0 or self.custom);m.Velocity={X=0,Y=0,Z=0}
   if reason=='world-ready'then self.inputPending=true else env.controller:SetIgnoreMoveInput(false)end
   ctx.log(string.format('MC51_ENTRY_HOLD_END reason=%s seconds=%.3f max_delta_cm=%.3f',reason,os.clock()-self.at,self.maxDelta))
  end
  self.active=false
 end
 function H:finish(env)
  if self.inputPending and self:owns(env)then
   if not ctx.valid(env.controller)then self:forget();return end
   env.controller:SetIgnoreMoveInput(false);self.inputPending=false;ctx.log('MC52_LOADING_INPUT_RELEASE')
  end
 end
 function H:rebaseOwnedFooting(env)
  if not self.active or not self:owns(env)then return end
  local m=env.player.CharacterMovement;if not ctx.valid(m)then self:forget();return end
  local p=env.player:K2_GetActorLocation();self.p={X=p.X,Y=p.Y,Z=p.Z};self.mode=1;self.custom=0
  m:SetMovementMode(0,0);m:StopMovementImmediately()
  ctx.log('MC52_ENTRY_HOLD_OWNED_FOOTING z='..p.Z)
 end
 function H:tick(env)
  if not self.active then return end
  if not self:owns(env)then self:forget();return end
  local p=env.player:K2_GetActorLocation();self.maxDelta=math.max(self.maxDelta,math.sqrt((p.X-self.p.X)^2+(p.Y-self.p.Y)^2+(p.Z-self.p.Z)^2))
  _G.MC_OUT_K('K2_SetActorLocation',env.player,self.p,false,{},true)
  if os.clock()-self.at>=30 then self:release(env,'bounded-timeout30s');ctx.log('MC52_ENTRY_HOLD_TIMEOUT')end
 end
 if ctx.timers then ctx.timers.onEpoch('entry-hold',function()H:forget()end)end
 return H
end
