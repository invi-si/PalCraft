-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
 local T=dofile(ctx.base..'/timers.lua');local S={enabled=ctx.config.steve==true,requestedFirstPerson=ctx.config.steve_first_person==true}
 local skin=dofile(ctx.base..'/steve_skin.lua')(ctx)
 S.library71=dofile(ctx.base..'/skins71.lua')(ctx)
 local rigid=dofile(ctx.base..'/steve_pose.lua')(ctx)
 local motion=dofile(ctx.base..'/steve_motion.lua')
 local foodItems=dofile(ctx.base..'/item_registry.lua').items
 local UE,valid,log=ctx.UE,ctx.valid,ctx.log
 local attachments108c=dofile(ctx.base..'/attachment108c.lua')(ctx)
 S.mountCamera102=dofile(ctx.base..'/mount_camera102.lua')(ctx);UE.mountCamera102=S.mountCamera102
 local function asset(path)
  S.assetCacheZ3=S.assetCacheZ3 or{};local a=S.assetCacheZ3[path];if valid(a)then return a end
  local package,name=path:match('^(.*)%.([^%.]+)$');if not package then package=path;name=path:match('([^/]+)$')end
  a=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(package),AssetName=UE.FindOrAddFName(name)})
  if not valid(a)then a=UE.Object(path)end
  S.assetCacheZ3[path]=a
  assert(valid(a),'Steve asset unavailable '..path);return a
 end
 S.elytra104=dofile(ctx.base..'/elytra104.lua')(ctx,motion,asset);UE.elytra104=S.elytra104
 local held66=dofile(ctx.base..'/held66.lua')(ctx,motion,asset)
 S.held66=held66
 local function vec(v)return{X=v.X,Y=v.Y,Z=v.Z}end
 local nativeParts65c={}
 local function parts(env)local p=env.player;nativeParts65c[1]=p.Mesh;nativeParts65c[2]=p.HeadMesh;nativeParts65c[3]=p.HairMesh;nativeParts65c[4]=p.HairAttachAccessory;return nativeParts65c end
 function S:retainSkin71(texture,mask)
  if not texture then return end
  self.skinHolders71=self.skinHolders71 or{}
  for i,t in ipairs({texture,mask})do
   local h=self.skinHolders71[i]
   if not valid(h)then h=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.Image'),UE.GetGameInstance());self.retain71(h);self.skinHolders71[i]=h end
   h:SetBrushFromTexture(t,false)
  end
 end
 function S:preload(retain)
  if not self.enabled then return end
  self.choice,self.skinWarning71=self.library71:saved()
  if not self.choice then self.choice={format='wide',file='steve-wide.png',default71=true}end
  self.preloaded={}
   
   for _,path in ipairs({self:meshPath(false),self:meshPath(true),'/Game/MinecraftSteve/Task27/M_MC27SkinBase.M_MC27SkinBase','/Game/MinecraftSteve/Task27/M_MC27SkinOverlay.M_MC27SkinOverlay'})do local o=asset(path);self.preloaded[#self.preloaded+1]=o;retain(o)end
  self.retain71=retain
  if self.choice.custom71 then
   local ok,t,m=pcall(self.library71.load,self.library71,{player=UE.GetGameInstance()},self.choice)
   if ok then self.titleTexture,self.titleMask71=t,m;self:retainSkin71(t,m)
   else self.skinWarning71=t;self.choice={format='wide',file='steve-wide.png',default71=true};self.titleTexture,self.titleMask71=nil,nil end
  end
  log('MC71_SKIN_RESTORE file='..self.choice.file..' model='..self.choice.format..' custom='..tostring(self.choice.custom71==true)..' fallback='..tostring(self.skinWarning71~=nil))
  log('MC51_STEVE_PRELOADED title=true assets='..#self.preloaded)
 end
 function S:early(env)
  if not self.enabled or not valid(env.player)or not valid(env.player.Mesh)or not valid(env.player.Mesh:GetAnimInstance())then return end
  if self.state and(self.state.player~=env.player:GetAddress()or self.state.epoch~=ctx.epoch())then self:clear(nil,false)end
  if not self.state then self:apply(env);self.earlyState=true;log('MC51_STEVE_EARLY epoch='..ctx.epoch())end
   self:maskNative(env)
 end
 local function boom(env)
  if valid(S.boom61)and S.boomPlayer61==env.player:GetAddress()then return S.boom61 end
  S.boom61=UE.Object(env.player:GetFullName():match('^%S+ (.+)$')..'.CameraBoom');S.boomPlayer61=env.player:GetAddress();return S.boom61
 end
 local offsetNames={'WalkCameraOffset','HipShootCameraOffset','AimCameraOffset','AirCameraOffset','AirHipShootCameraOffset','AirAimCameraOffset','CrouchCameraOffset','CrouchHipShootCameraOffset','CrouchAimCameraOffset','WaterCameraOffset','WaterHipShootCameraOffset','WaterAimCameraOffset','FlyCameraOffset','FlyHipShootCameraOffset','FlyAimCameraOffset'}
 function S:firstPersonCamera(env,enable)
  local riding=env.controller:IsRiding()
  if self.mountCamera102.lease and(not riding or(not enable and not self.mountCamera102.lease.customGround))then self.mountCamera102:release(not riding and'dismount'or'F5-third-person',riding)end
  if riding then enable=false end
  local b=boom(env);if not valid(b)then return end
  if enable and not self.fpCamera then
   self:camera(env,false);local saved={offsets={},target=vec(b.TargetOffset),socket=vec(b.SocketOffset),arm=b.TargetArmLength}
   for _,name in ipairs(offsetNames)do saved.offsets[name]=vec(b:GetPropertyValue(name))end
   local head=env.player.Mesh:GetSocketLocation(UE.FindOrAddFName('Head'));local origin=b:K2_GetComponentLocation()
   for _,name in ipairs(offsetNames)do local v=b:GetPropertyValue(name);v.X=8;v.Y=0;v.Z=head.Z-origin.Z+10;b:SetPropertyValue(name,v)end
   b.TargetOffset={X=0,Y=0,Z=0};b:SetCameraLengthScale(UE.FindOrAddFName('MC27FirstPerson'),.001);b:ResetCameraInterp();self.fpCamera=saved
   log('MC27_FIRST_PERSON_CAMERA active=true collision_preserved=true')
  elseif not enable and self.fpCamera then
   for name,v in pairs(self.fpCamera.offsets)do b:SetPropertyValue(name,v)end
   b.TargetOffset=self.fpCamera.target;b.SocketOffset=self.fpCamera.socket;b:SetCameraLengthScale(UE.FindOrAddFName('MC27FirstPerson'),1)

   b.TargetArmLength=self.fpCamera.arm;b:ResetCameraInterp();self.fpCamera=nil
   log('MC27_FIRST_PERSON_CAMERA active=false')
  end

  if enable and self.fpCamera and self.mountCamera102.footRecalibrate and os.clock()>=self.mountCamera102.footRecalibrate then
   self.mountCamera102.footRecalibrate=nil
   local head=env.player.Mesh:GetSocketLocation(UE.FindOrAddFName('Head'));local origin=b:K2_GetComponentLocation()
   for _,name in ipairs(offsetNames)do local v=b:GetPropertyValue(name);v.X=8;v.Y=0;v.Z=head.Z-origin.Z+10;b:SetPropertyValue(name,v)end
   b:ResetCameraInterp();log('MC102_ONFOOT_CAMERA_REFIT')
  end
 end
 function S:perspective(env,enabled)
   self.requestedFirstPerson=enabled;if self.state then self:maskNative(env);self:firstPersonCamera(env,enabled);self:tick(env)end
 end
 function S:setSkin(env,format,file)
  
  local choice=skin.choice(format,file);local texture=skin.load(env,choice)
  self:clear(env,true);self.choice=choice;self.titleTexture=texture;self.titleMask71=nil;self.pendingTexture=texture;self:apply(env);self:tick(env)
  log('MC27_SKIN_SELECTED format='..choice.format..' file='..choice.file)
 end
 function S:selectSkin71(env,file,model)
  local ok,choice,texture,mask=pcall(function()
   if not file then return {format='wide',file='steve-wide.png',default71=true}end
   local c=self.library71:choice(model,file);local t,m=self.library71:load(env,c);return c,t,m
  end)
  local err
  if not ok then err=tostring(choice);choice={format='wide',file='steve-wide.png',default71=true};texture,mask=nil,nil end
  self:retainSkin71(texture,mask)
  self.choice=choice;self.titleTexture=texture;self.titleMask71=mask
  if valid(self.mesh)and self.state and self.state.player==env.player:GetAddress()then

   self.texture=texture or asset('/Game/MinecraftSteve/Authoring/steve-wide-local.steve-wide-local')
   self.mesh:SetSkinnedAssetAndUpdate(asset(self:meshPath(self.firstPerson)),true)
   skin.apply(self.mesh,self.texture,asset,mask);self.hideLeft=nil;held66.token=nil
  else self:apply(env)end
  self:tick(env)
  self.library71:remember(choice)
  log('MC71_SKIN_APPLIED file='..choice.file..' model='..choice.format..' default='..tostring(choice.default71==true)..' fallback='..tostring(err~=nil))
  return err==nil,err
 end
 function S:meshPath(arms)
  local format=self.choice and self.choice.format or 'wide';local cut=self.choice and not self.choice.custom71 and self.choice.file=='steve-'..format..'.png';local name=(cut and'SK_MC70'or'SK_MC27')..(format=='slim'and'Slim'or'Wide')..(arms and'Arms'or'Body')
  return (cut and'/Game/MinecraftTask70/'or'/Game/MinecraftSteve/Task27/')..name..'.'..name
 end
 function S:clearViewWeapons(env,touch)
  if touch then for _,v in ipairs(self.viewWeapons or{})do
   local source=attachments108c:source(v);if source then source:SetOwnerNoSee(v.ownerNoSee);source:SetVisibility(v.visible,false);if v.tick~=nil then source.VisibilityBasedAnimTickOption=v.tick end end
   if valid(v.component)then if v.component==self.mcViewStatic then v.component:SetVisibility(false,false)else v.component:K2_DestroyComponent(env.player)end end
  end end;self.viewWeapons=nil;self.viewWeaponToken=nil
 end
 function S:attachmentVisibility(env,touch)
  if touch then for _,v in ipairs(self.attachmentMasks or{})do local source=attachments108c:source(v);if source then source:SetOwnerNoSee(v.ownerNoSee);source:SetVisibility(v.visible,false)end end end
  self.attachmentMasks=nil;self.attachmentToken=nil;self.attachmentRefreshAt=nil;self.attachmentPendingG2=nil
 end
 function S:hideFirstPersonAttachments(env,weapon,selected)
  local selectedItem=selected.id or''
  local mcHeld=selectedItem:sub(1,3)=='MC_'
  local address=valid(weapon)and weapon:GetAddress()or 0;local riding=env.controller:IsRiding()
  local key=self.attachmentKeyZ3
  if not key or key.address~=address or key.item~=selectedItem or key.slot~=ctx.phaseA.selected or key.riding~=riding then
   key={address=address,item=selectedItem,slot=ctx.phaseA.selected,riding=riding,token=tostring(address)..':'..selectedItem..':'..tostring(ctx.phaseA.selected)..':'..tostring(riding)};self.attachmentKeyZ3=key
  end
  local token=key.token;local now=os.clock()

  if token==self.attachmentToken and self.firstPerson==self.attachmentPerspective65c then
   if not self.attachmentRefreshAt or now<self.attachmentRefreshAt then return end
   
   if not self.attachmentPendingG2 then self.attachmentRefreshCount74=(self.attachmentRefreshCount74 or 0)+1 end
   self.attachmentRefreshAt=self.attachmentRefreshCount74<2 and now+.5 or nil
   for _,v in ipairs(self.attachmentMasks or{})do local source=attachments108c:source(v);if source then source:SetOwnerNoSee(true);source:SetVisibility(false,false)end end
  else
   self:attachmentVisibility(env,true);self.attachmentToken=token;self.attachmentPerspective65c=self.firstPerson
   self.attachmentRefreshAt=now+.5;self.attachmentRefreshCount74=0
  end
  self.attachmentPendingG2=nil
  local children={};env.player.RootComponent:GetChildrenComponents(true,children);self.attachmentMasks=self.attachmentMasks or{}
  local held=ctx.phaseC:handVisual()
  local known={};for _,v in ipairs(self.attachmentMasks)do if valid(v.source)then known[v.source:GetAddress()]=true end end
  for _,p in ipairs(children)do local ok,c=pcall(function()return p:get()end);c=ok and c or p
   if valid(c)and c:IsA(UE.Object('/Script/Engine.MeshComponent'))and c:GetAddress()~=self.mesh:GetAddress()and c:GetAddress()~=self.mcViewAddress66 and(not valid(self.foodCard)or c:GetAddress()~=self.foodCard:GetAddress())then
    local owner=c:GetOwner()
    local clone=false;for _,v in ipairs(self.viewWeapons or{})do if valid(v.component)and v.component:GetAddress()==c:GetAddress()then clone=true;break end end
    local selected=false
    if valid(owner)then
     local name=owner:GetClass():GetFName():ToString()
     local socket=c:GetAttachSocketName():ToString():lower()
     local holstered=name:find('BackWeapon',1,true)~=nil or socket:find('back',1,true)~=nil and name:find('Weapon',1,true)~=nil
     selected=self.firstPerson and(owner:GetAddress()==env.player:GetAddress()or(valid(weapon)and owner:GetAddress()==weapon:GetAddress())or holstered or name:match('^BP_Glider_')~=nil or(valid(held)and c:GetAddress()==held:GetAddress()))or holstered or(mcHeld and valid(weapon)and owner:GetAddress()==weapon:GetAddress())
    end
    if selected and not clone and not known[c:GetAddress()]then
     local source,name,deferred=attachments108c:resolve(c,nil,true)
     if deferred then self.attachmentPendingG2=true;self.attachmentRefreshAt=now end
     if source then self.attachmentMasks[#self.attachmentMasks+1]={source=source,sourceName=name,sourceAddress109=source:GetAddress(),concrete109=true,ownerNoSee=source.bOwnerNoSee,visible=source:IsVisible()};source:SetOwnerNoSee(true);source:SetVisibility(false,false)end
    end
   end
  end
  local signature=tostring(self.firstPerson)..':'..#self.attachmentMasks;if self.maskSignature63~=signature then self.maskSignature63=signature;log('MC63_NATIVE_ATTACHMENTS_MASKED first_person='..tostring(self.firstPerson)..' count='..#self.attachmentMasks)end
 end
 function S:updateViewWeapons(env,weapon)
  local selected=ctx.items:hotbar(env,ctx.phaseA.selected);local def=foodItems[selected.id];local food=def and def.category=='consumable'and def.hunger and selected.count>0
  local bow=valid(weapon)and weapon:GetClass():GetFName():ToString():lower():find('bow',1,true)~=nil
  local camera=env.controller.PlayerCameraManager;local rotation=camera:GetCameraRotation()
  local yaw,pitch=math.rad(rotation.Yaw),math.rad(rotation.Pitch)
  local eye=camera:GetCameraLocation();local origin=env.player.Mesh:K2_GetComponentLocation()
  local forward={X=math.cos(yaw)*math.cos(pitch),Y=math.sin(yaw)*math.cos(pitch),Z=math.sin(pitch)}
  local right={X=-math.sin(yaw),Y=math.cos(yaw),Z=0}
  local up={X=-math.cos(yaw)*math.sin(pitch),Y=-math.sin(yaw)*math.sin(pitch),Z=math.cos(pitch)}
  local handStatus=ctx.phaseC:handStatus()
  local hand66=ctx.phaseC:handVisual()
  self.itemOnly66=false
  if food and valid(self.foodCard)then hand66=self.foodCard;handStatus={id=selected.id,category='food'}end
  local empty66=not valid(hand66)and not food and(not selected.id or selected.id==''or not valid(weapon))
  if(valid(hand66)or(self.firstPerson and empty66))and held66:update(self,env,hand66,handStatus,rigid,rotation,eye)then return end
  local held=ctx.phaseC:handVisual();local melee=not food and handStatus.category and handStatus.category~='bow'
  local empty=not food and not valid(held)and not valid(weapon)
  local now=os.clock();local pressed=melee and env.controller:IsInputKeyDown({KeyName=UE.FindOrAddFName('LeftMouseButton')})
  if pressed and(not self.swingAt or now-self.swingAt>=.55)then self.swingAt=now;log('MC33_FP_SWING native_gameplay_unchanged=true')end
  local swing=self.swingAt and math.max(0,math.min(1,(now-self.swingAt)/.45))or 1
  local wave=swing<1 and math.sin(swing*math.pi)or 0
  self.viewSwing=wave
  if self.firstPerson then
   local size=empty and .4 or .3
   self.mesh:SetWorldScale3D({X=size,Y=size,Z=size});_G.MC_OUT_K('K2_SetWorldLocation',self.mesh,origin,false,ignoredHitJ(),true)
   local hand=self.mesh:GetSocketLocation(UE.FindOrAddFName('hand_r'))
   local down=empty and 40 or 38;local distance=empty and 46 or 60
   local grip={X=eye.X+forward.X*distance+right.X*26-up.X*down,Y=eye.Y+forward.Y*distance+right.Y*26-up.Y*down,Z=eye.Z+forward.Z*distance-up.Z*down}
   self.viewGrip=grip
   _G.MC_OUT_K('K2_SetWorldLocation',self.mesh,{X=origin.X+grip.X-hand.X,Y=origin.Y+grip.Y-hand.Y,Z=origin.Z+grip.Z-hand.Z},false,ignoredHitJ(),true)
  end
  local held=ctx.phaseC:handVisual();local token=valid(held)and(tostring(held:GetAddress())..':'..tostring(handStatus.id))or(valid(weapon)and weapon:GetAddress()or 0)
  if token~=self.viewWeaponToken then
   self:clearViewWeapons(env,true);self.viewWeaponToken=token;self.viewWeapons={};local sources={}
   if valid(held)then sources={held}
   elseif valid(weapon)and weapon:GetItemId().StaticId:ToString()==selected.id then for _,v in ipairs(weapon:K2_GetComponentsByClass(UE.Object('/Script/Engine.MeshComponent')))do local ok,c=pcall(function()return v:get()end);c=ok and c or v;if valid(c)then
    local visible=c:IsVisible();for _,mask in ipairs(self.attachmentMasks or{})do if valid(mask.source)and mask.source:GetAddress()==c:GetAddress()then visible=mask.visible;break end end
    if visible then sources[#sources+1]=c end
   end end end
   local identity={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
   for _,src in ipairs(sources)do local component
    if src:IsA(UE.Object('/Script/Engine.StaticMeshComponent'))and valid(src.StaticMesh)then
     if src==held then
      if not valid(self.mcViewStatic)then self.mcViewStatic=env.player:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),true,identity,false)end;component=self.mcViewStatic
     else component=env.player:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),true,identity,false)end;component:SetStaticMesh(src.StaticMesh)
    elseif src:IsA(UE.Object('/Script/Engine.SkeletalMeshComponent'))and valid(src:GetSkeletalMeshAsset())then
     component=env.player:AddComponentByClass(UE.Object('/Script/Engine.SkeletalMeshComponent'),true,identity,false);component:SetSkeletalMeshAsset(src:GetSkeletalMeshAsset());component:SetLeaderPoseComponent(src,true,false)
    end
    if valid(component)then
     for i=0,src:GetNumMaterials()-1 do component:SetMaterial(i,src:GetMaterial(i))end
     component:SetCollisionEnabled(0);component:SetOnlyOwnerSee(self.firstPerson);component:SetCastShadow(false)
     local tick;if src:IsA(UE.Object('/Script/Engine.SkeletalMeshComponent'))then tick=src.VisibilityBasedAnimTickOption;src.VisibilityBasedAnimTickOption=0 end
     local socket='weapon_r';local parent=src
     for _=1,8 do
      if not valid(parent)then break end;local name=parent:GetAttachSocketName():ToString()
      if name=='weapon_r'or name=='weapon_l'or name=='hand_r'or name=='hand_l'then socket=name;break end
      parent=parent:GetAttachParent()
     end
     local hand=socket:sub(-2)=='_l'and'hand_l'or'hand_r'
     self.viewWeapons[#self.viewWeapons+1]={source=src,component=component,gripSocket=socket,handBone=hand,ownerNoSee=src.bOwnerNoSee,visible=src:IsVisible(),tick=tick,rotation=src:K2_GetComponentRotation(),cameraYaw=rotation.Yaw,cameraPitch=rotation.Pitch};src:SetOwnerNoSee(true);src:SetVisibility(false,false)
     log('MC52_ITEM_GRIP source='..socket..' rigid='..hand)
    end
   end
   log('MC27_VIEW_WEAPON_READY count='..#self.viewWeapons..' native_gameplay_unchanged=true')
  end
  for _,v in ipairs(self.viewWeapons or{})do if valid(v.source)and valid(v.component)then
   v.source:SetVisibility(false,false)
   v.component:SetVisibility(not food,false)
   local target=self.mesh:GetSocketLocation(UE.FindOrAddFName(v.handBone));local source=env.player.Mesh:GetSocketLocation(UE.FindOrAddFName(v.gripSocket))
   local p=v.source:K2_GetComponentLocation();local location={X=p.X+target.X-source.X,Y=p.Y+target.Y-source.Y,Z=p.Z+target.Z-source.Z}
   local r=v.source:K2_GetComponentRotation();local size=.75
   if self.firstPerson and melee then
    local grip=self.viewGrip
    location={X=grip.X+forward.X*8-right.X*(10+wave*10)+up.X*(20+wave*5),Y=grip.Y+forward.Y*8-right.Y*(10+wave*10)+up.Y*(20+wave*5),Z=grip.Z+forward.Z*8+up.Z*(20+wave*5)}

    r={Pitch=-15-wave*25,Yaw=rotation.Yaw+90,Roll=25-rotation.Pitch-wave*30};size=.45
   elseif self.firstPerson and handStatus.block then
    location={X=eye.X+forward.X*60+right.X*28-up.X*24,Y=eye.Y+forward.Y*60+right.Y*28-up.Y*24,Z=eye.Z+forward.Z*60-up.Z*24}
    r={Pitch=-15,Yaw=rotation.Yaw+40,Roll=8-rotation.Pitch};size=.64
   elseif not self.firstPerson then
    local from=env.player.Mesh:GetSocketTransform(UE.FindOrAddFName(v.gripSocket),0);local to=self.mesh:GetSocketTransform(UE.FindOrAddFName(v.handBone),0)
    local function quat(q)return{X=q.X,Y=q.Y,Z=q.Z,W=q.W}end
    local delta=motion.mul(quat(to.Rotation),motion.inv(quat(from.Rotation)));local src=v.source:K2_GetComponentToWorld()
    location=motion.add({X=to.Translation.X,Y=to.Translation.Y,Z=to.Translation.Z},motion.rotate(delta,motion.sub({X=src.Translation.X,Y=src.Translation.Y,Z=src.Translation.Z},{X=from.Translation.X,Y=from.Translation.Y,Z=from.Translation.Z})))
    local scale=src.Scale3D
    _G.MC_OUT_K('K2_SetWorldTransform',v.component,{Rotation=motion.mul(delta,quat(src.Rotation)),Translation=location,Scale3D={X=scale.X*.75,Y=scale.Y*.75,Z=scale.Z*.75}},false,ignoredHitJ(),true)
   end
   if self.firstPerson then
    _G.MC_OUT_K('K2_SetWorldLocation',v.component,location,false,ignoredHitJ(),true);_G.MC_OUT_K('K2_SetWorldRotation',v.component,r,false,ignoredHitJ(),true)
    local scale=v.source:K2_GetComponentToWorld().Scale3D;v.component:SetWorldScale3D({X=scale.X*size,Y=scale.Y*size,Z=scale.Z*size})
   end
  end end
 end
 function S:camera(env,enable)
  local b=boom(env);if not valid(b)then return end
  if enable and not self.cameraSaved then
   self.cameraSaved={node=b,original=vec(b:GetPropertyValue('AimCameraOffset'))}
   local v=b:GetPropertyValue('AimCameraOffset');v.X=self.cameraSaved.original.X;v.Y=self.cameraSaved.original.Y+40;v.Z=self.cameraSaved.original.Z+40;b:SetPropertyValue('AimCameraOffset',v)
   log('MC26_STEVE_CAMERA_APPLIED right=40 up=40 collision_preserved=true')
  elseif not enable and self.cameraSaved then
   local saved=self.cameraSaved;local v=b:GetPropertyValue('AimCameraOffset');v.X=saved.original.X;v.Y=saved.original.Y;v.Z=saved.original.Z;b:SetPropertyValue('AimCameraOffset',v);self.cameraSaved=nil
   log('MC26_STEVE_CAMERA_RESTORED')
  end
 end
 function S:clear(env,touch)
  if env then self.mountCamera102:release('clear',false)else self.mountCamera102:forget()end
  if touch then local alive=ctx.environment();touch=alive~=nil and env~=nil and alive.player:GetAddress()==env.player:GetAddress()end
  if self.elytra104 then self.elytra104:clear(touch and env~=nil)end
  if touch and self.state and env and env.player:GetAddress()==self.state.player then
   if valid(self.foodCard)then self.foodCard:K2_DestroyComponent(env.player)end
     self:clearViewWeapons(env,true)
     if valid(self.mcViewStatic)then self.mcViewStatic:K2_DestroyComponent(env.player)end
   self:attachmentVisibility(env,true)
   self:firstPersonCamera(env,false);self:camera(env,false)
   if valid(self.mesh)then self.mesh:K2_DestroyComponent(env.player)end
   env.player.Mesh.VisibilityBasedAnimTickOption=self.state.tick
   if self.state.tickEnabled~=nil then env.player.Mesh:SetComponentTickEnabled(self.state.tickEnabled)end
   if self.state.pauseAnims~=nil then env.player.Mesh.bPauseAnims=self.state.pauseAnims end
   for _,p in ipairs(parts(env))do if valid(p)then local name=p:GetFullName();local v=self.state.visibility[name];if v~=nil then p:SetVisibility(v,false)end;local own=self.state.ownerNoSee65c and self.state.ownerNoSee65c[name];if own~=nil then p:SetOwnerNoSee(own)end end end
  end
  held66.token=nil;held66.view=nil;held66.at=nil
  self:attachmentVisibility(nil,false);self:clearViewWeapons(nil,false);self.mcViewStatic=nil;self.foodCard=nil;self.foodId=nil;self.mesh=nil;self.state=nil;self.cameraSaved=nil;self.fpCamera=nil;self.pose=nil;self.texture=nil;self.firstPerson=false;self.pendingTexture=nil;self.swingAt=nil;self.viewSwing=nil;self.viewGrip=nil;self.hideLeft=nil
 end
 function S:updateFood(env)
  local selected=ctx.items:hotbar(env,ctx.phaseA.selected);local def=foodItems[selected.id];local id=def and def.category=='consumable'and def.hunger and selected.count>0 and selected.id or nil
  if id~=self.foodId then
   if valid(self.foodCard)then self.foodCard:K2_DestroyComponent(env.player)end;self.foodCard=nil;self.foodId=id
   if id then
    local identity={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
    local c=env.player:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),true,identity,false);assert(valid(c));self.foodCard=c
    c:SetCollisionEnabled(0);c:SetCastShadow(false);assert(c:SetStaticMesh(asset('/Engine/BasicShapes/Cube.Cube')))
    local mid=c:CreateDynamicMaterialInstance(0,asset('/Game/MinecraftSteve/Task27/M_MC27SkinOverlay.M_MC27SkinOverlay'),UE.FindOrAddFName('None'));assert(valid(mid));mid:SetTextureParameterValue(UE.FindOrAddFName('SkinTexture'),ctx.items:icon(id))
     assert(c:K2_AttachToComponent(self.mesh,UE.FindOrAddFName('hand_r'),2,2,2,false));c:SetRelativeScale3D({X=.012,Y=.18,Z=.18})

     _G.MC_OUT_K('K2_SetRelativeLocation',c,{X=-8,Y=0,Z=-20},false,ignoredHitJ(),true);ctx.log('MC52_FOOD_HAND_READY id='..id..' owned_icon=true')
   end
  end
  if valid(self.foodCard)then
   if held66:supports(self.foodId)then return end
   local r=env.controller.PlayerCameraManager:GetCameraRotation()

   local t=self.mesh:GetSocketTransform(UE.FindOrAddFName('hand_r'),0)
   local offset=motion.rotate(t.Rotation,{X=-8,Y=0,Z=-20});local p=t.Translation
   if self.firstPerson and self.viewGrip then
    local yaw,pitch=math.rad(r.Yaw),math.rad(r.Pitch);local forward={X=math.cos(yaw)*math.cos(pitch),Y=math.sin(yaw)*math.cos(pitch),Z=math.sin(pitch)}
    local up={X=-math.cos(yaw)*math.sin(pitch),Y=-math.sin(yaw)*math.sin(pitch),Z=math.cos(pitch)}
    p=self.viewGrip;offset={X=forward.X*8+up.X*18,Y=forward.Y*8+up.Y*18,Z=forward.Z*8+up.Z*18}
    self.foodCard:SetWorldScale3D({X=.012,Y=.18,Z=.18})
   end
   _G.MC_OUT_K('K2_SetWorldLocation',self.foodCard,{X=p.X+offset.X,Y=p.Y+offset.Y,Z=p.Z+offset.Z},false,ignoredHitJ(),true)
   _G.MC_OUT_K('K2_SetWorldRotation',self.foodCard,{Pitch=r.Pitch,Yaw=r.Yaw,Roll=25},false,ignoredHitJ(),true)
   self.foodCard:SetOwnerNoSee(false);self.foodCard:SetOnlyOwnerSee(self.firstPerson);self.foodCard:SetVisibility(true,false)
  end
 end
 function S:apply(env)
  local source=env.player.Mesh
  if not self.choice then local ok,choice=pcall(skin.choice,ctx.config.steve_arm_format or 'wide',ctx.config.steve_skin_file or 'steve-wide.png');if ok then self.choice=choice else log('MC27_SKIN_REJECTED default_retained '..tostring(choice))end end
  local mesh=asset(self:meshPath(false))
  assert(not valid(mesh.PhysicsAsset),'Cosmetic Steve must have no physics')
  local id={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
  self.state={player=env.player:GetAddress(),epoch=ctx.epoch(),tick=source.VisibilityBasedAnimTickOption,tickEnabled=source:IsComponentTickEnabled(),pauseAnims=source.bPauseAnims,visibility={},nativeAnimation=source:GetAnimInstance():GetFullName()}
  for _,p in ipairs(parts(env))do if valid(p)then self.state.visibility[p:GetFullName()]=p:IsVisible()end end
  self.mesh=env.player:AddComponentByClass(UE.Object('/Script/Engine.PoseableMeshComponent'),true,id,false);assert(valid(self.mesh))
  self.mesh:SetCollisionEnabled(0);assert(self.mesh:K2_AttachToComponent(source,UE.FindOrAddFName('None'),0,0,0,false))
  self.mesh:SetSkinnedAssetAndUpdate(mesh,true);self.mesh:AddTickPrerequisiteComponent(source);self.mesh:SetComponentTickEnabled(true)
  assert(self.mesh:GetNumBones()==17);rigid:bind(self.mesh);self.rigid=rigid
  self.texture=self.pendingTexture or self.titleTexture or(self.choice and not self.choice.default71 and skin.load(env,self.choice));self.pendingTexture=nil
  if not self.texture and UE.texRuntime then self.texture=UE.texRuntime:load('textures/entity/player/'..(self.choice and self.choice.format=='slim'and'slim/alex.png'or'wide/steve.png'),nil)end
  if self.texture then skin.apply(self.mesh,self.texture,asset,self.titleMask71);log('MC27_SKIN_LIVE format='..self.choice.format..' file='..self.choice.file..' filter='..self.texture.Filter..' pixels=64 pixel_centres=true')end
  self.mesh:SetOwnerNoSee(source.bOwnerNoSee);self.mesh:SetOnlyOwnerSee(source.bOnlyOwnerSee)
  source.VisibilityBasedAnimTickOption=0;source:SetComponentTickEnabled(true);source.bPauseAnims=false;self.pose=false
  log('MC36_STEVE_SOURCE_TICK before_enabled='..tostring(self.state.tickEnabled)..' before_paused='..tostring(self.state.pauseAnims))
  log('MC26_STEVE_READY bones=17 native_animation='..self.state.nativeAnimation..' refs='..T.nativeRefCount)
 end
  function S:maskNative(env)
   if not self.state then return end
   self.state.names61=self.state.names61 or{}
   self.state.ownerNoSee65c=self.state.ownerNoSee65c or{}
   for _,p in ipairs(parts(env))do if valid(p)then
    local address=p:GetAddress();local name=self.state.names61[address]
    if not name then name=p:GetFullName();self.state.names61[address]=name end
    if self.state.visibility[name]==nil then self.state.visibility[name]=p:IsVisible()end
    if self.state.ownerNoSee65c[name]==nil then self.state.ownerNoSee65c[name]=p.bOwnerNoSee end
    if not p.bOwnerNoSee then p:SetOwnerNoSee(true)end
    if p:IsVisible()then p:SetVisibility(false,false)end
   end end
  end
  function S:tick(env)
  if T.test54 and T.test54.steveservice==false then return end
  if not self.enabled then if self.state then self:clear(env,true)end;return end
  if not valid(env.player)or not valid(env.player.Mesh)or not valid(env.player.CharacterParameterComponent)then return end
  local parameter=env.player.CharacterParameterComponent:GetIndividualParameter();if not valid(parameter)then return end
  local dead=parameter:IsDead()
  if self.state and(self.state.epoch~=ctx.epoch()or self.state.player~=env.player:GetAddress())then self:clear(nil,false)end
  if dead then if self.state then self:clear(nil,false);log('MC28_STEVE_DEFERRED dead=true native_components_untouched=true')end;return end
  if not self.state then self:apply(env)end

  if self.nativeTalkR then
   self.talkDrawsR=self.talkDrawsR or{}
   local function hide(c)if valid(c)then local a=c:GetAddress();if not self.talkDrawsR[a]then self.talkDrawsR[a]={node=c,visible=c:IsVisible()}end;c:SetVisibility(false,false)end end
   self:maskNative(env);hide(self.mesh);hide(self.foodCard);hide(self.mcViewStatic);hide(ctx.phaseC:handVisual())
   for _,v in ipairs(self.viewWeapons or{})do hide(v.component)end
   if not self.talkHiddenR then self.talkHiddenR=true;log('MCR_DIALOGUE_STEVE hidden=true cosmetic_only=true')end
   return
  elseif self.talkHiddenR then
   for _,r in pairs(self.talkDrawsR or{})do if valid(r.node)then r.node:SetVisibility(r.visible,false)end end
   self.talkDrawsR=nil;self.talkHiddenR=nil;log('MCR_DIALOGUE_STEVE hidden=false restored=true')
  end

   self:maskNative(env)
  local shooter=env.player.ShooterComponent;local weapon=shooter:GetHasWeapon()
  local weaponAddress=valid(weapon)and weapon:GetAddress()or 0;local nowZ3=os.clock()
  if self.weaponAddressZ3~=weaponAddress or nowZ3>=(self.weaponCheckZ3 or 0)then
   self.weaponAddressZ3=weaponAddress;self.weaponCheckZ3=nowZ3+.5
   self.weaponClassZ3=valid(weapon)and weapon:GetClass():GetFName():ToString()or''
  end
  local handgun=self.weaponClassZ3=='BP_HandGun_C'
  self:firstPersonCamera(env,self.requestedFirstPerson)
  self.mountCamera102:update(env,self.requestedFirstPerson,env.controller:IsRiding())
  self:camera(env,handgun and not self.requestedFirstPerson)
  local camera=env.controller.PlayerCameraManager:GetCameraLocation();local head=env.player.Mesh:GetSocketLocation(UE.FindOrAddFName('Head'))
  local close=(camera.X-head.X)^2+(camera.Y-head.Y)^2<55^2 and math.abs(camera.Z-head.Z)<70
  local fp=self.requestedFirstPerson or close
  if self.firstPerson~=fp then
   self:clearViewWeapons(env,true)
     _G.MC_OUT_K('K2_SetRelativeTransform',self.mesh,{Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}},false,ignoredHitJ(),true)
   self.mesh:SetSkinnedAssetAndUpdate(asset(self:meshPath(fp)),true);if self.texture then skin.apply(self.mesh,self.texture,asset,self.titleMask71)end
   self.firstPerson=fp;self.swingAt=nil;log('MC27_STEVE_VIEW first_person='..tostring(fp)..' arms_only='..tostring(fp))
  end
  rigid:tick(env,self,weapon)
  self.elytra104:tick(env,self)
  local bow=self.weaponClassZ3:lower():find('bow',1,true)~=nil
  local selected=ctx.items:hotbar(env,ctx.phaseA.selected);local selectedDef=foodItems[selected.id];local food=selectedDef and selectedDef.category=='consumable'and selectedDef.hunger
  local hideLeft=self.firstPerson and(food or not bow or held66:supports(selected.id))
  if hideLeft~=self.hideLeft then
   if hideLeft then self.mesh:HideBoneByName(UE.FindOrAddFName('upperarm_l'),0)else self.mesh:UnHideBoneByName(UE.FindOrAddFName('upperarm_l'))end
   self.hideLeft=hideLeft
  end
  self:updateFood(env)
  self:updateViewWeapons(env,weapon)

  self.itemOnly66=self.firstPerson and selected.id~=nil and selected.id~=''and(selected.count or 0)>0
  self:hideFirstPersonAttachments(env,weapon,selected)
  ctx.phaseC:hideUnusedHand()
  self.itemFrame=T.frameCounter;self.itemId=selected.id
  local draw=not self.itemOnly66;if self.mesh:IsVisible()~=draw then self.mesh:SetVisibility(draw,false)end
 end
 function S:start(env)
  if self.handle then T.cancel(self.handle)end
   local epoch=ctx.epoch();self.handle=T.loop(33,function()if ctx.quiesced()or epoch~=ctx.epoch()then return true end;local e=ctx.environment();if e then self:tick(e)end;return false end,'steve-appearance')

 end
 T.hook('/Script/Pal.PalNPCTalkFlowComponent:RequestStartTalkFlow',function()S.nativeTalkR=true end)
 T.hook('/Script/Pal.PalNPCTalkFlowComponent:OnFinishTalkFlow',function()S.nativeTalkR=false end)
 T.hook('/Script/Pal.PalNPCTalkFlowComponent:RequestEndTalkFlow',function()S.nativeTalkR=false end)
 T.onEpoch('steve',function(value,reason)
  S.assetCacheZ3=nil;S.attachmentKeyZ3=nil;S.weaponAddressZ3=nil;S.weaponCheckZ3=nil;S.weaponClassZ3=nil
  S.nativeTalkR=nil;S.talkDrawsR=nil;S.talkHiddenR=nil
  S.boom61=nil;S.boomPlayer61=nil
  if reason=='world-entry'and S.earlyState and S.state then S.state.epoch=value;S.earlyState=nil
  else S:clear(nil,false)end;S.handle=nil
 end)
 return S
end
