-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local configs={
  wither={{0,140,95,125},{30,238,85,90}},
  enderdragon={{-90,290,160,310},{420,290,95,125}},
  warden={{0,115,67,108},{15,218,55,57}},
  enderman={{0,150,32,115},{0,260,32,35}},
  slime={{0,120,105,120},{0,130,105,110}},
  witch={{0,95,38,75},{20,177,33,42}},
  wolf={{-10,49,35,70},{48,69,29,38}},
  horse={{15,96,43,92},{95,145,34,55}},
  camel={{30,166,49,118},{156,233,39,75}},
  fox={{-20,39,23,55},{45,48,23,32}},
  rabbit={{-6,20,14,26},{15,43,14,18}},
  cat={{-4,30,17,45},{44,43,17,23}},
  panda={{-2,65,53,86},{109,76,39,46}},
  irongolem={{0,125,55,82},{25,229,31,37}},
 }
 local UE,valid=ctx.UE,ctx.valid
 local function vec(v)return{X=v.X,Y=v.Y,Z=v.Z}end
 local function rot(v)return{Pitch=v.Pitch,Yaw=v.Yaw,Roll=v.Roll}end
 return function(s)
  local config=configs[s.kind];if not config then return false end
  s.captureParts={};local components={};local scale=s.host:GetActorScale3D()
  for _,capsule in ipairs({true,false})do
   local cls=UE.Object(capsule and'/Script/Pal.PalBodyPartsCapsuleComponent'or'/Script/Pal.PalBodyPartsSphereComponent')
   for _,v in ipairs(s.host:K2_GetComponentsByClass(cls))do
    local ok,c=pcall(function()return v:get()end);c=ok and c or v
    if valid(c)then components[#components+1]={component=c,capsule=capsule,height=c:K2_GetComponentLocation().Z}end
   end
  end
  table.sort(components,function(a,b)return a.height<b.height end)
  for i,row in ipairs(components)do
   local c=row.component;local capsule=row.capsule
   local q=config[i==1 and 1 or 2]
   s.captureParts[#s.captureParts+1]={component=c,parent=c:GetAttachParent(),socket=c:GetAttachSocketName(),location=vec(c.RelativeLocation),rotation=rot(c.RelativeRotation),scale=vec(c.RelativeScale3D),radius=capsule and c:GetUnscaledCapsuleRadius()or c:GetUnscaledSphereRadius(),half=capsule and c:GetUnscaledCapsuleHalfHeight()or nil}
   assert(c:K2_AttachToComponent(s.host.RootComponent,UE.FindOrAddFName('None'),2,2,2,false))
   c:SetRelativeScale3D({X=1/math.abs(scale.X),Y=1/math.abs(scale.Y),Z=1/math.abs(scale.Z)})
   _G.MC_OUT_K('K2_SetRelativeRotation',c,{Pitch=capsule and s.kind~='irongolem'and s.kind~='enderman'and s.kind~='witch'and s.kind~='slime'and s.kind~='warden'and s.kind~='wither'and 90 or 0,Yaw=0,Roll=0},false,{},true)
   _G.MC_OUT_K('K2_SetRelativeLocation',c,{X=q[1]/scale.X,Y=0,Z=(q[2]-s.capsule:GetScaledCapsuleHalfHeight())/scale.Z},false,{},true)
   if capsule then c:SetCapsuleSize(q[3],q[4],true)else c:SetSphereRadius(q[3],true)end
  end
  ctx.log('MC105_CAPTURE_REFIT species='..s.species..' parts='..#s.captureParts)
  return true
 end
end
