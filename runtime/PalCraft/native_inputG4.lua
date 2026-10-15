-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,G)
 local T=dofile(ctx.base..'/timers.lua');local R={radialOpen=false,hooks={}}
 local path='/Game/Pal/Blueprint/UI/PlayerRadialMenu/WBP_PlayerRadialMenu.WBP_PlayerRadialMenu_C:'
 function R:install()
  if self.installed then return end
  for _,event in ipairs({'OpenSetup','CloseSetup'})do
   local fn=path..event
   if ctx.valid(StaticFindObject(fn))then
    local opening=event=='OpenSetup'
    T.hook(fn,function()
     self.dirty=true;self.radialOpen=opening
     if not opening then self.closedAt=os.clock()end
    end)
    self.hooks[#self.hooks+1]=event
   end
  end
  self.installed=#self.hooks==2
  ctx.log('MCG4_RADIAL_HOOKS '..table.concat(self.hooks,','))
 end
 function R:tick(e)
  if not self.dirty then return end
  self.dirty=nil;self.row=nil
  for _,w in ipairs(FindAllOf('WBP_PlayerRadialMenu_C')or{})do
   if G:active(w,e.controller)and G:radialOpen(w)then self.row=G:capture(w);break end
  end
  local was=self.radialOpen;self.radialOpen=self.row~=nil
  if was and not self.radialOpen then self.closedAt=os.clock()end
  ctx.log('MCG4_RADIAL_OWNER open='..tostring(self.radialOpen))
 end
 function R:blocksMenu(at)

  return self.radialOpen or(self.closedAt and os.clock()-self.closedAt<.35)
   or(at and self.closedAt and at<=self.closedAt and self.closedAt-at<.35)
 end
 function R:status()return{open=self.radialOpen,dirty=self.dirty==true,closedAt=self.closedAt,hooks=self.hooks}end
 function R:releaseMain(e)return G:releaseMain(e.controller)end
 T.onEpoch('native-inputG4',function()R.radialOpen=false;R.dirty=nil;R.row=nil;R.closedAt=nil end)
 return R
end
