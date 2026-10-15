-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local factory=dofile(ctx.base..'/island.lua');local primary=factory(ctx)
 local all={plains=primary};primary.all=all
 local dataSet=dofile(ctx.base..'/islands88_data.lua');for k,v in pairs(dofile(ctx.base..'/islands89_data.lua'))do assert(not dataSet[k]);dataSet[k]=v end

 for key,shift in pairs(dofile(ctx.base..'/island_offsets89.lua'))do
  local d=assert(dataSet[key]);local function move(p)for _,axis in ipairs({'X','Y','Z'})do p[axis]=p[axis]+(shift[axis]or 0)end end
  move(d.origin);move(d.dock);move(d.arrival);move(d.statue)
  for _,chest in ipairs(d.chests or{})do move(chest.position)end
 end
 for key,data in pairs(dataSet)do
  local child={};for k,v in pairs(ctx)do child[k]=v end;child.data=data
  all[key]=factory(child)
 end
 local keys={};for k in pairs(all)do if k~='plains'then keys[#keys+1]=k end end;table.sort(keys)
 local timers=dofile(ctx.base..'/timers.lua');local starts={};for k,i in pairs(all)do starts[k]=i.start end
 local function nearby(i,p)
  local d=i.data;local mid=(d.min or 0)+d.size/2
  local x=d.origin.X+mid*100*(d.signX or 1);local y=d.origin.Y+mid*100*(d.signY or -1)
  return(p.X-x)^2+(p.Y-y)^2<=34000^2
 end
 local function nearestAt(p)
  local nearest,distance
  for k,i in pairs(all)do if nearby(i,p)then
   local d=i.data;local mid=(d.min or 0)+d.size/2
   local x=d.origin.X+mid*100*(d.signX or 1);local y=d.origin.Y+mid*100*(d.signY or -1)
   local ds=(p.X-x)^2+(p.Y-y)^2
   if not distance or ds<distance then nearest=k;distance=ds end
  end end
  return nearest
 end
 function primary:request(key,e)
  local i=assert(all[key],'Unknown island');local stamp=ctx.epoch()
  if i.requested109~=stamp then i.requested109=stamp;ctx.log('MC109_ISLAND_REQUEST key='..key..' epoch='..stamp)end
  starts[key](i,e);return i.admitted and i.footingReady and i.epoch==stamp
 end
 function primary:loadNearby(e)
  local p=e.player:K2_GetActorLocation()
  local cover=ctx.UE.loadingCover51
  if cover and(cover.at or cover.armed)then
   local nearest=nearestAt(p)
   if nearest then self:request(nearest,e)end
   return
  end
  for k,i in pairs(all)do if nearby(i,p)then self:request(k,e)end end
 end
 function primary:start(e)
  self:loadNearby(e)
  local stamp=ctx.epoch();if self.watch109==stamp then return end;self.watch109=stamp
  ctx.log('MC109_ISLAND_DISTANCE_STREAM radius_m=340 epoch='..stamp..' no_unload=true')
  timers.loop(500,function()
   if stamp~=ctx.epoch()or ctx.quiesced()then return true end
   local current=ctx.environment();if current and ctx.ready()then self:loadNearby(current)end;return false
  end,'islands-distance109')
 end
 function primary:nearbyReady(e)
  if ctx.config.island==false then return true end
  if not e then return false end;local p=e.player:K2_GetActorLocation()
  local cover=ctx.UE.loadingCover51
  if cover and(cover.at or cover.armed)then
   local key=nearestAt(p);if not key then return true end;local i=all[key]
   return i.admitted and i.footingReady and i.epoch==ctx.epoch()
  end
  for _,i in pairs(all)do if nearby(i,p)and(not i.admitted or not i.footingReady or i.epoch~=ctx.epoch())then return false end end
  return true
 end
 function primary:allReady()
  for _,i in pairs(all)do if not i.admitted or not i.footingReady or i.epoch~=ctx.epoch()then return false end end
  return true
 end
 function primary:at(p)
  for _,i in pairs(all)do local d=i.data;local x=(p.X-d.origin.X)/100;local z=(d.origin.Y-p.Y)/100
   if x>=d.min and x<d.min+d.size and z>=d.min and z<d.min+d.size then return i end
  end
 end
 function primary:owned(a)
  if not ctx.valid(a)then return false end
  for _,i in pairs(all)do if i.admitted and i:owns(a)then return true end end
  return false
 end
 return primary
end
