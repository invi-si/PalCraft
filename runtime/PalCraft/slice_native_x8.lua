-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,A,env,persist)
 local N,UE=ctx.items.native,ctx.UE
 local function snapshot()return A.snapshot(env)end
 local function remove(id,num)
  local left=num
  for kind=0,5 do local c=N:container(env,kind);for i=0,c:Num()-1 do local s=c:Get(i)
   if N:id(s)==id and left>0 then local n=math.min(left,s:GetStackCount());N:network(env):RequestDispose_ToServer(N:guid(),{SlotId=N:slotId(s),Num=n});left=left-n end
  end end
  return left==0
 end
 local function add(id,num)
  
  N:inventory(env):AddItem_ServerInternal(UE.FindOrAddFName(id),num,false,0,true)
  return true
 end
 local function fits(q,before)
  local slots={}
  for kind=0,5 do slots[kind]={};local c=N:container(env,kind)
   for i=0,c:Num()-1 do local s=c:Get(i);slots[kind][i+1]={id=N:id(s),count=s:GetStackCount()}end
  end
  for id,n in pairs(q.cost)do local left=n
   for kind=0,5 do for _,s in ipairs(slots[kind])do if s.id==id and left>0 then local take=math.min(s.count,left);s.count=s.count-take;left=left-take;if s.count==0 then s.id=nil end end end end
   if left>0 then return false end
  end
  local ids={};for id in pairs(q.give)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do
   local d=ctx.items:data(id);if not ctx.valid(d)then return false end
   local stack=tonumber(d.MaxStackCount);if not stack or stack<1 then return false end
   if id=='MC_Saddle'and(before.counts[id]or 0)>0 then return false end
   local target=slots[id=='MC_Saddle'and 2 or 0];local left=q.give[id]
   for _,s in ipairs(target)do if s.id==id and left>0 then local n=math.min(left,math.max(0,stack-s.count));s.count=s.count+n;left=left-n end end
   for _,s in ipairs(target)do if not s.id and left>0 then local n=math.min(left,stack);s.id=id;s.count=n;left=left-n end end
   if left>0 then return false end
  end
  return true
 end
 return{snapshot=snapshot,remove=remove,add=add,fits=fits,persist=persist,walletFromMoney=true}
end
