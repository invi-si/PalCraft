-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local C={entries={},parkVisibility=1,names={'WBP_MCInventory2','WBP_MCInventory3','WBP_MCChest','WBP_MCFurnace','WBP_MCProduction','WBP_MCOptions','WBP_MCDeath','WBP_MCGameMenu','WBP_MCPals','WBP_MCPC','WBP_MCTechnology','WBP_MCPalpedia'}}
 local allowed={};for _,n in ipairs(C.names)do allowed[n]=true end
 local warm={'WBP_MCInventory2','WBP_MCInventory3','WBP_MCGameMenu','WBP_MCDeath'}
 local T=dofile(ctx.base..'/timers.lua')
 function C:hide(w)
  if not ctx.valid(w)then return end
  for _,r in pairs(self.entries)do if r.widget:GetAddress()==w:GetAddress()then w:SetRenderOpacity(0);w:SetVisibility(self.parkVisibility);return end end
  w:RemoveFromParent()
 end
 function C:get(env,name,kind,prebuild)
  if not allowed[name]then return ctx.create(env,name,kind,prebuild)end
  local r=self.entries[name];local scale=ctx.scale and ctx.scale(env);local language=ctx.locale and ctx.locale()
  if r and(r.scale~=scale or r.language~=language)and ctx.valid(r.widget)then if ctx.retire then ctx.retire(r)end;r.widget:SetRenderOpacity(0);r.widget:RemoveFromParent();self.entries[name]=nil;r=nil;ctx.log('MC53_UI_SCALE_REBUILD name='..name..' scale='..tostring(scale))end
  if not r or r.epoch~=ctx.epoch()or not ctx.valid(r.widget)then
   r=assert(ctx.create(env,name,kind,true));r.nodes=ctx.widgets(r.widget);r.scale=scale;r.language=language;self.entries[name]=r
  end
  r.reused=r.used==true
  if not prebuild then
   r.used=true;if not r.widget:IsInViewport()then r.widget:AddToViewport(200)end
   r.widget:SetVisibility(0);r.widget:SetRenderOpacity(1)
  end
  return r
 end
 function C:start(env)
  if self.started==ctx.epoch()then return end;self.started=ctx.epoch();local epoch=self.started;local i=1
  T.loop(1,function()
   if epoch~=ctx.epoch()or ctx.quiesced()then return true end
   
   if ctx.UE and ctx.UE.loadingCover51 and(ctx.UE.loadingCover51.at or ctx.UE.loadingCover51.armed)then return false end
   self.coverReleasedL=self.coverReleasedL or os.clock();if os.clock()-self.coverReleasedL<5 then return false end
   local current=ctx.environment();if not current then return false end
   if ctx.primeReady and not ctx.primeReady(current)then return false end
   local name=warm[i];local r=self:get(current,name,'inventory',true)
   if self.prime then self.prime(current,r,name)end
   self:hide(r.widget)
   i=i+1
   if i>#warm then self.ready=true;ctx.log('MC51_UI_PREBUILT count='..#warm..' epoch='..epoch..' opacity=0 plain_graphs_collapsed=true lua_tick=true catalogs_on_first_open=true');return true end
   return false
  end,'ui-prebuild')
 end
 function C:retire()
  for _,r in pairs(self.entries)do if ctx.valid(r.widget)then r.widget:SetRenderOpacity(0);r.widget:RemoveFromParent()end end
 end
 T.onEpoch('ui-cache',function()C.entries={};C.ready=nil;C.started=nil;C.coverReleasedL=nil end)
 return C
end
