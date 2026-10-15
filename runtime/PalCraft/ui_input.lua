-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local I={serial=0,opens=0,repairs=0};U.input57=I
 local function library()return UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary')end
 function I:reset(reason)
  local c=self.controller
  self.owner=nil;self.controller=nil;self.fields=nil;self.field=nil;self.serial=self.serial+1
  if valid(c)then
   c:ResetIgnoreMoveInput();c:ResetIgnoreLookInput();c.bShowMouseCursor=false
   library():SetInputMode_GameOnly(c,true)
  end
  ctx.log('MCZ1_INPUT_RELEASE reason='..tostring(reason)..' serial='..self.serial)
 end
 function I:editing()
  if not self.owner then return false end
  if valid(self.field)then return true end
  for _,n in ipairs(self.fields or{})do if valid(n)and(n:HasKeyboardFocus()or n:HasUserFocus(self.controller))then return true end end
  return false
 end
 function I:apply(centre)
  local w,c=self.owner,self.controller;if not valid(w)or not valid(c)then return end
  c.bShowMouseCursor=true;c:ResetIgnoreMoveInput();c:ResetIgnoreLookInput();c:SetIgnoreMoveInput(true);c:SetIgnoreLookInput(true)
  w.bIsFocusable=true
  library():SetInputMode_GameAndUIEx(c,w,0,false,false)
  w:SetUserFocus(c);w:SetKeyboardFocus()
  if centre then local size=UE.Object('/Script/UMG.Default__WidgetLayoutLibrary'):GetViewportSize(c);c:SetMouseLocation(math.floor(size.X/2),math.floor(size.Y/2))end
 end
 function U:ownInput(env,w,fields)
  I.serial=I.serial+1;I.owner=w;I.controller=env.controller;I.field=nil;I.fields={};for _,n in pairs(fields or{})do if valid(n)then I.fields[#I.fields+1]=n end end;I.opens=I.opens+1;I.untilAt=os.clock()+.4;I.nextAt=0
  I:apply(true);ctx.log('MC57_INPUT_OPEN serial='..I.serial..' cursor=true focus=true centred=true')
 end
 function U:releaseInput(w)
  if not w or I.owner==w then I:reset('screen-close')end
 end
 function U:focusField(env,n)
  library():SetInputMode_UIOnlyEx(env.controller,n,0,false);n:SetUserFocus(env.controller);n:SetKeyboardFocus();I.field=n
  ctx.log('MC57_TEXT_FOCUS gameplay_blocked=true')
 end
 function U:clearField()
  I.field=nil;I:apply(false)
 end
 function U:editing()return I:editing()end
 T.frame('ui-input-owner',function()
  local w,c=I.owner,I.controller;if not w then return end
  if not valid(w)or not valid(c)or not w:IsInViewport()or w:GetRenderOpacity()==0 or w:GetVisibility()==1 or w:GetVisibility()==2 then
   I:reset('watchdog-closed-owner');I.repairs=I.repairs+1
   if U.recoverInputZ1 then U.recoverInputZ1('closed-owner')end
   return
  end
  if I:editing()then
   if valid(I.field)and(not I.field:HasKeyboardFocus()or not c.bShowMouseCursor or not c:IsLookInputIgnored())then
    c.bShowMouseCursor=true;c:ResetIgnoreMoveInput();c:ResetIgnoreLookInput();c:SetIgnoreMoveInput(true);c:SetIgnoreLookInput(true)
    library():SetInputMode_UIOnlyEx(c,I.field,0,false);I.field:SetUserFocus(c);I.field:SetKeyboardFocus()
   end
   return
  end
  local now=os.clock();if now<(I.nextAt or 0)then return end;I.nextAt=now+.1

  if now<(I.untilAt or 0)or not c.bShowMouseCursor or not w:HasUserFocus(c)then I:apply(false);I.repairs=I.repairs+1 end
 end)
 T.onEpoch('ui-input-owner',function()I.owner=nil;I.controller=nil;I.fields=nil;I.field=nil;I.serial=I.serial+1 end)
end
