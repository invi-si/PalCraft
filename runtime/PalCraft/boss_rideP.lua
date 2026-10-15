-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local P={events={}};local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local flying={MC_Wither=true,MC_EnderDragon=true}
 function P:event(kind,row)
  row=row or{};row.kind=kind;row.at=os.clock();self.events[#self.events+1]=row
  if #self.events>40 then table.remove(self.events,1)end;ctx.log('MCP_RIDE_'..kind)
 end
 function P:beforeGetOff(rider,M)
  if not M.riding or not flying[M.id]or not valid(M.rider)or rider:GetAddress()~=M.rider:GetAddress()or not valid(M.movement)or M.movement.MovementMode~=5 or not valid(self.player)then return end
  local cp=self.player.CharacterParameterComponent;if not valid(cp)or cp:IsDead()then return end
  local ip=cp:GetIndividualParameter();if not valid(ip)then return end
  self.pending={epoch=T.epoch,player=self.player:GetAddress(),ip=ip,before=cp:GetHP().Value,species=M.id}
  ip:SetNoFallDamageHeightLastJumpedLocation()
 end
 function P:afterGetOff()
  local row=self.pending;self.pending=nil;if not row then return end
  T.after(1,function()
   local e=ctx.environment();if row.epoch~=T.epoch or not e or e.status~='alive'or e.player:GetAddress()~=row.player or e.controller:IsRiding()or not valid(row.ip)then return end
   row.ip:SetNoFallDamageHeightLastJumpedLocation();row.born=os.clock();self.safe=row
   self:event('DISMOUNT_ARMED',{species=row.species,hp=row.before,nativeNoFall=row.ip:IsNoFallDamageLastJumpedLocation()})
  end,'bossP-dismount')
 end
 function P:sample(e,M,now)
  self.player=e.player
  local previous=self.previous
  if not M.riding and previous and previous.epoch==T.epoch and previous.player==e.player:GetAddress()and previous.airborne and valid(previous.ip)then
   previous.ip:SetNoFallDamageHeightLastJumpedLocation();previous.born=now;previous.falling=e.player.CharacterMovement.MovementMode==3;self.safe=previous
   self:event('DISMOUNT_ARMED',{species=previous.species,hp=previous.before,nativeNoFall=previous.ip:IsNoFallDamageLastJumpedLocation(),path='ride transition'})
  end
  self.previous=nil
  if M.riding and flying[M.id]and valid(M.movement)then
   local cp=e.player.CharacterParameterComponent
   self.previous={epoch=T.epoch,player=e.player:GetAddress(),ip=cp:GetIndividualParameter(),before=cp:GetHP().Value,species=M.id,airborne=M.movement.MovementMode==5}
  end
  local safe=self.safe
  if safe then
   if safe.epoch~=T.epoch or e.player:GetAddress()~=safe.player or not valid(safe.ip)then self.safe=nil
   elseif safe.falling and(e.player.CharacterMovement.MovementMode==1 or e.player.CharacterMovement.MovementMode==4)then
    
    safe.ip:ResetLastJumpedLocation();self.safe=nil
    self:event('LANDED',{before=safe.before,after=e.player.CharacterParameterComponent:GetHP().Value,seconds=now-safe.born,nativeNoFall=safe.ip:IsNoFallDamageLastJumpedLocation()})
   elseif now-safe.born>120 or e.player.CharacterParameterComponent:IsDead()or M.riding then safe.ip:ResetLastJumpedLocation();self.safe=nil
   else
    safe.falling=safe.falling or e.player.CharacterMovement.MovementMode==3
    if not safe.ip:IsNoFallDamageLastJumpedLocation()then safe.ip:SetNoFallDamageHeightLastJumpedLocation()end
   end
  end
  if M.riding and M.id=='MC_Wither'and valid(M.movement)then
   self.space=self.space or{KeyName=UE.FindOrAddFName('SpaceBar')}
   local down=e.controller:IsInputKeyDown(self.space);local mode=M.movement.MovementMode
   if down and(mode==1 or mode==3)and M.parameter:GetSP().Value>0 then
    if not self.request then
     self.request={address=M.mountAddress,at=now};e.controller:StartFlyToServer();self:event('NATIVE_TAKEOFF',{id=M.id,mode=mode})
    elseif self.request.address==M.mountAddress and now-self.request.at>=.15 then
     
     M.movement:SetMovementMode(5,0);self:event('FLYING_MODE',{id=M.id,mode=M.movement.MovementMode});self.request=nil
    end
   else self.request=nil end
  else self.request=nil end
 end
 T.onEpoch('bossP',function()P.player=nil;P.safe=nil;P.pending=nil;P.request=nil;P.previous=nil;P.events={}end)
 return P
end
