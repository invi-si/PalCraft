-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
 local T=dofile(ctx.base..'/timers.lua');local P={pool={},active={},assets={},events={},serial=0}
 local function v(x,y,z)return{X=x,Y=y,Z=z}end
 local function tf(p,s)return{Rotation={X=0,Y=0,Z=0,W=1},Translation=p or v(0,0,0),Scale3D=v(s or 1,s or 1,s or 1)}end
 function P:mesh(index)
  local d=ctx.registry[index];local a=self.assets[index]
  if not a then
   a=ctx.UE.Object(d.mesh)
   if not ctx.valid(a)then local pkg,name=d.mesh:match('^(.*)%.([^%.]+)$');a=ctx.UE.GetAsset109(ctx.UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=ctx.UE.FindOrAddFName(pkg),AssetName=ctx.UE.FindOrAddFName(name)})end
   assert(ctx.valid(a),'Particle block mesh absent '..d.name);ctx.retain(a);self.assets[index]=a
  end;return a
 end
 function P:prepare(env)
  if self.epoch==ctx.epoch()and ctx.valid(self.actor)then return end
  self.epoch=ctx.epoch();self.pool={};self.active={};self.assets={}
  local g=ctx.UE.Object('/Script/Engine.Default__GameplayStatics');local tag=ctx.UE.FindOrAddFName('MC73Particles');local found={}
  _G.MC_OUT_K('GetAllActorsWithTag',g,env.player,tag,found)
  for _,a in ipairs(found)do local ok,o=pcall(function()return a:get()end);o=ok and o or a;if ctx.valid(o)and o:GetWorld():GetAddress()==env.world:GetAddress()then self.actor=o;break end end
  if not ctx.valid(self.actor)then
   local a=g:BeginDeferredActorSpawnFromClass(env.world,ctx.UE.Object('/Script/Engine.Actor'),tf(),1,nil);a=g:FinishSpawningActor(a,tf());assert(ctx.valid(a));self.actor=a;a.Tags={tag};a:SetActorEnableCollision(false)
   local root=a:AddComponentByClass(ctx.UE.Object('/Script/Engine.SceneComponent'),false,tf(),false);root:SetMobility(2)
  end
  local old=self.actor:K2_GetComponentsByClass(ctx.UE.Object('/Script/Engine.StaticMeshComponent'))
  for _,a in ipairs(old)do local ok,o=pcall(function()return a:get()end);o=ok and o or a;self.pool[#self.pool+1]=o end
  for i=1,16 do
   local c=self.pool[i]or self.actor:AddComponentByClass(ctx.UE.Object('/Script/Engine.StaticMeshComponent'),false,tf(),false)
   c:SetMobility(2);c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false);c:SetCastShadow(false);c:SetVisibility(false,false);self.pool[i]=c
  end
 end
 function P:emit(env,kind,p,block)
  if not env or not ctx.ready()then return false end
  self:prepare(env)
  local now=os.clock();local n=kind=='explosion'and 16 or kind=='death'and 12 or kind=='break'and 8 or kind=='crit'and 8 or 4
  self.serial=self.serial+1;local free={}
  for i=1,16 do if not self.active[i]then free[#free+1]=i end end
  
  n=math.min(n,#free);if n==0 then return false end
  local duration=kind=='explosion'and .40 or kind=='death'and .4 or .32
  for k=1,n do
   local i=free[k];local index=block or ctx.types[(kind=='crit'or kind=='hit')and'yellow_wool'or(kind=='explosion'and k%2==0)and'light_gray_wool'or'white_wool']
   index=index or ctx.types.stone;local source=self:mesh(index);local cube=ctx.registry[index].kind=='cube'and source or self:mesh(ctx.types.stone)
   local c=self.pool[i];c:SetStaticMesh(cube);c:SetMaterial(0,source:GetMaterial(0))
   local angle=k*2.3999632297287;local speed=kind=='explosion'and 160 or 75
   local size=kind=='explosion'and(.17+k%3*.035)or kind=='death'and .12 or kind=='break'and .09 or .045
   local q=v(p.X+math.cos(angle)*8,p.Y+math.sin(angle)*8,p.Z+(k%3-1)*9)
   self.active[i]={at=now,duration=duration,p=q,v=v(math.cos(angle)*speed,math.sin(angle)*speed,45+(k%4)*17),size=size,kind=kind,serial=self.serial}
   _G.MC_OUT_K('K2_SetWorldTransform',c,tf(q,size),false,ignoredHitJ(),true);c:SetVisibility(true,false)
  end
  self.nextAt=now+.075;self.events[#self.events+1]={kind=kind,count=n,duration=duration,block=block,serial=self.serial};if #self.events>64 then table.remove(self.events,1)end
  ctx.log('MC73_PARTICLES kind='..kind..' count='..n..' seconds='..duration);return true
 end
 function P:tick(now)
  if not next(self.active)then return end 
  if now<(self.nextAt or 0)then return end;self.nextAt=now+.075
  if not ctx.ready()then return end
  for i,b in pairs(self.active)do
   local age=now-b.at
   if age>=b.duration then self.pool[i]:SetVisibility(false,false);self.active[i]=nil
   else
    local life=age/b.duration;local gravity=b.kind=='break'and 240 or 0
    local p=v(b.p.X+b.v.X*age,b.p.Y+b.v.Y*age,b.p.Z+b.v.Z*age-gravity*age*age)
    local scale=b.size*(b.kind=='explosion'and(1+life*1.8)*(1-life*.5)or(1-life*.85))
    _G.MC_OUT_K('K2_SetWorldTransform',self.pool[i],tf(p,scale),false,ignoredHitJ(),true)
   end
  end
 end
 T.frame('particles73',function()P:tick(os.clock())end)
 T.onEpoch('particles73',function()P.actor=nil;P.pool={};P.active={};P.assets={};P.epoch=nil end)
 return P
end
