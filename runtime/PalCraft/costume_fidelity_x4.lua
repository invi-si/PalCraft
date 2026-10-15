-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

local base=(debug.getinfo(1,'S').source:sub(2):match('^(.*)[/\\]'))
local P=dofile(base..'/vanilla_pose_x4.lua')
local models=_G.MC_X4_GEOMETRY_J or assert(loadfile(base..'/mob_models_x4.lua'))(base);_G.MC_X4_GEOMETRY_J=models
local F={models=models,source=P}
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function v(x,y,z)return{X=x,Y=y,Z=z}end
local function rotation(x,y,z,out)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 local pitch=math.asin(clamp(sz*sy*cx-cz*sx,-1,1));local yaw,roll
 if math.abs(math.cos(pitch))>1e-7 then yaw=math.atan(cz*sy*cx+sz*sx,cy*cx);roll=math.atan(-sz*cy,sz*sy*sx+cz*cx)else yaw=math.atan(sy,cz*cy);roll=0 end
 out=out or{};out.Pitch=math.deg(pitch);out.Yaw=math.deg(yaw);out.Roll=math.deg(roll);return out
end
local common={ageInTicks='idf.L',headYaw='ieh.au',headPitch='ieh.av',bodyYaw='ieh.at',walkAnimationPos='ieh.ax',walkAnimationSpeed='ieh.ay',ageScale='ieh.aA',attackProgress='ich.m'}
local empty={}
local clips={warden={roar='ift.c',sniff='ift.d',emerge='ift.e',dig='ift.f',attack='ift.g',sonicBoom='ift.h'},camel={sit='ics.d',sitPose='ics.e',stand='ics.f',idle='ics.g',dash='ics.h'}}
function F.new(kind)
 local state=P.defaultState(kind)
 
 state['ieh.au']=0;state['ieh.av']=0;state['ieh.ax']=0;state['ieh.ay']=0;state['idf.L']=0
 return {kind=kind,source=P.new(kind),state=state,models=assert(models[kind])}
end
function F.state(instance,input)
 local s=instance.state;local kind=instance.kind;local f=P.f32
 for k,key in pairs(common)do if input[k]~=nil then s[key]=f(input[k])end end
 for key,value in pairs(input.raw or empty)do s[key]=value end
 if kind=='sheep'then if input.eatPosition~=nil then s['iez.a']=f(input.eatPosition)end;if input.eatAngle~=nil then s['iez.b']=f(input.eatAngle)end end
 if kind=='chicken'then if input.flap~=nil then s['icu.a']=f(input.flap)end;if input.flapSpeed~=nil then s['icu.b']=f(input.flapSpeed)end end
 if kind=='irongolem'then if input.attackTicksRemaining~=nil then s['ieb.a']=f(input.attackTicksRemaining)end;if input.offerFlowerTick~=nil then s['ieb.b']=math.floor(input.offerFlowerTick)end end
 if kind=='skeleton'and input.bowAiming~=nil then s['ich.f']=P.enum('gzo$a',input.bowAiming and 'd'or'a')end
 if kind=='zombie'or kind=='husk'then if input.aggressive~=nil then s['ify.a']=input.aggressive and 1 or 0 end end
 if kind=='warden'then
  if input.wardenCounters then
   local c=input.wardenCounters;local o={['dch.cV']=c.previousTendril,['dch.cU']=c.tendril,['dch.cX']=c.previousHeart,['dch.cW']=c.heart}
   s['ift.a']=P.entityEffect('dch.L(F)F',o,input.partialTick or 0);s['ift.b']=P.entityEffect('dch.M(F)F',o,input.partialTick or 0)
  end
  if input.tendrilAnimation~=nil then s['ift.a']=f(input.tendrilAnimation)end
  if input.heartAnimation~=nil then s['ift.b']=f(input.heartAnimation)end
 end
 if kind=='wither'then
  if input.sideHeadYaw then s['ifv.b']={f(input.sideHeadYaw[1]),f(input.sideHeadYaw[2])}end
  if input.sideHeadPitch then s['ifv.a']={f(input.sideHeadPitch[1]),f(input.sideHeadPitch[2])}end
 end
 if kind=='enderdragon'then
  if input.flapTime~=nil then s['idd.a']=f(input.flapTime)end
  if input.partialTick~=nil then s['idd.h']=f(input.partialTick)end
  if input.flightHistory then
   assert(#input.flightHistory==64,'64 vanilla 20Hz history samples, oldest first')
   local h=s['idd.i'] or{class='cya',['cya.d']=63,['cya.c']={}}
   for i,q in ipairs(input.flightHistory)do local row=h['cya.c'][i]or{class='cya$a'};h['cya.c'][i]=row;row['cya$a.a']=q.heightBlocks;row['cya$a.b']=f(q.yawDegrees)end
   s['idd.i']=h
  end
 end
 for name,key in pairs(clips[kind]or empty)do
  local value=input.clips and input.clips[name]
  if value==false or type(value)=='number'then local q=s[key]or{class='cfz'};s[key]=q;q.started=value~=false;q.startTick=value==false and 0 or math.floor(value)end
 end
 return s
end
function F.frame(instance,input)
 input=input or empty;local state=F.state(instance,input);local source=P.frame(instance.source,state);instance.outputs=instance.outputs or{{},{}};instance.outputIndex=3-(instance.outputIndex or 2);local out=instance.outputs[instance.outputIndex];local kind=instance.kind
 for i,m in ipairs(instance.models)do
  local name=m.name=='__model_root'and'root'or m.name:gsub('^fur_',''):gsub('^shell_','')
  local p=source[name]
  if not p then p={m.mcPivot[1],m.mcPivot[2],m.mcPivot[3],m.mcRotation[1],m.mcRotation[2],m.mcRotation[3],1,1,1,1}end
  local row=out[i]or{location={},rotation={},scale={}};out[i]=row
  local k=6.25*m.scaleMC;local pos=row.location;pos.X=-p[3]*k;pos.Y=-p[1]*k;pos.Z=-p[2]*k
  if m.name=='__model_root'then pos.Z=pos.Z+(kind=='enderdragon'and 320 or 24*k)end
  rotation(p[4],p[5],p[6],row.rotation);row.scale.X=p[9];row.scale.Y=p[7];row.scale.Z=p[8];row.visible=p[10]~=0 and(not m.parent or out[m.parent].visible)
  if m.layer=='fur'and input.sheared then out[i].visible=false end
 end
 local material=instance.materialOutput or{};instance.materialOutput=material
 if kind=='warden'then
  material.Heart=P.effect('hzs.a(Lift;F)F',state,state['idf.L']);material.Tendrils=P.effect('hzs.b(Lift;F)F',state,state['idf.L'])
  material.Spots1=P.effect('hzs.d(Lift;F)F',state,state['idf.L']);material.Spots2=P.effect('hzs.c(Lift;F)F',state,state['idf.L']);material.Bioluminescent=1
 end
 if kind=='creeper'and input.swell~=nil then
  local rs={['icy.a']=P.f32(input.swell)};local _,t=P.effect('hwd.a(Licy;Lfzm;)V',rs);local a=t[1].value
  out[1].scale=v(a[3],a[1],a[2]);out[1].location.Z=out[1].location.Z*a[2];material.WhiteOverlay=P.whiteOverlay(P.effect('hwd.a(Licy;)F',rs))
 end
 if kind=='slime'and input.squish~=nil then
  local size=input.slimeSize or 4;local _,t=P.effect('hyx.a(Lifd;Lfzm;)V',{['ifd.a']=P.f32(input.squish),['ifd.b']=size});local a=t[3].value
  
  local f=t[1].value[1];out[1].scale=v(a[3]*f/4,a[1]*f/4,a[2]*f/4);out[1].location.Z=out[1].location.Z*a[2]*f/4-t[2].value[2]*100*f
 end
 return out,material,source
end

function F.assemble(ctx,actor,root,kind,transform)
 local inst=F.new(kind);inst.parts={};inst.materials={};inst.ctx=ctx
 for i,m in ipairs(inst.models)do
  local cls=m.mesh and'/Script/Engine.StaticMeshComponent'or'/Script/Engine.SceneComponent'
  local c=actor:AddComponentByClass(ctx.UE.Object(cls),false,transform,false);c:SetMobility(2)
  assert(c:K2_AttachToComponent(m.parent and inst.parts[m.parent]or root,ctx.UE.FindOrAddFName('None'),2,2,2,false))
  if m.mesh then
   c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false);assert(c:SetStaticMesh(assert(ctx.asset(m.mesh))))
   local mid=c:CreateDynamicMaterialInstance(0,c.StaticMesh:GetMaterial(0),ctx.UE.FindOrAddFName('None'));inst.materials[i]=mid
  end
  inst.parts[i]=c
 end
 return inst
end
function F.apply(instance,input)
 local frames,material=F.frame(instance,input)
 for i,p in ipairs(frames)do
  local c=instance.parts[i];_G.MC_OUT_K('K2_SetRelativeLocation',c,p.location,false,ignoredHitJ(),true);_G.MC_OUT_K('K2_SetRelativeRotation',c,p.rotation,false,ignoredHitJ(),true);c:SetRelativeScale3D(p.scale);c:SetVisibility(p.visible,false)
  local mid=instance.materials[i];if mid then for k,value in pairs(material)do mid:SetScalarParameterValue(instance.ctx.UE.FindOrAddFName(k),value)end end
 end
 return frames,material
end
return F
