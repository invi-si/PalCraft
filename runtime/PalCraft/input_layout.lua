-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local I={rows={},wheelSamples=0,wheelNotches=0,wheelMaxDelta=0};local T=dofile(ctx.base..'/timers.lua')
 local function key(name)return{KeyName=ctx.UE.FindOrAddFName(name)}end
 local remaps={OtomoChangeIncrement='None',OtomoChangeDecrement='None',SphereChange='U',PartnerPalInstructions='H',Interact4='J',ChangeWeaponNext='None',ChangeWeaponPrev='None',ChangeFishingBaitNext='None',ChangeFishingBaitPrev='None',Reload='Y'}
 function I:start(env)
  if self.controller==env.controller:GetAddress()then return end
  local input=env.controller.PlayerInput;assert(ctx.valid(input),'Native PlayerInput unavailable')
  self.rideKeysFA={};self.ridingFA=nil
  for _,name in ipairs({'RidingSkill1','RidingSkill2','RidingSkill3'})do
   local keys=input:GetActionConfigKeys(ctx.UE.FindOrAddFName(name),0)
   self.rideKeysFA[name]={keys.MainKey.KeyName:ToString(),keys.SecondaryKey.KeyName:ToString()}
  end
  self.rows={}
  for action,name in pairs(remaps)do
   local a=ctx.UE.FindOrAddFName(action);local before=input:GetActionConfigKeys(a,0)
   input:UpdateActionMapping(a,{MainKey=key(name),SecondaryKey=key('None')},0)
   local after=input:GetActionConfigKeys(a,0)
   local row={action=action,key=name,before={before.MainKey.KeyName:ToString(),before.SecondaryKey.KeyName:ToString()},after={after.MainKey.KeyName:ToString(),after.SecondaryKey.KeyName:ToString()}}
   assert(row.after[1]==name and row.after[2]=='None','Native remap did not settle '..action)
   self.rows[#self.rows+1]=row
  end

  local settings=StaticFindObject('/Script/Engine.Default__InputSettings');assert(ctx.valid(settings))
  local numeric={One=true,Two=true,Three=true,Four=true,Five=true,Six=true,Seven=true,Eight=true,Nine=true}
  local actions={}
  settings.ActionMappings:ForEach(function(_,v)local m=v:get();actions[m.ActionName:ToString()]=true end)
  for action in pairs(actions)do local a=ctx.UE.FindOrAddFName(action);local keys=input:GetActionConfigKeys(a,0);local main,secondary=keys.MainKey.KeyName:ToString(),keys.SecondaryKey.KeyName:ToString()
   if numeric[main]or numeric[secondary]then input:UpdateActionMapping(a,{MainKey=key(numeric[main]and'None'or main),SecondaryKey=key(numeric[secondary]and'None'or secondary)},0);ctx.log('MC68_NUMBER_REMAP action='..action..' before='..main..','..secondary)end
  end
  local remove={}
  settings.ActionMappings:ForEach(function(_,v)local m=v:get();if numeric[m.Key.KeyName:ToString()]or(m.ActionName:ToString()=='UIINputGuardCancel'and m.Key.KeyName:ToString()=='BackSpace')then
   remove[#remove+1]={ActionName=m.ActionName,Key={KeyName=m.Key.KeyName},bShift=m.bShift,bCtrl=m.bCtrl,bAlt=m.bAlt,bCmd=m.bCmd}
  end end)
  for _,m in ipairs(remove)do settings:RemoveActionMapping(m,false);ctx.log('MC68_RAW_BINDING_REMOVED action='..m.ActionName:ToString()..' key='..m.Key.KeyName:ToString())end
  if #remove>0 then settings:ForceRebuildKeymaps();ctx.log('MC55_BACKSPACE_NATIVE_CANCEL_REMOVED count='..#remove..' saved=false')end
  self.controller=env.controller:GetAddress();self.input=input:GetAddress()
  self.wheelKey=key('MouseWheelAxis')
  self.numberKeys={};self.numberDown={};for i,name in ipairs({'One','Two','Three','Four','Five','Six','Seven','Eight','Nine'})do self.numberKeys[i]=key(name)end
  if not self.sampler then
   self.sampler=T.loop(1,function()
    if ctx.ready()then self:poll(ctx.environment())end
    return false
   end,'hotbar-input')
  end
  ctx.log('MC44_INPUT_READY hotbar=1-9 wheel=9_priority_sampler party=arrows+R reload=Y sphere_cycle=U commands=H interaction4=J persistent_settings=false')
 end
 function I:poll(env)
  if not env or env.status~='alive'or env.controller:GetAddress()~=self.controller or ctx.items.open or ctx.phaseD.open or env.controller.bShowMouseCursor then return end

  local frame=ctx.UE.GetKismetSystemLibrary():GetFrameCount();if frame==self.wheelFrame then return end;self.wheelFrame=frame
  local riding=env.controller:IsRiding()
  if self.ridingFA~=riding then
   self.ridingFA=riding;local input=env.controller.PlayerInput;local defaults={RidingSkill1='LeftMouseButton',RidingSkill2='E',RidingSkill3='C'}
   local numeric={One=true,Two=true,Three=true,Four=true,Five=true,Six=true,Seven=true,Eight=true,Nine=true}
   for name,old in pairs(self.rideKeysFA or{})do
    local main,secondary=old[1],old[2]
    if main=='None'and secondary=='None'then main=defaults[name]end
    if not riding then if numeric[main]then main='None'end;if numeric[secondary]then secondary='None'end end
    local action=ctx.UE.FindOrAddFName(name);local actual=input:GetActionConfigKeys(action,0)
    if actual.MainKey.KeyName:ToString()~=main or actual.SecondaryKey.KeyName:ToString()~=secondary then input:UpdateActionMapping(action,{MainKey=key(main),SecondaryKey=key(secondary)},0)end
   end
   ctx.log('MCFA_RIDE_INPUT riding='..tostring(riding)..' native_skills=retained')
  end
  if riding then return end
  if ctx.UE.elytra104 and ctx.gameplayInput(env)then
   self.spaceKeyO=self.spaceKeyO or key('SpaceBar')
   ctx.UE.elytra104:space(env,env.controller:IsInputKeyDown(self.spaceKeyO))
  end
  for i,k in ipairs(self.numberKeys)do local down=env.controller:IsInputKeyDown(k)
   if down and not self.numberDown[i]and ctx.gameplayInput(env)then ctx.phaseA:select(i)end;self.numberDown[i]=down
  end
  local down=ctx.UE.rightDown68==true;local now=os.clock()
  if down and not self.rightDown68 then self.repeatAt68=now+.2 end
  if down and self.rightDown68 and now>=(self.repeatAt68 or now+.2)then self.repeatAt68=self.repeatAt68+.2;if now-self.repeatAt68>.2 then self.repeatAt68=now+.2 end;if ctx.gameplayInput(env)then ctx.phaseA:place(true)end end
  self.rightDown68=down
  local delta=env.controller:GetInputAnalogKeyState(self.wheelKey)
  self.wheelSamples=self.wheelSamples+1
  if delta==0 then return end
  self.wheelMaxDelta=math.max(self.wheelMaxDelta,math.abs(delta))
  if ctx.gameplayInput(env)then
   self.wheelRemainder=(self.wheelRemainder or 0)+delta
   local count=math.floor(math.abs(self.wheelRemainder)+.00001)
   if count==0 then return end
   local direction=self.wheelRemainder>0 and-1 or 1
   self.wheelRemainder=self.wheelRemainder+(direction*count)
   local slot=(ctx.phaseA.selected-1+direction*count)%9+1;ctx.phaseA:select(slot)
   self.wheelNotches=self.wheelNotches+count
   ctx.log('MC49_WHEEL delta='..delta..' notches='..count..' slot='..slot)
  end
 end
 function I:party(direction)
  local env=ctx.active();if not ctx.gameplayInput(env)then return end
  if direction>0 then env.controller:OnOtomoChangeIncrement()else env.controller:OnOtomoChangeDecrement()end
  ctx.phaseA.lastPartyAt=nil;ctx.log('MC_PARTY_CYCLE direction='..direction..' selected='..env.controller.BP_OtomoPalHolderComponent:GetSelectedOtomoID())
 end
 function I:status(env)return{controller=self.controller==env.controller:GetAddress(),rows=self.rows,wheelSamples=self.wheelSamples,wheelNotches=self.wheelNotches,wheelMaxDelta=self.wheelMaxDelta,wheelRemainder=self.wheelRemainder or 0}end
 T.onEpoch('input-layout',function()I.controller=nil;I.input=nil;I.wheelFrame=nil;I.wheelRemainder=nil end)
 return I
end
