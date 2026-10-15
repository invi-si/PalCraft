-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local T=dofile(ctx.base..'/timers.lua');local R={}
 function R:travelTo(env,goal,label,onDone)
  if self.handle then T.cancel(self.handle)end
  local epoch=ctx.epoch()
  env.player.CharacterMovement:SetMovementMode(5,0)
  env.player.CharacterMovement:StopMovementImmediately()
  self.handle=T.loop(200,function()
   if epoch~=ctx.epoch()or ctx.quiesced()then self.handle=nil;return true end
   local alive=ctx.environment();if not alive then return false end
   local p=alive.player:K2_GetActorLocation()
   local x,y,z=goal.X-p.X,goal.Y-p.Y,goal.Z-p.Z
   local distance=math.sqrt(x*x+y*y+z*z);local step=distance>0 and math.min(1,4800/distance)or 1
   alive.player.CharacterMovement:StopMovementImmediately()
   assert(_G.MC_OUT_K('K2_SetActorLocation',alive.player,{X=p.X+x*step,Y=p.Y+y*step,Z=p.Z+z*step},false,{},true))
   if distance<=4800 then
    alive.player.CharacterMovement:SetMovementMode(1,0);self.handle=nil
    if onDone then onDone(alive)end;return true
   end
   return false
  end,'owned-travel')
 end
 return R
end
