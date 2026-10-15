-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local UE,valid=ctx.UE,ctx.valid
 local S={seen={},events={}}
 S.heights={CP_FungalHost=160,CP_IvoryRattle=170,CP_PatchworkBrute=240,CP_RedstoneRevenant=220,CP_Mossback=380}
 function S:sample(a,e,id)
  local alpha=id=='CP_PatchworkBruteAlpha'
  local height=alpha and 312 or self.heights[id];if not height then return end
  if alpha then local s=a:GetActorScale3D();if math.abs(s.X-1.3)>.001 or math.abs(s.Y-1.3)>.001 or math.abs(s.Z-1.3)>.001 then a:SetActorScale3D({X=1.3,Y=1.3,Z=1.3})end end
  local cp=a.CharacterParameterComponent;local key=a:GetAddress()
  if not a:GetActiveActorFlag()or a.bHidden or cp:IsDead()or cp:GetIsCapturedProcessing()then self.seen[key]=nil;return end
  local cap=a.CapsuleComponent;local half=cap:GetScaledCapsuleHalfHeight();local radius=cap:GetScaledCapsuleRadius()
  local previous=self.seen[key]
  if previous and previous.actor==a:GetFullName()and math.abs(previous.half-half)<.01 then return end
  local parts={}
  for _,capsule in ipairs({true,false})do
   local class=UE.Object(capsule and'/Script/Pal.PalBodyPartsCapsuleComponent'or'/Script/Pal.PalBodyPartsSphereComponent')
   for _,value in ipairs(a:K2_GetComponentsByClass(class))do
    local ok,c=pcall(function()return value:get()end);c=ok and c or value
    if valid(c)then parts[#parts+1]={component=c,capsule=capsule,z=c:K2_GetComponentLocation().Z}end
   end
  end
  if #parts==0 then return end 
  table.sort(parts,function(x,y)return x.z<y.z end)
  local scale=a:GetActorScale3D();local rows={}
  for index,part in ipairs(parts)do
   local c=part.component;local head=index>1
   local r=height*(head and .19 or .24);local h=height*(head and .19 or .35)
   local z=height*(head and .79 or .40)
   assert(c:K2_AttachToComponent(a.RootComponent,UE.FindOrAddFName('None'),2,2,2,false))
   c:SetRelativeScale3D({X=1/math.abs(scale.X),Y=1/math.abs(scale.Y),Z=1/math.abs(scale.Z)})
   _G.MC_OUT_K('K2_SetRelativeRotation',c,{Pitch=0,Yaw=0,Roll=0},false,{},true)
   _G.MC_OUT_K('K2_SetRelativeLocation',c,{X=0,Y=0,Z=(z-half)/scale.Z},false,{},true)
   if part.capsule then c:SetCapsuleSize(r,h,true)else c:SetSphereRadius(r,true)end
   rows[#rows+1]={name=c:GetFullName(),radius=r,half=part.capsule and h or nil,aboveFeet=z}
  end

  local nav=a.CharacterMovement.NavAgentProps
  nav.AgentRadius=radius;nav.AgentHeight=2*half
  self.seen[key]={actor=a:GetFullName(),id=id,height=height,half=half,radius=radius,
   navRadius=nav.AgentRadius,navHeight=nav.AgentHeight,parts=rows}
  self.events[#self.events+1]=self.seen[key];if #self.events>40 then table.remove(self.events,1)end
  ctx.log('MCB_SIZE_READY id='..id..' height='..height..' capsule='..(2*half)..' captureParts='..#rows)
 end
 function S:reset()self.seen={};self.events={}end
 return S
end
