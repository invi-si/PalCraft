-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local D={pending={},events={}}
 function D:give(env,id,n,queue)
  if n<=0 then return true end
  if not ctx.capacity(env,id,n)then
   if queue then self.pending[id]=(self.pending[id]or 0)+n;ctx.log('MC66_DROP_DEFER id='..id..' count='..n..' inventory_full=true');return true end
   return false
  end
  local before=ctx.native:count(env,id);ctx.native:add(env,id,n);local after=ctx.native:count(env,id)
  assert(after==before+n,'Direct drop must conserve native inventory');ctx.log('MC66_DROP_DIRECT id='..id..' before='..before..' after='..after..' count='..n)
  self.events[#self.events+1]={id=id,before=before,after=after,count=n};if #self.events>64 then table.remove(self.events,1)end;return true
 end
 function D:tick(env)
  for id,n in pairs(self.pending)do if self:give(env,id,n,false)then self.pending[id]=nil end;break end
 end
 local T=dofile(ctx.base..'/timers.lua');T.onEpoch('drop-fallback66',function()D.pending={};D.events={}end)
 ctx.UE.drops66=D;return D
end
