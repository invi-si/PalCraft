-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
 local R={};local UE,valid=ctx.UE,ctx.valid
 local function vec(v)return{X=v.X,Y=v.Y,Z=v.Z}end
 local function rot(v)return{Pitch=v.Pitch,Yaw=v.Yaw,Roll=v.Roll}end
 local seats={horse={X=8,Y=0,Z=141},camel={X=12,Y=0,Z=216}}
 local bosses=dofile(ctx.base..'/boss_mountI.lua')
 for kind,data in pairs(bosses)do seats[kind]=data.seat end
 function R.coat(g)return((g.A%5)+(g.B%5)+(g.C%5)+(g.D%5))%5+1 end
 function R.charge(seconds)
  
  local ticks=math.max(0,seconds)*20
  return ticks<10 and ticks*.1 or(.8+2/(ticks-9)*.1)
 end
 function R:bind(s,Z)
  if not seats[s.kind]then return end
  local scale=s.host:GetActorScale3D();local marker=s.host:GetComponentByClass(UE.Object('/Script/Pal.PalRideMarkerComponent'))
  assert(valid(marker),'MC106 native mount marker absent')
  s.ride106={marker=marker,parent=marker:GetAttachParent(),socket=marker:GetAttachSocketName(),location=vec(marker.RelativeLocation),rotation=rot(marker.RelativeRotation),scale=vec(marker.RelativeScale3D)}
  local seat=seats[s.kind]
  local boss=bosses[s.kind];local parent
  if boss then

   local helper=s.seatHelperJ
   if not valid(helper)then
    local tf={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
    helper=s.actor:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,tf,false);s.seatHelperJ=helper
    helper:SetMobility(2);helper:SetCollisionEnabled(0);helper:SetGenerateOverlapEvents(false);helper:SetCastShadow(false)
   end
   helper:SetStaticMesh(Z:asset('/Game/CustomPalsA1/SM_I_'..s.kind..'_SeatPart.SM_I_'..s.kind..'_SeatPart'))
   assert(helper:K2_AttachToComponent(s.host.RootComponent,UE.FindOrAddFName('None'),2,2,2,false))
   helper:SetRelativeScale3D({X=1/math.abs(scale.X),Y=1/math.abs(scale.Y),Z=1/math.abs(scale.Z)})
   _G.MC_OUT_K('K2_SetRelativeRotation',helper,{Pitch=0,Yaw=0,Roll=0},false,ignoredHitJ(),true)
   local socket=UE.FindOrAddFName('MC_RiderSeatI');assert(helper:DoesSocketExist(socket),'MCT cooked rider socket absent')
   local localSeat=helper:GetSocketTransform(socket,2).Translation
   local location={X=(seat.X-localSeat.X)/scale.X,Y=(seat.Y-localSeat.Y)/scale.Y,Z=(seat.Z-s.capsule:GetScaledCapsuleHalfHeight()-localSeat.Z)/scale.Z}
   _G.MC_OUT_K('K2_SetRelativeLocation',helper,location,false,ignoredHitJ(),true)
   helper:SetVisibility(false,false);helper:SetRenderInMainPass(false);helper:SetRenderInDepthPass(false)
   assert(marker:K2_AttachToComponent(helper,socket,2,2,2,false))
   marker:SetRelativeScale3D({X=1,Y=1,Z=1})
   _G.MC_OUT_K('K2_SetRelativeLocation',marker,{X=0,Y=0,Z=0},false,ignoredHitJ(),true)
   s.seatStableT=true
  else
   assert(marker:K2_AttachToComponent(s.host.RootComponent,UE.FindOrAddFName('None'),2,2,2,false))
   marker:SetRelativeScale3D({X=1/math.abs(scale.X),Y=1/math.abs(scale.Y),Z=1/math.abs(scale.Z)})
   _G.MC_OUT_K('K2_SetRelativeLocation',marker,{X=seat.X/scale.X,Y=seat.Y/scale.Y,Z=(seat.Z-s.capsule:GetScaledCapsuleHalfHeight())/scale.Z},false,ignoredHitJ(),true)
  end
  _G.MC_OUT_K('K2_SetRelativeRotation',marker,{Pitch=0,Yaw=0,Roll=0},false,ignoredHitJ(),true)
  if s.kind=='horse'then
   local colors={'horse','horsewhite','horseblack','horsechestnut','horsecreamy'}
   local guid=s.parameter:GetIndividualParameter():GetPalId().InstanceId
   s.coat106=self.coat(guid);local name=colors[s.coat106]
   s.normalMaterial105=Z:asset('/Game/MinecraftRideables106/MI_MC_'..name..'.MI_MC_'..name)
   s.hitMaterial105='/Game/MinecraftRideables106/MI_MC_'..name..'_hit.MI_MC_'..name..'_hit'
   local textures={'Horse','HorseWhite','HorseBlack','HorseChestnut','HorseCreamy'}
   local texture=Z:asset('/Game/MinecraftFidelityX4/T_J_'..textures[s.coat106]..'.T_J_'..textures[s.coat106])
   for i,m in ipairs(s.models)do if m.mesh then
    if s.x4 then s.x4.materials[i]:SetTextureParameterValue(UE.FindOrAddFName('Tex'),texture)else s.parts[i]:SetMaterial(0,s.normalMaterial105)end
   end end
  end
  ctx.log('MC106_RIDE_BIND species='..s.species..' coat='..tostring(s.coat106)..' seatZ='..seat.Z)
 end
 function R:release(s)
  local d=s.ride106;s.ride106=nil
  if d and valid(d.marker)and valid(d.parent)then
   d.marker:K2_AttachToComponent(d.parent,d.socket,2,2,2,false);d.marker:SetRelativeScale3D(d.scale)
   _G.MC_OUT_K('K2_SetRelativeLocation',d.marker,d.location,false,ignoredHitJ(),true);_G.MC_OUT_K('K2_SetRelativeRotation',d.marker,d.rotation,false,ignoredHitJ(),true)
  end
 end
 function R:clear(touch)
  local s=self.jump;self.jump=nil
  if touch and s and valid(s.movement)then s.movement:SetJumpDisableFlag(UE.FindOrAddFName('MC106Charge'),false)end
 end
 function R:sample(M,e,now)
  if M.id~='MC_Horse'or not M.riding or not valid(M.mount)or not valid(M.movement)then self:clear(true);return end
  local s=self.jump
  if not s or s.address~=M.mountAddress then
   self:clear(true);s={address=M.mountAddress,movement=M.movement};self.jump=s
   s.movement:SetJumpDisableFlag(UE.FindOrAddFName('MC106Charge'),true)
  end
  self.key=self.key or{KeyName=UE.FindOrAddFName('SpaceBar')}
  local down=e.controller:IsInputKeyDown(self.key)
  local grounded=s.movement.MovementMode==1
  if down and not s.down and grounded then s.started=now end
  s.charge=s.started and self.charge(now-s.started)or 0
  if not down and s.down and s.started then
   local ratio=self.charge(now-s.started);s.started=nil;s.charge=0
   if grounded then

    local gravity=math.abs(s.movement:GetGravityZ());local velocity=math.sqrt(2*gravity*320)*(.4+.6*ratio)
    M.mount:LaunchCharacter({X=0,Y=0,Z=velocity},false,true)
    s.last={at=now,ratio=ratio,velocity=velocity,height=320*(.4+.6*ratio)^2}
    ctx.log('MC106_HORSE_JUMP charge='..ratio..' velocity='..velocity)
   end
  end
  if not grounded and not down then s.started=nil;s.charge=0 end
  s.down=down;return s
 end
 return R
end
