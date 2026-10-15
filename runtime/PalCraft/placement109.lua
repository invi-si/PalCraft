-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(UE,log,now)
 now=now or os.clock
 local P={waits={},failed={}}
 function P:ready(key,p,radius,probe)
  if self.failed[key]then return nil end
  local value

  if UE.restoreReady109 and not UE.restoreReady109(p,radius)then self.waits[key]=nil;return nil end
  value=probe()
  if value then
   if self.waits[key]then log('MC109C_PLACEMENT_RESUMED key='..key)end
   self.waits[key]=nil;return value
  end
  local at=now()
  if not self.waits[key]then self.waits[key]=at;log('MC109C_PLACEMENT_WAIT key='..key)end
  if at-self.waits[key]>=3 then
   self.failed[key]=true;log('MC109C_PLACEMENT_FAILED key='..key..' reason=support-timeout3s')
  end
 end
 function P:reset()self.waits={};self.failed={}end
 return P
end
