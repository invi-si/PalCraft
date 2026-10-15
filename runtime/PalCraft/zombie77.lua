-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local modelTable=assert(loadfile(ctx.base..'/model_registryJ.lua'))(ctx.base)
 local species={MC_Zombie={kind='zombie',host='PinkCat',attack='CatPunch'},MC_Skeleton={kind='skeleton',host='RobinHood',attack='RobinHood_Snipe'},MC_Spider={kind='spider',host='Garm',attack='Garm_Bite',radius=40,half=45},MC_Creeper={kind='creeper',host='PinkCat',attack='CatPunch',radius=30,half=85}}
 species.MC_Mooshroom={["kind"]="mooshroom",["host"]="CowPal",["attack"]="AirCanon",["radius"]=45.0,["half"]=78.0,["farm"]=true}; species.MC_Cow={["kind"]="cow",["host"]="CowPal",["attack"]="AirCanon",["radius"]=45.0,["half"]=78.0,["farm"]=true}; species.MC_Sheep={["kind"]="sheep",["host"]="CowPal",["attack"]="AirCanon",["radius"]=38.0,["half"]=75.0,["farm"]=true}; species.MC_Pig={["kind"]="pig",["host"]="CowPal",["attack"]="AirCanon",["radius"]=38.0,["half"]=50.0,["farm"]=true}; species.MC_Chicken={["kind"]="chicken",["host"]="ChickenPal",["attack"]="AirCanon",["radius"]=25.0,["half"]=48.0,["farm"]=true};
 species.MC_Husk={kind='husk',host='PinkCat',attack='CatPunch',radius=30,half=97.5,ground=true,material='/Game/MinecraftCreatures100/MI_MC_husk_hit.MI_MC_husk_hit'}
 species.MC_Ocelot={kind='ocelot',host='Garm',attack='Garm_Bite',radius=25,half=40,farm=true,material='/Game/MinecraftCreatures100/MI_MC_ocelot_hit.MI_MC_ocelot_hit'}
 species.MC_Parrot={kind='parrot',host='Eagle',attack='AirCanon',radius=22,half=48,ground=true,material='/Game/MinecraftParrot103/MI_MC_parrot_hit.MI_MC_parrot_hit'}
 species.MC_Wolf={["kind"]="wolf",["host"]="Garm",["attack"]="Garm_Bite",["radius"]=28.0,["half"]=49.0,["farm"]=true,["material"]="/Game/MinecraftCreatures105/MI_MC_wolf_hit.MI_MC_wolf_hit"}
 species.MC_Fox={["kind"]="fox",["host"]="Garm",["attack"]="Garm_Bite",["radius"]=25.0,["half"]=38.0,["farm"]=true,["material"]="/Game/MinecraftCreatures105/MI_MC_fox_hit.MI_MC_fox_hit"}
 species.MC_Rabbit={["kind"]="rabbit",["host"]="Garm",["attack"]="Garm_Bite",["radius"]=16.0,["half"]=30.0,["farm"]=true,["material"]="/Game/MinecraftCreatures105/MI_MC_rabbit_hit.MI_MC_rabbit_hit"}
 species.MC_Cat={["kind"]="cat",["host"]="Garm",["attack"]="Garm_Bite",["radius"]=20.0,["half"]=32.0,["farm"]=true,["material"]="/Game/MinecraftCreatures105/MI_MC_cat_hit.MI_MC_cat_hit"}
 species.MC_Panda={["kind"]="panda",["host"]="CowPal",["attack"]="AirCanon",["radius"]=60.0,["half"]=68.0,["farm"]=true,["material"]="/Game/MinecraftCreatures105/MI_MC_panda_hit.MI_MC_panda_hit"}
 species.MC_IronGolem={["kind"]="irongolem",["host"]="PinkCat",["attack"]="CatPunch",["radius"]=60.0,["half"]=134.5,["farm"]=true,["material"]="/Game/MinecraftCreatures105/MI_MC_irongolem_hit.MI_MC_irongolem_hit"}
 species.MC_Horse={["kind"]="horse",["host"]="Garm",["attack"]="Garm_Bite",["radius"]=44.0,["half"]=94.0,["farm"]=true,["material"]="/Game/MinecraftRideables106/MI_MC_horse_hit.MI_MC_horse_hit"}
 species.MC_Camel={["kind"]="camel",["host"]="Garm",["attack"]="Garm_Bite",["radius"]=50.0,["half"]=141.0,["farm"]=true,["material"]="/Game/MinecraftRideables106/MI_MC_camel_hit.MI_MC_camel_hit"}
 species.MC_Enderman={["kind"]="enderman",["host"]="PinkCat",["attack"]="CatPunch",["radius"]=30.0,["half"]=144.0,["ground"]=true,["material"]="/Game/MinecraftHostiles107/MI_MC_enderman_hit.MI_MC_enderman_hit"}
 species.MC_Slime={["kind"]="slime",["host"]="PinkCat",["attack"]="CatPunch",["radius"]=90.0,["half"]=100.0,["ground"]=false,["material"]="/Game/MinecraftHostiles107/MI_MC_slime_hit.MI_MC_slime_hit"}
 species.MC_Witch={["kind"]="witch",["host"]="RobinHood",["attack"]="RobinHood_Snipe",["radius"]=35.0,["half"]=135.0,["ground"]=false,["material"]="/Game/MinecraftHostiles107/MI_MC_witch_hit.MI_MC_witch_hit"}
 species.MC_Warden={kind='warden',host='Garm',attack='Ac_Golem',radius=65,half=140,ground=true,material='/Game/MinecraftBossC/MI_MC_warden_hit.MI_MC_warden_hit'}
 species.MC_Wither={kind='wither',host='HawkBird',attack='Ac_Golem',radius=95,half=140,bossD=true,material='/Game/MinecraftBossD/MI_MC_wither_hit.MI_MC_wither_hit'}
 species.MC_EnderDragon={kind='enderdragon',host='HawkBird',attack='Ac_Golem',radius=200,half=220,bossD=true,material='/Game/MinecraftBossD/MI_MC_enderdragon_hit.MI_MC_enderdragon_hit'}
 local rootPoseOA=dofile(ctx.base..'/poseK.lua')
 local function rotateRootOA(root,rotation)
  local p,s=root.RelativeLocation,root.RelativeScale3D
  rootPoseOA(root,{location={X=p.X,Y=p.Y,Z=p.Z},rotation=rotation,scale={X=s.X,Y=s.Y,Z=s.Z}})
 end
 local lifecycle108=dofile(ctx.base..'/costume108.lua')(ctx)
 local ride106=dofile(ctx.base..'/ride106.lua')(ctx)
 local farmGround=dofile(ctx.base..'/farm_ground96.lua')(ctx);local farmCapture=dofile(ctx.base..'/farm_capture96.lua')(ctx)
 local passiveFlee=dofile(ctx.base..'/passive_flee101.lua')(ctx)
 local models=modelTable.zombie
 local motion=dofile(ctx.base..'/mob_motion.lua');local lookT=dofile(ctx.base..'/lookT.lua');local fidelity=dofile(ctx.base..'/costume_runtimeJ.lua')(ctx)
 local Z={slots={},hosts={},dirty=true,due=0,hostDue=0,candidates={},pending={},knownNames={},assets={},events={},serial=0}
 local function vec(x,y,z)return{X=x,Y=y,Z=z}end
 local function tf(x,y,z)return{Rotation={X=0,Y=0,Z=0,W=1},Translation=vec(x or 0,y or 0,z or 0),Scale3D=vec(1,1,1)}end
 local function record(kind,s)
  Z.serial=Z.serial+1;Z.events[#Z.events+1]={event=kind,serial=Z.serial,at=os.clock(),host=s and s.address,species=s and s.species}
  if #Z.events>80 then table.remove(Z.events,1)end
  ctx.log('MC77_COSTUME_'..kind..' host='..tostring(s and s.address)..' species='..tostring(s and s.species))
 end
 function Z:asset(path)
  local a=self.assets[path];if valid(a)then return a end
  local begun=os.clock()
  local p,n=path:match('^(.*)%.([^%.]+)$')
  a=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(p),AssetName=UE.FindOrAddFName(n)})
  if not valid(a)then a=UE.Object(path)end
  if not valid(a)then
   local k=UE.GetKismetSystemLibrary()
   a=UE.Native109(k,'LoadAsset_Blocking',k:Conv_SoftObjectPathToSoftObjectReference(k:MakeSoftObjectPath(path)))
  end
  assert(valid(a),'MC77 owned asset missing '..path);ctx.retain(a);self.assets[path]=a
  ctx.log(string.format('MC109_COSTUME_ASSET ms=%.3f path=%s',(os.clock()-begun)*1000,path));return a
 end
 local function warmLoadG(path)if path:sub(1,6)=='sound:'then ctx.sound:preloadSoundG(path:sub(7))else Z:asset(path)end end
 local warmG=dofile(ctx.base..'/asset_queueG.lua')(warmLoadG,valid)
 function Z:prepareG(id)
  local spec=species[id];if not spec then return true end
  if warmG.ready[id]==nil then
   local paths={};for _,part in ipairs(modelTable[spec.kind])do if part.mesh then paths[#paths+1]=part.mesh end end
   if spec.material then paths[#paths+1]=spec.material end
   for _,path in ipairs(ctx.sound:soundPathsG(spec.kind))do paths[#paths+1]='sound:'..path end
   if spec.kind=='rabbit'then paths[#paths+1]='/Game/MinecraftCreatures105/MI_MC_rabbitdesert.MI_MC_rabbitdesert';paths[#paths+1]='/Game/MinecraftCreatures105/MI_MC_rabbitdesert_hit.MI_MC_rabbitdesert_hit'end
   warmG:add(id,paths)
  end
  return warmG.ready[id]==true
 end
 function Z:prepareIslandG(key)
  local ready=true
  for id,spec in pairs(farmGround.data.species)do
   local matches=spec.island==key
   for _,alt in ipairs(spec.alternates or{})do matches=matches or alt.island==key end
   if matches and not self:prepareG(id)then ready=false end
  end
  return ready
 end
 function Z:arrivalReadyG(target)
  if target and not _G.MC_J_BASELINE then return self:prepareIslandG(target)and os.clock()-(self.lastBindG or 0)>.7 end
  return not warmG:pending()and os.clock()-(self.lastBindG or 0)>.7
 end
 function Z:pool(e)
  if self.poolReady then return end;self.poolReady=true
  local old={};_G.MC_OUT_K('GetAllActorsWithTag',UE.Object('/Script/Engine.Default__GameplayStatics'),e.player,UE.FindOrAddFName('MC77Costume'),old)
  for _,v in ipairs(old)do local ok,a=pcall(function()return v:get()end);a=ok and a or v
   if valid(a)then
    a:SetActorHiddenInGame(true);a:K2_DetachFromActor(1,1,1)
    local parts,splitParts={},{};for _,q in ipairs(a:K2_GetComponentsByClass(UE.Object('/Script/Engine.StaticMeshComponent')))do
     local ok,c=pcall(function()return q:get()end);c=ok and c or q;if c:ComponentHasTag(UE.FindOrAddFName('MC107Split'))then c:SetVisibility(false,false);splitParts[#splitParts+1]=c end;for i=1,48 do if c:ComponentHasTag(UE.FindOrAddFName('MC77Part:'..i))then parts[i]=c end end
    end
    if #parts>=1 and #self.slots<8 then self.slots[#self.slots+1]={actor=a,parts=parts,splitParts107=splitParts,root=a.RootComponent}end
   end
  end
 end
 function Z:visual(e,definition,host)
  self:pool(e)
  local selected
  for _,s in ipairs(self.slots)do if not s.host and not s.fixtureJ and valid(s.actor)then selected=s;break end end
  if not selected then
   for _,s in ipairs(self.slots)do
    if s.recall108 and s.recall108.finished and valid(s.host)and s.host.bHidden and not s.host:GetActiveActorFlag()then
     self:release(s,'inactive-pool',false);selected=s;break
    end
   end
  end
  if not selected then
   if #self.slots>=8 then

    local player=e.player:K2_GetActorLocation();local at=host:K2_GetActorLocation()
    local distance=function(p)return math.sqrt((p.X-player.X)^2+(p.Y-player.Y)^2+(p.Z-player.Z)^2)end
    local threshold=distance(at)+600;local farthest
    for _,candidate in ipairs(self.slots)do
     if valid(candidate.host)and not candidate.capturing then
      local owner=candidate.parameter:GetIndividualParameter().SaveParameter.OwnerPlayerUId
      if owner.A==0 and owner.B==0 and owner.C==0 and owner.D==0 then
       local d=distance(candidate.host:K2_GetActorLocation())
       if d>threshold then threshold=d;farthest=candidate end
      end
     end
    end
    if not farthest then return end
    self:release(farthest,'nearer-host',true);selected=farthest
   end
  end
  if not selected then
   local g=UE.Object('/Script/Engine.Default__GameplayStatics');local p=e.player:K2_GetActorLocation();local t=tf(p.X,p.Y,p.Z)
   local a=g:BeginDeferredActorSpawnFromClass(e.world,UE.Object('/Script/Engine.Actor'),t,1,nil);assert(valid(a));a=g:FinishSpawningActor(a,t)
   a.Tags={UE.FindOrAddFName('MC77Costume')};a:SetActorEnableCollision(false);a:SetActorHiddenInGame(true)
   local root=a:AddComponentByClass(UE.Object('/Script/Engine.SceneComponent'),false,tf(),false);root:SetMobility(2)
   selected={actor=a,root=root,parts={}};self.slots[#self.slots+1]=selected
  end
  local s=selected;s.kind=(definition or species.MC_Zombie).kind;s.models=modelTable[s.kind]
  s.root:SetAbsolute(false,false,false);s.root:SetRelativeScale3D(vec(1,1,1))
  
  for i,d in ipairs(s.models)do
   local c=s.parts[i]
   if not valid(c)then
    c=s.actor:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,tf(),false)
    s.parts[i]=c;c.ComponentTags={UE.FindOrAddFName('MC77Part:'..i)};c:SetMobility(2);c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false)
    assert(c:K2_AttachToComponent(s.root,UE.FindOrAddFName('None'),2,2,2,false))
   end
   c:SetAbsolute(false,false,false);assert(c:K2_AttachToComponent(s.root,UE.FindOrAddFName('None'),2,2,2,false))
   c:SetRelativeScale3D(vec(1,1,1));c:SetHiddenInGame(false,false)
   if d.mesh then
    local asset=self:asset(d.mesh);c:SetStaticMesh(asset)
    assert(valid(c.StaticMesh)and c.StaticMesh:GetAddress()==asset:GetAddress(),'MCJ mesh assignment mismatch')
    c:SetMaterial(0,c.StaticMesh:GetMaterial(0))
   else c:SetStaticMesh(nil)end
   c:SetVisibility(true,false)
   if d.parent then assert(c:K2_AttachToComponent(s.parts[d.parent],UE.FindOrAddFName('None'),2,2,2,false))end
   _G.MC_OUT_K('K2_SetRelativeLocation',c,d.location,false,ignoredHitJ(),true);_G.MC_OUT_K('K2_SetRelativeRotation',c,d.rotation,false,ignoredHitJ(),true)
   if d.equipmentJ and not d.heldK then local h=dofile(ctx.base..'/item_display66.lua').skeleton_bow.left;local p=h.Translation;_G.MC_OUT_K('K2_SetRelativeTransform',c,{Rotation=h.Rotation,Translation=vec(p.X,p.Y,p.Z-75),Scale3D=h.Scale3D},false,ignoredHitJ(),true)end
  end
  dofile(ctx.base..'/equipmentK.lua').apply(s,UE)
  for i=#s.models+1,#s.parts do s.parts[i]:SetVisibility(false,false)end
  s.bornAt=os.clock();s.speed=0;fidelity:bind(s);record('POOL',s);return s
 end
 function Z:release(s,reason,restore)
  if self.events108b then self.events108b.golem:clear(s)end
  if self.creeper103 then self.creeper103:clear(s)end
  if self.bossD then self.bossD:clear(s)end
  if self.wardenC then self.wardenC:clear(s)end
  if self.hostiles107 then self.hostiles107:clear(s)end
  passiveFlee:release(s)
  ride106:release(s)
  farmCapture:release(s)
  if valid(s.actor)then s.actor:SetActorHiddenInGame(true);s.actor:K2_DetachFromActor(1,1,1)end
  if restore and valid(s.host)and valid(s.mesh)then
   lifecycle108:mask(s) 
   if valid(s.capsule)and s.oldRadius then s.capsule:SetCapsuleSize(s.oldRadius,s.oldHalf,true)end
   if valid(s.sound)then s.sound:SetOutputBusVolume(UE.FindOrAddFName('MinecraftZombie77'),1)end
   if valid(s.ak)and s.oldAttenuation then s.ak:SetAttenuationScalingFactor(s.oldAttenuation)end
  end
  if s.address then self.hosts[s.address]=nil end
  record('RELEASE_'..reason,s)
  s.host=nil;s.address=nil;s.mesh=nil;s.parameter=nil;s.action=nil;s.capsule=nil;s.sound=nil;s.sample=nil;s.pose=nil;s.red=nil;s.lastAction=nil;s.deadAt=nil;s.lastHP=nil;s.capturing=nil
  s.recall108=nil;s.footing108=nil;s.owned108=nil;s.x4=nil
  s.ak=nil;s.oldAttenuation=nil;s.fuseStart=nil;s.fuseScale=nil;s.materialVariant=nil
 end
 function Z:mute(s)
  if valid(s.sound)then return end

  if valid(s.ak)then return end
  local ak=s.host:GetComponentByClass(UE.Object('/Script/Pal.PalAkComponent'))
  if valid(ak)then
   s.oldAttenuation=ak.AttenuationScalingFactor;ak:SetAttenuationScalingFactor(.001);s.ak=ak;record('VOICE_RADIUS_REDUCED',s);return
  end
  local c=s.host:GetComponentByClass(UE.Object('/Script/Pal.PalSoundPlayerComponent'))
  if not valid(c)then return end
  local slot=c.PalSoundSlotCache
  if valid(slot)then local sound=slot:GetSoundPlayer();if valid(sound)then sound:SetOutputBusVolume(UE.FindOrAddFName('MinecraftZombie77'),0);s.sound=sound;record('VOICE_MUTED',s)end end
 end
 function Z:bind(a,e,id)
  if self.bindFrameG==T.frameCounter or not self:prepareG(id)then return end
  self.bindFrameG=T.frameCounter;self.lastBindG=os.clock()
  local s=self:visual(e,species[id],a);if not s then return end
  if self.bossD then self.bossD:clear(s)end
  if self.wardenC then self.wardenC:clear(s)end
  if self.hostiles107 then self.hostiles107:clear(s)end
  s.species=id;s.definition=species[id];s.bowEquipped=s.kind=='skeleton';s.usingBow=false;s.bowDraw=nil
  s.host=a;s.address=a:GetAddress();s.mesh=a.Mesh;s.parameter=a.CharacterParameterComponent;s.action=a:GetActionComponent();s.capsule=a.CapsuleComponent
  s.nativeVisible=s.mesh:IsVisible();s.bornAt=os.clock();s.walk=0;s.walkWeight=0;s.pose={};s.sampleDue=0;s.soundDue=0;s.hp=nil;s.lastHP=nil;s.deadAt=nil;s.lastAction=nil;s.scale=nil
  if s.kind=='sheep'or s.kind=='cat'or s.kind=='wolf'or s.kind=='horse'then
   self.variantsJ=self.variantsJ or dofile(ctx.base..'/variantsJ.lua');local g=s.parameter:GetIndividualParameter():GetPalId().InstanceId
   local index=s.kind=='sheep'and self.variantsJ.naturalSheep(g)or(s.kind=='wolf'and self.variantsJ.seed(g,9)*3+1 or self.variantsJ.seed(g,#self.variantsJ.setsK[s.kind])+1)
   self.variantsJ.apply(s,index,UE,function(p)return self:asset(p)end)
  end
  s.lastActionObject=nil;s.attackStart=nil;s.aggressive=false;s.actionHistory={};s.attackCount103=0;s.fuseStart=nil;s.fuseScale=nil;s.materialVariant=nil
  s.lastMotionPosition=nil;s.lastMotionAt=nil;s.panicUntil=nil;s.motionHistory={};s.flee101=nil;s.lastFlee101=nil;s.passive101=nil;s.fleeRotation101=nil
  s.bossPoseD=nil;s.bossHistoryD=nil;s.fixtureD=nil;s.lookBodyT=nil;s.lookHeadT=nil;s.rootYawT=nil;s.lookTargetT=nil;s.lookAbsoluteT=true
  s.bossAppliedE=nil;s.bossDesiredE=nil;s.bossRootAppliedE=nil;s.bossWriteCursorE=nil;s.armorE=nil;s.armorMaterialsRetainedOA=nil
  s.normalMaterial105=nil;s.hitMaterial105=nil;s.coat106=nil;s.seatPartI=nil;s.seatMaterialI=nil
  if s.kind=='rabbit'and a:K2_GetActorLocation().X < -450000 then
   s.normalMaterial105=self:asset('/Game/MinecraftCreatures105/MI_MC_rabbitdesert.MI_MC_rabbitdesert')
   s.hitMaterial105='/Game/MinecraftCreatures105/MI_MC_rabbitdesert_hit.MI_MC_rabbitdesert_hit'
   for i,m in ipairs(s.models)do if m.mesh then s.x4.materials[i]:SetTextureParameterValue(UE.FindOrAddFName('Tex'),self:asset('/Game/MinecraftCreatures105/T_MC_RabbitDesert.T_MC_RabbitDesert'))end end
  end
  s.oldRadius=s.capsule:GetUnscaledCapsuleRadius();s.oldHalf=s.capsule:GetUnscaledCapsuleHalfHeight()
  s.recall108=nil;s.footing108=nil;s.owned108=lifecycle108.owned(s)
  s.fieldScaleFA=nil

  local before=a:K2_GetActorLocation();local oldHalf=s.capsule:GetScaledCapsuleHalfHeight()
  local scale=a:GetActorScale3D()
  if not s.owned108 then
   s.capsule:SetCapsuleSize((s.definition.radius or 30)/math.max(.01,math.abs(scale.X)),(s.definition.half or 97.5)/math.max(.01,math.abs(scale.Z)),true)
   before.Z=before.Z-oldHalf+s.capsule:GetScaledCapsuleHalfHeight();_G.MC_OUT_K('K2_SetActorLocation',a,before,false,ignoredHitJ(),true)
  end
  s.baseMeshScale=math.max(.01,math.abs(s.mesh.DefaultScale3D.Z))
  assert(s.root:K2_AttachToComponent(a.RootComponent,UE.FindOrAddFName('None'),2,2,2,false))

  s.root:SetAbsolute(false,true,false)
  lifecycle108:footing(s)
  _G.MC_OUT_K('K2_SetRelativeRotation',s.root,{Pitch=0,Yaw=a:K2_GetActorRotation().Yaw,Roll=0},false,ignoredHitJ(),true)
  s.mesh.VisibilityBasedAnimTickOption=0;s.mesh:SetComponentTickEnabled(true);s.mesh.bPauseAnims=false;s.mesh:SetVisibility(false,false)
  lifecycle108:mask(s)
  farmCapture:bind(s);ride106:bind(s,self);farmGround:check(a,e,id)
  self.hosts[s.address]=s;self.events108b:bind(s);self:mute(s);record('BOUND',s)
 end
 
 function Z:consider(a,e)
  if not valid(a)then return end
  local class=UE.Object('/Script/Pal.PalMonsterCharacter')
  if not a:IsA(class)then return end
  local world=a:GetWorld()
  if not valid(world)or world:GetAddress()~=e.world:GetAddress()then return end
  if not valid(a.Mesh)or not valid(a.CharacterParameterComponent)then return 'retry' end
  local p=a.CharacterParameterComponent:GetIndividualParameter()
  if not valid(p)then return 'retry' end
  local id=p:GetCharacterID():ToString();if not species[id]then return end
  local address=a:GetAddress();self.candidates[address]=a
  self.knownNames[a:GetFullName()]=true

  local at,player=a:K2_GetActorLocation(),e.player:K2_GetActorLocation()
  if (at.X-player.X)^2+(at.Y-player.Y)^2+(at.Z-player.Z)^2>6000^2 then
   if self.hosts[address]then self:release(self.hosts[address],'distance',true)end
   return
  end
  if species[id].farm or species[id].ground then farmGround:check(a,e,id,at)end
  if not self.hosts[address]and a:GetActiveActorFlag()and not a.bHidden then self:bind(a,e,id)end
 end
 function Z:resolveHosts(e)
  local holder=e.controller.BP_OtomoPalHolderComponent
  if valid(holder)then self:consider(holder:TryGetSpawnedOtomo(),e)end
  local row=table.remove(self.pending,1)
  if row and row.epoch==T.epoch then
   if self:consider(row.object,e)=='retry'and(row.attempts or 0)<10 then row.attempts=(row.attempts or 0)+1;self.pending[#self.pending+1]=row end
  end
  if self.reacquire then
   self.reacquire=nil;self.reacquireG={};for name in pairs(self.knownNames)do self.reacquireG[#self.reacquireG+1]=name end
  end
  if self.reacquireG and #self.reacquireG>0 then self:consider(StaticFindObject(table.remove(self.reacquireG)),e)end
  for _=1,3 do
   local address,a=next(self.candidates,self.candidateCursorG)
   if not address then self.candidateCursorG=nil;break end
   self.candidateCursorG=address
   if valid(a)then self:consider(a,e)else self.candidates[address]=nil;self.candidateCursorG=nil end
  end
 end
 function Z:beginAttack(s,e,now,current)
  s.attackCount103=(s.attackCount103 or 0)+1
  s.attackStart=now;record('ATTACK',s);ctx.sound:play('entity.'..(s.kind or'zombie')..'.attack',s.host:K2_GetActorLocation(),.8,e)
  if s.kind=='creeper'and current and not s.fuseStart then self.creeper103:begin(s,e,now,current);record('FUSE',s)end
 end
 function Z:sample(s,e,now)
  if not valid(s.host)or not valid(s.mesh)or not valid(s.parameter)then self:release(s,'despawn',false);return end
  if not lifecycle108:sample(s,now,function(row)farmCapture:release(row);farmCapture:bind(row);ride106:release(row);ride106:bind(row,self)end)then return end
  local hp=s.parameter:GetHP().Value;local dead=s.parameter:IsDead()

  local capturing=s.parameter:GetIsCapturedProcessing()
  if capturing~=s.capturing then s.capturing=capturing;record(capturing and'CAPTURE_HIDE'or'CAPTURE_CLEAR',s)end
  local action=valid(s.action)and s.action:GetCurrentActionType(false)or 0

  local current=valid(s.action)and s.action:GetCurrentAction()or nil
  local actionObject=valid(current)and current:GetAddress()or 0
  local actionName=valid(current)and current:GetClass():GetFullName()or ''
  local attacking=action==10 or action==11 or action==12 or actionName:find((s.definition or species.MC_Zombie).attack,1,true)~=nil
  local p=s.host:K2_GetActorLocation()
  if not s.owned108 and(s.kind=='warden'or s.definition.bossD)and now-s.bornAt>1 then
   local scale=s.host:GetActorScale3D();local half=s.capsule:GetScaledCapsuleHalfHeight()
   if not s.fieldScaleFA or math.abs(half-s.definition.half)>1 or math.abs(scale.Z-1)>.01 then
    p.Z=p.Z-half;s.host:SetActorScale3D({X=1,Y=1,Z=1});s.capsule:SetCapsuleSize(s.definition.radius,s.definition.half,true)
    p.Z=p.Z+s.capsule:GetScaledCapsuleHalfHeight();_G.MC_OUT_K('K2_SetActorLocation',s.host,p,false,ignoredHitJ(),true)
    s.fieldScaleFA=true;farmGround.seen[s.address]=nil;record('FIELD_BODY_NORMALIZED_FA',s)
   end
  end
  if s.definition and(s.definition.farm or s.definition.ground or s.definition.bossD)then farmGround:check(s.host,e,s.species,p)end
  if action~=s.lastAction or actionObject~=s.lastActionObject then
   s.actionHistory=s.actionHistory or {};s.actionHistory[#s.actionHistory+1]={at=now,type=action,name=actionName,object=actionObject}
   if #s.actionHistory>24 then table.remove(s.actionHistory,1)end
    if attacking and not dead and not capturing and s.attackObject108b~=actionObject and s.kind~='irongolem' then
    self:beginAttack(s,e,now,current)
   end
   s.lastAction=action;s.lastActionObject=actionObject
  end
  self.hostiles107:sample(s,e,now,hp,dead,capturing,p,attacking)
  if not dead and not capturing then self.events108b:golemAI(s)end
  passiveFlee:sample(s,e,now,hp,dead,capturing,p)
  if UE.customPalsA and UE.customPalsA.motion then UE.customPalsA.motion:sample(s.host,e,s.species,s)end
  s.aggressive=attacking;s.usingBow=s.bowEquipped and attacking
  if s.lastHP and hp<s.lastHP then s.hitUntil=now+.5;s.panicUntil=now+(s.flee101 and 5 or 3);ctx.sound:play('entity.'..(s.kind or 'zombie')..'.hurt',p,1,e);record('HURT',s)end
  if dead and not s.deadAt then s.deadAt=now;ctx.sound:play('entity.'..(s.kind or 'zombie')..'.death',p,1,e);record('FAINT',s)
  elseif not dead and s.deadAt then s.deadAt=nil;record('RECOVER',s)end
  s.lastHP=hp
  local v=s.host:GetVelocity();local velocity=math.sqrt(v.X*v.X+v.Y*v.Y)
  local measured=0;local previous=s.lastMotionPosition;local elapsed=now-(s.lastMotionAt or now)
  if previous and elapsed>0 and elapsed<.75 then
   local distance=math.sqrt((p.X-previous.X)^2+(p.Y-previous.Y)^2)
   if distance<500 then measured=distance/elapsed end 
  end
  s.lastMotionPosition=vec(p.X,p.Y,p.Z);s.lastMotionAt=now
  s.speed=dead and 0 or math.max(velocity,measured)
  local reaction=actionName:lower()
  s.panic=s.definition and s.definition.farm and(now<(s.panicUntil or 0)or reaction:find('escape',1,true)~=nil or reaction:find('flee',1,true)~=nil or reaction:find('damage',1,true)~=nil)
  s.sample={hp=hp,dead=dead,action=action,actionName=actionName,speed=s.speed,velocity=velocity,measured=measured,panic=s.panic,capturing=capturing}
  s.motionHistory=s.motionHistory or{};s.motionHistory[#s.motionHistory+1]={at=now,speed=s.speed,walk=s.walk,hp=hp,panic=s.panic}
  if #s.motionHistory>30 then table.remove(s.motionHistory,1)end
  if s.definition and valid(e.player)then
   local q=e.player:K2_GetActorLocation();local dx,dy=q.X-p.X,q.Y-p.Y;local distance=math.sqrt(dx*dx+dy*dy)
   local yaw=(math.deg(math.atan(dy,dx))-s.host:K2_GetActorRotation().Yaw+180)%360-180
   s.headYaw=distance<600 and math.max(-75,math.min(75,yaw))or 0
   s.lookTargetT=distance<600 and math.deg(math.atan(dy,dx))or nil
   s.headPitch=distance<600 and math.max(-25,math.min(25,math.deg(math.atan(q.Z-p.Z,math.max(1,distance)))))or 0
  end
  local ratio=math.max(0,math.min(1,math.abs(s.mesh.RelativeScale3D.Z)/s.baseMeshScale))
  local rootScale=s.host:GetActorScale3D();local scale=vec(ratio/math.max(.01,math.abs(rootScale.X)),ratio/math.max(.01,math.abs(rootScale.Y)),ratio/math.max(.01,math.abs(rootScale.Z)))
  if not s.scale or math.abs(s.scale.X-scale.X)+math.abs(s.scale.Z-scale.Z)>.005 then s.root:SetRelativeScale3D(scale);s.scale=scale;record('SCALE',s)end
  if s.mesh:IsVisible()then s.mesh:SetVisibility(false,false)end
  s.mesh.VisibilityBasedAnimTickOption=0
  s.actor:SetActorHiddenInGame(capturing or ratio<.01 or(s.teleport107 and now<s.teleport107.untilAt)or false)
  if now>=s.soundDue then s.soundDue=now+2;self:mute(s)end
  if not dead and s.kind~='creeper'and now>=(s.ambientAt or 0)then s.ambientAt=now+8+math.random()*6;ctx.sound:play('entity.'..(s.kind or 'zombie')..'.ambient',p,.5,e)end
  if dead or capturing then self.creeper103:clear(s)end
 end
 function Z:animate(s,now,dt)
  local target=math.min((s.speed or 0)/(s.panic and 180 or 350),1);s.walkWeight=s.walkWeight+.4*(target-s.walkWeight);s.walk=s.walk+s.walkWeight*dt*(s.panic and 32 or 20)
  local death=s.deadAt and not s.split107 and motion.death(now-s.deadAt)or 0
  local hostYaw=s.host:K2_GetActorRotation().Yaw
  local bodyTarget=s.flee101 and s.flee101.yaw or hostYaw
  local headTarget=s.lookTargetT or(hostYaw+(s.headYaw or 0))
  if not s.flee101 and(s.speed or 0)<5 and math.abs(lookT.wrap(headTarget-bodyTarget))>75 then bodyTarget=headTarget end
  s.lookBodyT,s.lookHeadT=lookT.couple(s.lookBodyT or bodyTarget,s.lookHeadT or bodyTarget,bodyTarget,headTarget,dt,75)
  local rootYaw=s.lookBodyT
  if s.deathAngle~=death or not s.rootYawT or math.abs(lookT.wrap(rootYaw-s.rootYawT))>.01 then
   rotateRootOA(s.root,{Pitch=0,Yaw=rootYaw,Roll=death});s.deathAngle=death;s.rootYawT=rootYaw
  end
   fidelity:animate(s,now,dt)
 end
 function Z:hideAll()
  for _,s in ipairs(self.slots)do if valid(s.actor)then s.actor:SetActorHiddenInGame(true)end end
 end

 local registered={}
 for _,definition in pairs(species)do if not registered[definition.host]then
 registered[definition.host]=true
 NotifyOnNewObject('/Game/Pal/Blueprint/Character/Monster/PalActorBP/'..definition.host..'/BP_'..definition.host..'.BP_'..definition.host..'_C',function(object)
  if #Z.pending<64 then Z.pending[#Z.pending+1]={object=object,epoch=T.epoch}end
 end)
 NotifyOnNewObject((definition.bossD and'/Game/MinecraftBossD/'or definition.host=='Gorilla'and'/Game/MinecraftCreatures105/'or definition.host=='Eagle'and'/Game/MinecraftParrot103/'or'/Game/MinecraftHosts99/')..'BP_MC_Hidden_'..definition.host..'.BP_MC_Hidden_'..definition.host..'_C',function(object)
  if #Z.pending<64 then Z.pending[#Z.pending+1]={object=object,epoch=T.epoch}end
 end)
 end end
 T.onEpoch('zombie77',function()
  farmGround:reset()
  warmG=dofile(ctx.base..'/asset_queueG.lua')(warmLoadG,valid);Z.lastBindG=nil;Z.bindFrameG=nil;Z.candidateCursorG=nil;Z.reacquireG=nil
  Z.slots={};Z.hosts={};Z.assets={};Z.poolReady=nil;Z.pending={};Z.candidates={};Z.reacquire=true
  Z.hostDue=0;Z.due=0;Z.readyAt=nil;Z.at=nil;Z.visualAtT=nil
 end)
 T.frame('zombie77',function()
  local now=os.clock()
  if not ctx.ready()then Z.readyAt=nil;return end
  warmG:tick()
  if not Z.readyAt then Z.readyAt=now;return end
  if now-Z.readyAt<10 then return end
  if #Z.events108b.pending>0 then local e=ctx.environment();if e then Z.events108b:drain(e,now)end end
  T.measure('boss:part-writes',Z.bossD.flush,Z.bossD)

  local coarse=now>=Z.due
  if coarse then Z.at=now;Z.due=now+.1 end
  local dt=math.min(.1,math.max(0,now-(Z.visualAtT or now)));Z.visualAtT=now
  local e=ctx.environment();if not e then return end
  if not Z.gateEpoch or Z.gateEpoch~=T.epoch then Z.gateEpoch=T.epoch;record('GATE_10S')end
  if coarse then Z:pool(e);if Z.projectiles then Z.projectiles:tick(e)end end
  for _,s in ipairs(Z.slots)do if s.host then
   if coarse and now>=s.sampleDue then s.sampleDue=now+.2;Z:sample(s,e,now)end
   if coarse and s.host and s.definition.bossD then T.measure('boss:combat',Z.bossD.tick,Z.bossD,s,e,now)end
   if coarse and s.host and s.kind=='warden'then Z.wardenC:tick(s,e,now)end
   if s.host and not lifecycle108:animate(s,now)then
    if coarse and s.kind=='irongolem'then Z.events108b.golem:tick(s,e,now)end
    Z:animate(s,now,dt)
    if coarse then Z.hostiles107:animate(s,e,now);if s.kind=='creeper'then Z.creeper103:tick(s,e,now)end end
   end
  end end
  if now>=Z.hostDue then Z.hostDue=now+.1;T.measure('costume:discovery',Z.resolveHosts,Z,e)end
 end)
 Z.fidelityJ=fidelity;Z.modelsJ=modelTable;Z.speciesJ=species
 Z.bossFA=dofile(ctx.base..'/bossFA.lua')(ctx,Z)
 Z.bossD=dofile(ctx.base..'/bossD.lua')(ctx,Z)
 Z.wardenC=dofile(ctx.base..'/wardenC.lua')(ctx,Z)
 Z.events108b=dofile(ctx.base..'/costume_events108b.lua')(ctx,Z)
 Z.hostiles107=dofile(ctx.base..'/hostiles107.lua')(ctx,Z)
 Z.farmGround=farmGround
 Z.creeper103=dofile(ctx.base..'/creeper103.lua')(ctx,Z)
 Z.projectiles=dofile(ctx.base..'/pal_projectiles91.lua')(ctx,Z)
 return Z
end
