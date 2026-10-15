-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local data=dofile(ctx.base..'/farm_ground96_data.lua');local valid=ctx.valid
 local F={seen={},events={},snaps=0,recoveries=0,data=data}
 local function distance(a,b)return(a.X-b.X)^2+(a.Y-b.Y)^2 end
 function F:nearest(key,p,minDistance,maxDistance)
  local island=data.islands[key];if not island then return end
  local best,score
  for _,c in ipairs(island.cells)do local d=distance(c,p)
   if(not minDistance or d>=minDistance^2)and(not maxDistance or d<=maxDistance^2)and(not score or d<score)then best=c;score=d end
  end
  return best,score
 end
 function F:check(a,e,id,p)
  local spec=data.species[id];if not spec or not ctx.island then return end
  p=p or a:K2_GetActorLocation()
  for _,alternate in ipairs(spec.alternates or{})do
   local o=data.islands[alternate.island].origin
   if math.abs(p.X-o.X)<8500 and math.abs(p.Y-o.Y)<8500 then spec=alternate;break end
  end
  local island=ctx.island.all[spec.island]
  if not island or not island.admitted or not island.footingReady then return end
  if not a:GetActiveActorFlag()or a.bHidden then return end
  local cp=a.CharacterParameterComponent;if cp:IsDead()or cp:GetIsCapturedProcessing()then return end
  local owner=cp:GetIndividualParameter().SaveParameter.OwnerPlayerUId
  local owned=owner.A~=0 or owner.B~=0 or owner.C~=0 or owner.D~=0
  p=p or a:K2_GetActorLocation();local d=data.islands[spec.island];local origin=d.origin

  if math.abs(p.X-origin.X)>8500 or math.abs(p.Y-origin.Y)>8500 then return end
  local ground,dist=self:nearest(spec.island,p);if not ground then return end
  local address=a:GetAddress();local cap=a.CapsuleComponent;local half=cap:GetScaledCapsuleHalfHeight();local foot=p.Z-half
  local first=not owned and not self.seen[address]
  local fallen=foot<d.floor+150 or(dist<300^2 and foot<ground.Z-180)
  if not first and not fallen then return end
  local q={X=ground.X,Y=ground.Y,Z=ground.Z+half+3}
  
  local hit={};local c={R=0,G=0,B=0,A=0}
  local ok=_G.MC_OUT_K('LineTraceSingle',ctx.UE.GetKismetSystemLibrary(),e.player,{X=q.X,Y=q.Y,Z=ground.Z+40},{X=q.X,Y=q.Y,Z=ground.Z-40},0,false,{e.player,a},0,hit,true,c,c,0)
  local component=ok and hit.Component:Get()or nil
  if not valid(component)or not ctx.island:owned(component:GetOwner())or math.abs(hit.ImpactPoint.Z-ground.Z)>8 then return end
  a.CharacterMovement:StopMovementImmediately();assert(_G.MC_OUT_K('K2_SetActorLocation',a,q,false,{},true));if not spec.flying then a.CharacterMovement:SetMovementMode(1,0)end
  self.seen[address]=true;self.snaps=self.snaps+1;if fallen and not first then self.recoveries=self.recoveries+1 end
  self.events[#self.events+1]={id=id,reason=first and'spawn'or'fall',before={X=p.X,Y=p.Y,Z=p.Z},after=q,ground=ground}
  if #self.events>24 then table.remove(self.events,1)end
  ctx.log('MC96_GROUND_'..(first and'SPAWN'or'RECOVER')..' id='..id..' ground='..ground.Z)
 end
 function F:reset()self.seen={};self.events={};self.snaps=0;self.recoveries=0 end
 return F
end
