-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
 local C={};local valid=ctx.valid
 local function v(x,y,z)return{X=x,Y=y,Z=z}end
 function C.owned(s)
  local g=s.parameter:GetIndividualParameter().SaveParameter.OwnerPlayerUId
  return g.A~=0 or g.B~=0 or g.C~=0 or g.D~=0
 end
 function C:mask(s)

  if s.mesh.bRenderInMainPass then s.mesh:SetRenderInMainPass(false)end
  if s.mesh.bRenderInDepthPass then s.mesh:SetRenderInDepthPass(false)end
  if s.mesh.bRenderCustomDepth then s.mesh:SetRenderCustomDepth(false)end
  if s.mesh:IsVisible()then s.mesh:SetVisibility(false,false)end

  if valid(s.parameter)then s.parameter.IsDisableOtomoReturnEffect=true end
 end
 function C:footing(s,refit)
  local half=s.capsule:GetUnscaledCapsuleHalfHeight()
  local scale=s.host:GetActorScale3D()
  local old=s.footing108
  if not old or math.abs(old.half-half)>.01 or math.abs(old.x-scale.X)+math.abs(old.z-scale.Z)>.001 then
   _G.MC_OUT_K('K2_SetRelativeLocation',s.root,v(0,0,-half),false,ignoredHitJ(),true)
   s.footing108={half=half,x=scale.X,z=scale.Z}
   if old and refit then refit(s)end
   ctx.log('MC108_FOOTING id='..s.species..' capsuleHalf='..half..' scaleZ='..scale.Z)
  end

  if s.kind=='warden'then
   local mount=ctx.UE.mount76
   local riding=mount and mount.riding and mount.mountAddress==s.host:GetAddress()
   local z=-half
   if riding and valid(mount.movement)and mount.movement.MovementMode==1 then
    local p=s.host:K2_GetActorLocation();local hit={};local color={R=0,G=0,B=0,A=0}
    local e=ctx.environment();local ignored={s.host};if e then ignored[#ignored+1]=e.player end
    if _G.MC_OUT_K('LineTraceSingle',ctx.UE.GetKismetSystemLibrary(),s.host,p,v(p.X,p.Y,p.Z-1200),0,false,ignored,0,hit,true,color,color,0)and hit.ImpactNormal.Z>.65 then
     local floor=(hit.ImpactPoint.Z+2-p.Z)/math.max(.01,scale.Z)
     if math.abs(floor+half)<200 then z=floor end
    end
   end
   if s.rideFloorM~=z then
    dofile(ctx.base..'/poseK.lua')(s.root,{location=v(0,0,z),rotation=s.root.RelativeRotation,scale=s.root.RelativeScale3D})
    s.rideFloorM=z
    if riding and not s.rideLoggedM then ctx.log('MCM_WARDEN_FOOT_FIT relativeZ='..z..' nominal='..(-half));s.rideLoggedM=true end
    if not riding then s.rideLoggedM=nil end
   end
  end
 end
 function C:sample(s,now,refit)
  self:mask(s)
  local owned=self.owned(s);s.owned108=owned
  local inactive=not s.host:GetActiveActorFlag()or s.host.bHidden or(owned and s.parameter:IsInactiveOtomo())
  if inactive then
   if not s.recall108 then
    local f=s.footing108;local p=s.lastMotionPosition
    local scale=s.scale or v(1,1,1)
    s.recall108={at=now,scale=v(scale.X*(f and f.x or 1),scale.Y*(f and f.x or 1),scale.Z*(f and f.z or 1))}

    if p and f then
      s.root:SetAbsolute(true,s.lookAbsoluteT or false,true)
     _G.MC_OUT_K('K2_SetWorldLocation',s.root,v(p.X,p.Y,p.Z-f.half*f.z),false,ignoredHitJ(),true)
    end
    ctx.log('MC108_RECALL_BEGIN id='..s.species..' donorRender=false attached=true')
   end
   return false
  end
  if s.recall108 then
    s.root:SetAbsolute(false,s.lookAbsoluteT or false,false)
   s.recall108=nil;s.footing108=nil;s.scale=nil;s.deadAt=nil;s.lastHP=nil;s.lastMotionPosition=nil
   ctx.log('MC108_REACTIVATE id='..s.species)
  end
  self:footing(s,refit)
  return true
 end
 function C:animate(s,now)
  local r=s.recall108;if not r then return false end
  local amount=math.max(0,1-(now-r.at)/.3)
  if amount>0 or not r.finished then
   
   local scale=math.max(.001,amount)
   s.root:SetRelativeScale3D(v(r.scale.X*scale,r.scale.Y*scale,r.scale.Z*scale))
   s.actor:SetActorHiddenInGame(amount<=0)
   if amount<=0 then r.finished=true;ctx.log('MC108_RECALL_END id='..s.species..' attached=true donorRender=false')end
  end
  return true
 end
 return C
end
