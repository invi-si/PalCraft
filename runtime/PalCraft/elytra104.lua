-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,M,asset)
 local E={events={}};local UE,valid=ctx.UE,ctx.valid;local N=ctx.items.native
 local function v(x,y,z)return{X=x,Y=y,Z=z}end
 local function copy(q)return{X=q.X,Y=q.Y,Z=q.Z,W=q.W}end
 function E:event(kind,data)
  data=data or{};data.event=kind;data.at=os.clock();self.events[#self.events+1]=data
  if #self.events>80 then table.remove(self.events,1)end
  ctx.log('MC104_ELYTRA_'..kind..' '..dofile(ctx.base..'/json.lua').encode(data))
 end
 function E:restoreBoost()
  local b=self.boost
  if b and valid(b.movement)then b.movement.GliderMaxSpeed=b.speed end
  if b then self:event('BOOST_END',{seconds=os.clock()-b.start})end
  self.boost=nil
 end
 function E:clear(touch)
  if touch then
   self:restoreBoost()
   if self.masked and valid(self.glider)then self.glider:SetGliderVisibility(self.glider:IsGliding(),true)end
   if valid(self.wing)then self.wing:K2_DestroyComponent(self.wing)end
  end
  self.wing=nil;self.glider=nil;self.boost=nil;self.equipped=false;self.gliding=false;self.mesh=nil;self.nextAt=0;self.visual=nil;self.masked=false
 end
 function E:pair(env)
  local slot=N:container(env,4):Get(5)
  if not slot:IsEmpty()then return end

  local id='Glider_Super';local before=N:count(env,id)
  local source=N:find(env,id)
  if not source then N:add(env,id,1);source=assert(N:find(env,id))end

  if N:id(slot)~=id then assert(N:move(env,source,slot,1),'Elytra glider pairing failed')end
  self:event('PAIRED',{id=id,before=before,after=N:count(env,id),slot=5})
 end
 function E:rocket(env)
  local selected=ctx.items:hotbar(env,ctx.phaseA.selected)
  if selected.id~='MC_FireworkRocket'then return false end
  local glider=env.player:GetPropertyValue('BP_GliderComponent')
  local equipped=N:id(N:container(env,4):Get(1))=='MC_Elytra'
  if not equipped or not valid(glider)or not glider:IsGliding()or selected.count<1 then return true end
  local now=os.clock();if self.boost and now<self.boost.finish then return true end
  if self.boost then self:restoreBoost()end
  local movement=env.player.CharacterMovement;local before=N:count(env,'MC_FireworkRocket')
  N:dispose(env,selected.slot,1)
  self.boost={start=now,finish=now+2,movement=movement,speed=movement.GliderMaxSpeed,particles=0}
  movement.GliderMaxSpeed=2200
  ctx.phaseC:play('entity.firework_rocket.launch',env.player:K2_GetActorLocation(),1,env)
  self:event('BOOST_START',{before=before,after=N:count(env,'MC_FireworkRocket'),seconds=2})
  return true
 end
 function E:space(env,down)
  if UE.creativeMode and UE.creativeMode:enabled()then self.spaceDownO=down;self.deployAtO=nil;return end
  local rising=down and not self.spaceDownO;self.spaceDownO=down
  if not rising or env.controller:IsRiding()then return end
  if N:id(N:container(env,4):Get(1))~='MC_Elytra'then return end
  local movement=env.player.CharacterMovement
  if movement.MovementMode~=3 then return end
  
  self.deployAtO=os.clock()+.10
 end
 function E:tick(env,S)
  local now=os.clock();if now<(self.nextAt or 0)then return end;self.nextAt=now+.1
  local equipped=N:id(N:container(env,4):Get(1))=='MC_Elytra'
  if not equipped then
   if self.equipped then self:clear(true);self:event('UNEQUIPPED')end
   return
  end
  if self.mesh and self.mesh~=S.mesh then self:clear(true)end
  self.mesh=S.mesh
  if not self.equipped then
   self.equipped=true;self:event('EQUIPPED')
   local ok,err=pcall(function()self:pair(env)end)
   if not ok then self:event('PAIR_FAILED',{error=tostring(err)})end
  end
  local glider=env.player:GetPropertyValue('BP_GliderComponent');self.glider=glider
  if self.deployAtO and now>=self.deployAtO then
   self.deployAtO=nil
   if env.player.CharacterMovement.MovementMode==3 and not env.controller:IsRiding()and valid(glider)and not glider:IsGliding()and glider:IsEquipGlider()and glider:CanGliding()then
    glider:StartGliding_ToServer();self:event('SPACE_DEPLOY',{airborne=true})
   end
  end
  local flying=valid(glider)and glider:IsGliding()and not env.controller:IsRiding()
  if flying~=self.gliding then
   self.gliding=flying;self:event(flying and'SPREAD'or'FOLDED')
   if flying then ctx.phaseC:play('item.elytra.flying',env.player:K2_GetActorLocation(),.35,env)else self:restoreBoost()end
  end
  if flying then
   
   glider:SetGliderVisibility(false,true);self.masked=true
  end
  local state=flying and'spread'or'folded'
  if not valid(self.wing)then
   self.wing=env.player:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),true,{Rotation={X=0,Y=0,Z=0,W=1},Translation=v(0,0,0),Scale3D=v(1,1,1)},false)
   self.wing:SetMobility(2);self.wing:SetCollisionEnabled(0);self.wing:SetGenerateOverlapEvents(false)

   assert(self.wing:K2_AttachToComponent(env.player.RootComponent,UE.FindOrAddFName('None'),2,2,2,false))
   self.wing:SetCastShadow(true);self.visual=nil
  end
  if self.visual~=state then assert(self.wing:SetStaticMesh(asset('/Game/MinecraftElytra104/SM_elytra_'..state..'.SM_elytra_'..state)));self.visual=state end
  self.wing:SetVisibility(not S.firstPerson,false)
  if not S.firstPerson then
   local t=S.mesh:GetSocketTransform(UE.FindOrAddFName('spine_03'),0)
   local q=M.mul(copy(t.Rotation),M.inv(S.rigid.rest.spine_03.Rotation))
   local p=M.add(v(t.Translation.X,t.Translation.Y,t.Translation.Z),M.rotate(q,v(0,-16,12)))
   _G.MC_OUT_K('K2_SetWorldTransform',self.wing,{Rotation=q,Translation=p,Scale3D=v(1,1,1)},false,{},true)
  end
  local b=self.boost
  if b then
   if not flying or now>=b.finish then self:restoreBoost()
   else
    local rot=env.controller:GetControlRotation();local yaw=math.rad(rot.Yaw);local pitch=math.rad(math.max(-35,math.min(35,M.wrap(rot.Pitch))))
    local velocity=env.player.CharacterMovement.Velocity
    local desired=v(math.cos(yaw)*math.cos(pitch)*1900,math.sin(yaw)*math.cos(pitch)*1900,math.sin(pitch)*1900+80)
    env.player.CharacterMovement:AddImpulse(v(desired.X-velocity.X,desired.Y-velocity.Y,desired.Z-velocity.Z),true)
    if UE.effects66 and now>=(b.nextFX or 0)then b.nextFX=now+.2;local pos=env.player:K2_GetActorLocation();if UE.effects66:emit(env,'firework',v(pos.X-math.cos(yaw)*65,pos.Y-math.sin(yaw)*65,pos.Z))then b.particles=b.particles+1 end end
   end
  end
 end
 return E
end
