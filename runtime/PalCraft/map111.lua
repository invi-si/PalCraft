-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local M={enabled=ctx.enabled==true,epoch=nil,attempts=0,rows={},leaving=false};local UE=ctx.UE;local timers=dofile(ctx.base..'/timers.lua');local J=dofile(ctx.base..'/json.lua');local historyN=dofile(ctx.base..'/marker_history.lua')
 local function vec(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 local function guid(p)
  local g={A=p.A,B=p.B,C=p.C,D=p.D};local nonzero=false
  for _,k in ipairs({'A','B','C','D'})do local n=g[k];assert(type(n)=='number'and n%1==0 and n>=-2147483648 and n<=4294967295,'Invalid marker GUID');nonzero=nonzero or n~=0 end
  assert(nonzero,'Native marker rejected');return g
 end
 local function world()return ctx.world()end
 local function write(name,d)
  local text=J.encode(d);local f=assert(io.open(ctx.base..'/'..name,'wb'));assert(f:write(text));assert(f:close())
 end
 local function ledgerPath(id)return 'map111-markers-'..id..'.json'end
 local function ownedID(id)
  return id=='waystone:base'or(type(id)=='string'and(id:match('^island:')or id:match('^waystone:'))and ctx.island.all[id:match(':([^:]+)$')]~=nil)
 end
 function M:loadOwned()
  local id=world();assert(type(id)=='string'and #id==32 and id:match('^%x+$'),'World identity unavailable')
  if self.world==id then return end
  self.world=id;self.rows={};self.historyIndexN=1;self.historyRemovedN=0;self.historyCompleteN=false
  local f=io.open(ctx.base..'/'..ledgerPath(id),'rb');if not f then return end
  local data=f:read('*a');f:close();local old=J.decode(data)
  assert(old.world==id and type(old.rows)=='table','Marker ownership ledger mismatch')
  if old.historyCompleteN==historyN.version then self.historyIndexN=#historyN.rows+1;self.historyCompleteN=historyN.version end
  for _,row in ipairs(old.rows)do assert(ownedID(row.id),'Unexpected owned marker');row.guid=guid(row.guid);self.rows[#self.rows+1]=row end
 end
 function M:saveOwned()
  write(ledgerPath(self.world),{world=self.world,epoch=ctx.epoch(),rows=self.rows,historyCompleteN=self.historyCompleteN})
 end
 local function managerFor(e)
  local manager=UE.Native109(UE.Object('/Script/Pal.Default__PalUtility'),'GetLocationManager',e.player)
  return ctx.valid(manager)and manager or nil
 end
 function M:removeOwned(manager)
  local removed=0

  while #self.rows>0 do
   local row=self.rows[#self.rows];manager:RemoveLocalCustomMarker(guid(row.guid))
   table.remove(self.rows);removed=removed+1;self:saveOwned()
  end
  return removed
 end
 function M:recoverHistoryN(manager)
  if historyN.world~=self.world then
   ctx.log('MCQ2_MAP_HISTORY_SKIP current_world='..tostring(self.world)..' history_world='..tostring(historyN.world))
   return true
  end
  local batch=0
  while self.historyIndexN<=#historyN.rows and batch<24 do
   local row=historyN.rows[self.historyIndexN];assert(ownedID(row.id),'Historical GUID ownership mismatch')
   manager:RemoveLocalCustomMarker(guid(row.guid))
   self.historyIndexN=self.historyIndexN+1;self.historyRemovedN=self.historyRemovedN+1;batch=batch+1
  end
  if self.historyIndexN<=#historyN.rows then return false end
  if not self.historyCompleteN then
   self.historyCompleteN=historyN.version;self:saveOwned()
   ctx.log('MCN_MAP_HISTORY_CLEARED count='..self.historyRemovedN..' public_owned_guids=true')
  end
  return true
 end
 function M:desired(e)return {}end
 function M:admit(e)
  if not self.enabled or self.leaving or self.epoch==ctx.epoch()or not ctx.ready()then return false end
  local desired=self:desired(e);if not desired then return false end
  local manager=managerFor(e);if not manager then return false end
  self:loadOwned();self.recovered=(self.recovered or 0)+self:removeOwned(manager)
  if not self:recoverHistoryN(manager)then return false end
  self.epoch=ctx.epoch()
  ctx.log('MC111_MAP_PINS_READY count='..#self.rows..' epoch='..self.epoch..' artwork_N=true public_api=true recovered='..self.recovered)
  return true
 end
 function M:beforeExit(e)
  if not self.enabled then return true end

  self.leaving=true;self:loadOwned()
  local removed=0
  if #self.rows>0 then
   assert(e and ctx.ready(),'Marker cleanup requires admitted world')
   local manager=assert(managerFor(e),'Marker cleanup manager unavailable')
   removed=self:removeOwned(manager)
  end
  self:saveOwned();ctx.log('MC111B_MAP_PINS_CLEARED count='..removed..' epoch='..ctx.epoch()..' before_travel=true')
  return true
 end
 function M:snapshot(e)
  local data={enabled=self.enabled,world=self.world or world(),epoch=self.epoch,attempts=self.attempts,rows=self.rows,leaving=self.leaving,recovered=self.recovered,historyRemovedN=self.historyRemovedN,historyCompleteN=self.historyCompleteN,receipt='owned scalar GUIDs; verify visibility with real M',player=vec(e.player:K2_GetActorLocation())}
  write('task111-map-status.json',data);ctx.log('MC111_MAP_STATUS owned='..#self.rows..' epoch='..tostring(self.epoch)..' public_api=true')
  return data
 end
 if not M.enabled then ctx.log('MC111B_MAP_PINS_DISABLED artwork_retained=true');return M end
 timers.loop(500,function()
  if M.leaving or not ctx.ready()then return false end
  if M.epoch==ctx.epoch()then return false end
  if M.attempts>=1 then return false end
  local e=ctx.environment();if not e then return false end
  local ok,result=pcall(function()return M:admit(e)end)
  if not ok then M.attempts=M.attempts+1;ctx.log('MC111_MAP_PINS_ERROR attempt='..M.attempts..' '..tostring(result))end
  return false
 end,'native-map-pins111')
 timers.onEpoch('native-map111',function()M.epoch=nil;M.world=nil;M.rows={};M.attempts=0;M.leaving=false;M.recovered=nil end)
 return M
end
