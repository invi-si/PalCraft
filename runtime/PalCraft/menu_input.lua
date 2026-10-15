-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local I={};local T=dofile(ctx.base..'/timers.lua')
 function I:install()
  T.key(Key.TAB,function()if self.alive then self.tab=true;self.tabAt=os.clock()end end)
  T.key(Key.ESCAPE,function()if self.alive then self.escape=true;self.escapeAt=os.clock()end end)
  T.frame('menu-input',function()self:tick()end)
  T.onEpoch('menu-input',function()self.alive=false;ctx.items.inputAlive=false;ctx.menu.inputAlive=false;self.tab=nil;self.escape=nil;self.fallback=nil;self.serial=(self.serial or 0)+1 end)
  ctx.log('MC50_MENU_KEYS_READY initial_state=true callbacks=flags_only master_tick=true')
 end
 function I:tick()
  if T.test54 and T.test54.menu==false then return end
  local tab,escape=self.tab,self.escape;self.tab=nil;self.escape=nil
  local env=not ctx.quiesced()and ctx.environment()or nil
  self.alive=env~=nil;ctx.items.inputAlive=self.alive;ctx.menu.inputAlive=self.alive
  if not env then self.fallback=nil;ctx.items.nativeInventoryDirty=nil;ctx.items.openRequest=nil;ctx.items.intent=nil;ctx.menu.escapeDirty=nil;ctx.menu.escapeDue=nil;ctx.menu.pendingNav46=nil;ctx.menu.intent=nil;return end
  local b,d,now=ctx.items,ctx.menu,os.clock()
  local native=ctx.UE.nativeInputG4
  if native then
   native:tick(env)
   if native:blocksMenu(escape and self.escapeAt or tab and self.tabAt)then
    b.nativeInventoryDirty=nil;d.escapeDirty=nil;d.escapeDue=nil;self.fallback=nil;return
   end
  end
  local trade=ctx.trade and ctx.trade()
  if trade and trade.open then
   b.nativeInventoryDirty=nil;d.escapeDirty=nil;d.escapeDue=nil
   if escape or tab then trade:close(env)end
   return
  end
  if ctx.uiKit:editing()then
   if escape then ctx.uiKit:clearField();b.escapeUntil=now+.35;if b.open then b:close()elseif d.open then d:close()end end
   b.nativeInventoryDirty=nil;d.escapeDirty=nil;d.escapeDue=nil;return
  end

  b:pollNativeInventory()
  if d.nativeVisibleG and(not d.nativeEscapeG or d.nativeBypass)and not b.open and not d.open then b.nativeInventoryDirty=nil;d.escapeDirty=nil;d.escapeDue=nil;return end
  if tab or escape then
   self.serial=(self.serial or 0)+1;self.fallback=nil
   if escape and b.openRequest and not b.open and not d.open then
    b.openRequest=nil;b.intent=nil;b.nativeInventoryDirty=nil;b.escapeUntil=now+.35;d.escapeDirty=nil;d.escapeDue=nil
   elseif b.open or d.open then
    b.escapeUntil=now+.35;d.escapeDirty=nil;d.escapeDue=nil
    if b.open then b:close()else d:close()end
   elseif not(b.escapeUntil and now<b.escapeUntil)then
    local at=escape and self.escapeAt or self.tabAt
    ctx.log(string.format('MC51_INPUT key=%s at=%.6f consume=%.6f frame=%d',escape and'Esc'or'Tab',at or now,now,T.frameCounter))
    if escape then d:show(env,'Game',nil)else b.intent=2;b:attach(nil)end
    ctx.log(string.format('MC51_INPUT_VISIBLE key=%s latency_ms=%.3f frame=%d',escape and'Esc'or'Tab',(os.clock()-(at or now))*1000,T.frameCounter))
   end
  end
  d:pollEscape(env)
  local f=self.fallback
  if f and now>=f.due then
   self.fallback=nil
   if f.epoch~=ctx.epoch()or f.serial~=self.serial or b.open or d.open or b.openRequest or(b.escapeUntil and now<b.escapeUntil)then return end
   if f.key=='tab'then
    if now-(b.nativeInputAt or 0)>.15 then b:requestOpen(2)end
   elseif not d.escapeDue and not d.escapeDirty then d:request('Game')end
  end
 end
 return I
end
