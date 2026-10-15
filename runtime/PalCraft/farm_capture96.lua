-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local UE,valid=ctx.UE,ctx.valid;local C={}
 local batch105=dofile(ctx.base..'/capture105.lua')(ctx)
 local function vec(v)return{X=v.X,Y=v.Y,Z=v.Z}end
 local function rot(v)return{Pitch=v.Pitch,Yaw=v.Yaw,Roll=v.Roll}end
 function C:bind(s)
  if batch105(s)then return end
  if s.kind~='parrot'and s.kind~='chicken'and s.kind~='spider'and s.kind~='ocelot'then return end
  local spider=s.kind=='spider'or s.kind=='ocelot';local cat=s.kind=='ocelot'
  local cls=UE.Object(spider and'/Script/Pal.PalBodyPartsCapsuleComponent'or'/Script/Pal.PalBodyPartsSphereComponent');local components=s.host:K2_GetComponentsByClass(cls)
  local scale=s.host:GetActorScale3D();s.captureParts={};local spheres={}
  for _,v in ipairs(components)do
   local ok,c=pcall(function()return v:get()end);c=ok and c or v
   if valid(c)then spheres[#spheres+1]={component=c,height=c:K2_GetComponentLocation().Z}end
  end
  table.sort(spheres,function(a,b)return a.height<b.height end)
  for _,row in ipairs(spheres)do local c=row.component
    local n=#s.captureParts+1
    local old={component=c,parent=c:GetAttachParent(),socket=c:GetAttachSocketName(),location=vec(c.RelativeLocation),rotation=rot(c.RelativeRotation),scale=vec(c.RelativeScale3D),radius=spider and c:GetUnscaledCapsuleRadius()or c:GetUnscaledSphereRadius(),half=spider and c:GetUnscaledCapsuleHalfHeight()or nil}
    s.captureParts[n]=old
    assert(c:K2_AttachToComponent(s.host.RootComponent,UE.FindOrAddFName('None'),2,2,2,false))
    c:SetRelativeScale3D({X=1/math.abs(scale.X),Y=1/math.abs(scale.Y),Z=1/math.abs(scale.Z)})
    _G.MC_OUT_K('K2_SetRelativeRotation',c,{Pitch=spider and 90 or 0,Yaw=0,Roll=0},false,{},true)
    _G.MC_OUT_K('K2_SetRelativeLocation',c,{X=(spider and(n==1 and -25 or 35)or(n==1 and 0 or 30))/scale.X,Y=0,Z=((cat and(n==1 and 45 or 57)or(spider and 50 or(n==1 and 50 or 76)))-s.capsule:GetScaledCapsuleHalfHeight())/scale.Z},false,{},true)
    if spider then c:SetCapsuleSize(cat and 20 or 40,cat and(n==1 and 55 or 30)or(n==1 and 70 or 50),true)else c:SetSphereRadius(n==1 and 32 or 22,true)end
  end
  ctx.log('MC96_CAPTURE_REFIT species='..s.species..' native_body_spheres='..#s.captureParts)
 end
 function C:release(s)
  for _,old in ipairs(s.captureParts or{})do local c=old.component
   if valid(c)and valid(old.parent)then
    c:K2_AttachToComponent(old.parent,old.socket,2,2,2,false)
    c:SetRelativeScale3D(old.scale);_G.MC_OUT_K('K2_SetRelativeLocation',c,old.location,false,{},true);_G.MC_OUT_K('K2_SetRelativeRotation',c,old.rotation,false,{},true)
    if old.half then c:SetCapsuleSize(old.radius,old.half,true)else c:SetSphereRadius(old.radius,true)end
   end
  end
  s.captureParts=nil
 end
 return C
end
