-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local C={}
local function copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
local function integer(n)return type(n)=='number'and n==math.floor(n)and n>=0 and n<1000000000 end
local function count(d,id)return d.counts[id]or 0 end
function C.new(state)
 state=state or{version=1,serial=0,limits={},receipts={}}
 assert(state.version==1 and type(state.limits)=='table'and type(state.receipts)=='table'and integer(state.serial),'Invalid X8 journal')
 return setmetatable({state=state,busy=false,nonces={}}, {__index=C})
end
function C:quote(offer,batches,inv,now)
 if self.state.pending or self.locked then return nil,'Trade recovery required' end
 if self.busy then return nil,'Trade in progress' end
 if not integer(batches)or batches<1 or batches>(offer.maxBatches or 64)then return nil,'Invalid quantity' end
 local q={cost={},give={},batches=batches,key=offer.key}
 for id,n in pairs(offer.cost)do assert(integer(n)and n>0);q.cost[id]=n*batches end
 for id,n in pairs(offer.give)do assert(integer(n)and n>0 and not q.cost[id]);q.give[id]=n*batches end
 for id,n in pairs(q.cost)do
  if count(inv,id)<n then return nil,id=='Money'and'Not enough gold'or('Not enough '..id)end
 end
 if q.cost.Money and inv.gold<q.cost.Money then return nil,'Not enough gold'end
 if offer.limit then
  local r=self.state.limits[offer.key];local used=r and now<r.resetAt and r.used or 0
  if used+batches>offer.limit.max then return nil,'Exchange limit reached' end
  q.limit={used=used+batches,resetAt=r and now<r.resetAt and r.resetAt or now+offer.limit.seconds}
 end
 return q
end
function C:transact(offer,batches,adapter,nonce,now)
 if self.nonces[nonce]then return false,'Repeated click'end
 local before=adapter.snapshot();local q,reason=self:quote(offer,batches,before,now)
 if not q then return false,reason end
 if not adapter.fits(q,before)then return false,'Inventory full'end
 self.busy=true;self.nonces[nonce]=true
 local s=self.state;s.serial=s.serial+1
 local tx={serial=s.serial,key=offer.key,batches=batches,before=copy(before),cost=q.cost,give=q.give,at=now,state='pending'}
 s.pending=tx
 local saved,err=pcall(adapter.persist,s)
 if not saved then self.locked=true;self.busy=false;return false,'Journal unavailable'end
 local ids={};for id in pairs(q.cost)do ids[id]=true end;for id in pairs(q.give)do ids[id]=true end
 local function same(d,target)
  for id in pairs(ids)do if count(d,id)~=count(target,id)then return false end end

  return adapter.walletFromMoney==true or d.gold==target.gold
 end
 local expected=copy(before)
 for id,n in pairs(q.cost)do expected.counts[id]=count(expected,id)-n end
 for id,n in pairs(q.give)do expected.counts[id]=count(expected,id)+n end
 expected.gold=before.gold-(q.cost.Money or 0)+(q.give.Money or 0)
 local ok,problem=pcall(function()
  for id,n in pairs(q.cost)do
   assert(adapter.remove(id,n)~=false,'debit rejected '..id)
   assert(count(adapter.snapshot(),id)==count(before,id)-n,'debit not synchronous '..id)
  end
  for id,n in pairs(q.give)do assert(adapter.add(id,n)~=false,'grant rejected '..id)end
  assert(same(adapter.snapshot(),expected),'native delta mismatch')
 end)
 if not ok then
  
  local restored=pcall(function()
   for id in pairs(q.give)do local delta=count(adapter.snapshot(),id)-count(before,id);if delta>0 then assert(adapter.remove(id,delta)~=false)end end
   for id in pairs(q.cost)do local delta=count(before,id)-count(adapter.snapshot(),id);if delta>0 then assert(adapter.add(id,delta)~=false)end end
   assert(same(adapter.snapshot(),before),'rollback mismatch')
  end)
  tx.state=restored and'rolled-back'or'recovery-required';tx.error=tostring(problem)
  if not restored then self.locked=true end
 else
  tx.state='committed';if q.limit then s.limits[offer.key]=q.limit end
 end
 tx.after=adapter.snapshot();s.receipts[#s.receipts+1]=copy(tx)
 if #s.receipts>64 then table.remove(s.receipts,1)end
 if tx.state~='recovery-required'then s.pending=nil end
 local final=pcall(adapter.persist,s)
 if not final then s.pending=tx;self.locked=true end
 self.busy=false
 if self.locked then return false,'Trade recovery required'end
 return ok,ok and'Trade complete'or'Trade failed; restored'
end
C.copy=copy
return C
