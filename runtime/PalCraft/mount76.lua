-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local ride106=dofile(ctx.base..'/ride106.lua')(ctx)
 local bossP=dofile(ctx.base..'/boss_rideP.lua')(ctx)
 local V={dirty=true,riding=false,ride106=ride106,bossP=bossP};local icons=dofile(ctx.base..'/native_icons.lua')
 local function clamp(v)return math.max(0,math.min(1,v or 0))end
 local function vec(v)return{X=v.X,Y=v.Y,Z=v.Z}end
 local function asset(path)
  local o=UE.Object(path);if valid(o)then return o end
  local p,n=path:match('^(.*)%.([^%.]+)$')
  return UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(p),AssetName=UE.FindOrAddFName(n)})
 end
 function V:observe(riding)
  if self.observed~=riding then self.observed=riding;self.dirty=true end
 end
 function V:invalidate()

  ride106:clear(false)
  self.rider=nil;self.mount=nil;self.parameter=nil;self.partner=nil;self.movement=nil
  self.player=nil;self.riding=false;self.mountAddress=nil;self.id=nil;self.dirty=true;self.observed=nil;self.sampled=nil;self.converter=nil
 end
 function V:forget()
  self:invalidate();self.epoch=nil;self.hud=nil
 end
 function V:resolve(e)
  local epoch,player=ctx.epoch(),e.player:GetAddress()
  if self.epoch~=epoch then self:forget();self.epoch=epoch
  elseif self.player~=player then self:invalidate()end
  if not self.rider then
   self.player=player
   self.rider=e.player:GetComponentByClass(UE.Object('/Script/Pal.PalRiderComponent'))
   assert(valid(self.rider),'MC76 local rider component absent')
   self.converter=UE.Object('/Script/Pal.Default__FixedPoint64MathLibrary');assert(valid(self.converter))
  end
  local riding=self.rider:IsRiding();self:observe(riding)
  if not self.dirty then return end;self.dirty=false
  local mount=riding and self.rider:GetRindingActor()or nil
  if riding and not valid(mount)then self.dirty=true;return end
  local address=valid(mount)and mount:GetAddress()or nil
  if address~=self.mountAddress then
   ride106:clear(true)
   self.mountAddress=address;self.mount=mount;self.parameter=nil;self.partner=nil;self.movement=nil
   if mount then
    self.parameter=mount:GetCharacterParameterComponent();assert(valid(self.parameter))
    self.partner=mount:GetComponentByClass(UE.Object('/Script/Pal.PalPartnerSkillParameterComponent'))
    self.movement=mount:GetPalCharacterMovementComponent()
    self.id=self.parameter:GetIndividualParameter():GetCharacterID():ToString()
   end
   ctx.log('MC76_MOUNT_TRANSITION riding='..tostring(riding)..' mount='..tostring(self.id)..' epoch='..ctx.epoch())
  end
  self.riding=riding and valid(mount);self.sampled=nil
 end
 function V:sample(e)
  self:resolve(e)
  bossP:sample(e,self,os.clock())
  if not self.riding or not valid(self.parameter)then ride106:clear(true);self.sampled=nil;return end
  local p=self.parameter;local nativeRate=p:GetHPRate()
  local hpValue=self.converter:Convert_FixedPoint64ToFloat(p:GetHP());local maxHP=self.converter:Convert_FixedPoint64ToFloat(p:GetMaxHP());local hp=clamp(hpValue/math.max(.001,maxHP))
  local sp=self.converter:Convert_FixedPoint64ToFloat(p:GetSP());local maxsp=self.converter:Convert_FixedPoint64ToFloat(p:GetMaxSP())
  local s={hp=hp,hpValue=hpValue,maxHP=maxHP,nativeHPRate=nativeRate,sp=sp,maxsp=maxsp,stamina=maxsp>0 and clamp(sp/maxsp)or nil,id=self.id,at=os.clock(),airborne=false}
  if valid(self.movement)then s.mode=self.movement.MovementMode;s.airborne=s.mode==5 end
  if valid(self.partner)then
   local p=self.partner;s.skill=p:IsExistActiveSkill();s.active=p:IsRunning();s.locked=not p:CanExec()
   s.cooldown=p:IsCoolDown()and clamp(p:GetCoolDownTimeRatio())or 0
   s.effect=s.active and clamp(p:GetEffectTimeRatio())or 0
  end
  local jump=ride106:sample(self,e,os.clock());if jump then s.jumpCharge=jump.charge;s.lastJump=jump.last end
  self.sampled=s;return s
 end
 function V:ui(e,ns,u,kit)
  
  u=u*.65
  local s=self:sample(e);local active=s~=nil
  if not self.hud or self.hud.root~=ns.Crosshair:GetAddress()or self.hud.unit~=u then
   local root=ns.Crosshair:GetParent();self.hud={root=ns.Crosshair:GetAddress(),unit=u,nodes={},values={},food={}}
   local h=self.hud
   local function node(name,kind,x,y,w,height,z)
    local n=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.'..kind),root:GetOuter());root:AddChildToCanvas(n)
     kit:position(n,x,y,w,height,u);n.Slot:SetAnchors({Minimum={X=1,Y=0},Maximum={X=1,Y=0}});n.Slot:SetZOrder(z or 40);n:SetVisibility(3);n:SetRenderOpacity(0);h.nodes[name]=n
    if kind=='TextBlock'then kit:textStyle(n,u,false)end;return n
   end
   h.textures={}
   for _,kind in ipairs({'full','half','container'})do
    local n='T_MC76_vehicle_'..kind;local texture=asset('/Game/MinecraftRiding/T76/'..n..'.'..n);assert(valid(texture));h.textures[kind]=texture

    local keep=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.Image'),root:GetOuter());root:AddChildToCanvas(keep);keep.Slot:SetSize({X=1,Y=1});keep:SetBrushFromTexture(texture,false);keep:SetVisibility(3);keep:SetRenderOpacity(0)
   end
   for i=1,10 do
    local p=ns['Food'..i].Slot:GetPosition();h.food[i]={x=p.X,y=p.Y}
     local x,y=-124+(i-1)*9,32
    node('empty'..i,'Image',x,y,9,9):SetBrushFromTexture(h.textures.container,false)
    node('heart'..i,'Image',x,y,9,9,41)
   end
    node('staminaBG','Image',-124,44,81,4):SetColorAndOpacity({R=.03,G=.03,B=.03,A=1})
    node('stamina','Image',-123,45,79,2):SetColorAndOpacity({R=.85,G=.65,B=.2,A=1})
    node('air','TextBlock',-124,52,110,10)
    node('jumpBG','Image',-214,65,182,5):SetColorAndOpacity({R=.03,G=.03,B=.03,A=1})
    node('jump','Image',-213,66,180,3):SetColorAndOpacity({R=.25,G=.55,B=1,A=1})
    node('frame','Image',-153,19,22,22);kit:brush(h.nodes.frame,'T_MC_UI_slot',{1/18,1/18})
    node('icon','Image',-151,21,18,18,41)
    node('sweep','Image',-151,21,18,18,42):SetColorAndOpacity({R=0,G=0,B=0,A=.65})
    node('key','TextBlock',-124,18,12,10,43);kit:putText(h.nodes.key,'F')
    node('state','TextBlock',-108,18,85,10,43)
  end
  local h=self.hud
  if h.active~=active then
   h.active=active;h.values={};h.hp=nil;h.sp=nil
   for _,n in pairs(h.nodes)do n:SetRenderOpacity(active and 1 or 0)end
  end
  if not s then return end
  h.hp=h.hp and h.hp+(s.hp-h.hp)*.75 or s.hp;h.sp=h.sp and h.sp+((s.stamina or 0)-h.sp)*.75 or(s.stamina or 0)
  for i=1,10 do local count=math.max(0,math.min(2,math.ceil(h.hp*20-.001)-(i-1)*2));if h.values[i]~=count then h.values[i]=count;local n=h.nodes['heart'..i];n:SetRenderOpacity(count>0 and 1 or 0);if count>0 then n:SetBrushFromTexture(h.textures[count==2 and'full'or'half'],false)end end end
  local bucket=math.floor(h.sp*79+.5)
  if h.values.sp~=bucket then h.values.sp=bucket;h.nodes.stamina.Slot:SetSize({X=math.max(.01,bucket*u),Y=2*u})end
  local jump=s.jumpCharge;local jumpShow=jump~=nil and 1 or 0
  h.nodes.jumpBG:SetRenderOpacity(jumpShow);h.nodes.jump:SetRenderOpacity(jumpShow)
  local charge=jump and math.floor(jump*180+.5)or 0
  if h.values.jump~=charge then h.values.jump=charge;h.nodes.jump.Slot:SetSize({X=math.max(.01,charge*u),Y=3*u})end
  local show=s.maxsp>0 and 1 or 0;h.nodes.staminaBG:SetRenderOpacity(show);h.nodes.stamina:SetRenderOpacity(show)
  kit:putText(h.nodes.air,s.airborne and'Airborne'or'')
  local key='T_'..s.id..'_icon_normal';local path=icons[key]
  if h.values.icon~=s.id and path then h.values.icon=s.id;local texture=asset(path);if valid(texture)then kit:icon(h.nodes.icon,texture,20,0)end end

  local label=s.active and'Active'or(s.cooldown>0 and'Cooldown'or(s.skill and s.locked and'Locked'or'Dismount'))
  kit:putText(h.nodes.state,label)
  local cover=math.floor((s.cooldown>0 and s.cooldown or 0)*18+.5)
  if h.values.cover~=cover then h.values.cover=cover;h.nodes.sweep:SetRenderOpacity(cover>0 and 1 or 0);h.nodes.sweep.Slot:SetSize({X=18*u,Y=math.max(.01,cover*u)})end
 end
 for _,name in ipairs({'RideClientRep','GetOff','OnInactive','OnDeadPlayer'})do
  local fn='/Script/Pal.PalRiderComponent:'..name
  if valid(StaticFindObject(fn))then
   if name=='OnDeadPlayer'or name=='OnInactive'then T.hook(fn,function()V:invalidate()end)
   elseif name=='GetOff'then T.hook(fn,function(context)bossP:beforeGetOff(context:get(),V);V.dirty=true end,function()bossP:afterGetOff()end)
   else T.hook(fn,function()V.dirty=true end)end
  end
 end
 T.onEpoch('mount76',function()V:forget()end)
 return V
end
