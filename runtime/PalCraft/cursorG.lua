-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,D,G)
 local T=dofile(ctx.base..'/timers.lua');local C={}
 function C:reset()self.rows=nil;self.at=nil;self.emptyAt=nil;self.scans=0;self.scanAt=nil;D.nativeVisibleG=false;D.nativeEscapeG=false end
 function C:tick(e)
  local UE=ctx.UE;local input=ctx.uiKit.input57
  if(UE.waystones83 and UE.waystones83.busy)or(UE.loadingCover51 and UE.loadingCover51.at)or e.status~='alive'then
   self:reset();self.hadMenu=nil;return
  end
  if D.open or ctx.items.open or(input and input.owner)or(UE.alexTrade and UE.alexTrade.open)
   or(UE.waystones83 and UE.waystones83.open)then self:reset();self.hadMenu=true;return end
  if UE.nativeInputG4 and UE.nativeInputG4:blocksMenu()then
   D.nativeVisibleG=true;D.nativeEscapeG=false;self.hadMenu=true;self.emptyAt=nil;return
  end

  local captured=e.controller:IsMoveInputIgnored()or e.controller:IsLookInputIgnored()

  if e.controller:IsRiding()and not e.controller.bShowMouseCursor then self:reset();self.hadMenu=nil;return end
  if not e.controller.bShowMouseCursor and not captured and not self.hadMenu then self:reset();D.nativeBypass=false;return end
  local now=os.clock();if now<(self.at or 0)then return end;self.at=now+.1
  local visible,foreign=false,false
  local function observe(w)
   if not w then return end
   local shown,escapeMenu=G:visible(w,e.controller)
   if shown then visible=true;if not escapeMenu then foreign=true end end
  end
  for _,row in ipairs(self.rows or{})do observe(G:resolve(row))end
  if(e.controller.bShowMouseCursor or captured)and not visible and(now-(self.scanAt or -10)>.25)then
   self.scanAt=now
   self.scans=(self.scans or 0)+1;self.rows={}
   for _,w in ipairs(FindAllOf('PalActivatableWidget')or{})do
    local row=G:capture(w);if row then self.rows[#self.rows+1]=row;observe(w)end
   end
  end
  D.nativeVisibleG=visible
  D.nativeEscapeG=visible and not foreign
  if visible then self.emptyAt=nil;self.hadMenu=true;return end
  self.emptyAt=self.emptyAt or now
  if now-self.emptyAt<.5 or ctx.items.openRequest or D.escapeDue or D.pendingNav46 then return end
  G:releaseMain(e.controller)
  e.controller:ResetIgnoreMoveInput();e.controller:ResetIgnoreLookInput();e.controller.bShowMouseCursor=false
  UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(e.controller,true)
  ctx.log('MCG_GAME_INPUT_RESTORED no_visible_native_or_mod_menu=true scans='..tostring(self.scans));self:reset();self.hadMenu=nil;D.nativeBypass=false
 end
 T.onEpoch('cursorG',function()C:reset();C.hadMenu=nil end)
 return C
end
