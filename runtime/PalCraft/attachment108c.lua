-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local A={cache={}}
 local T=dofile(ctx.base..'/timers.lua')
 T.onEpoch('attachment108c',function()A.cache={};A.lookupFrame=nil end)
 function A:resolve(o,name,bounded)
  if not ctx.valid(o)then return nil end
  if not o:IsA(ctx.UE.Object('/Script/Engine.MeshComponent'))then return nil end
  local full=o:GetFullName()
  if name and full~=name then return nil end
  local address=o:GetAddress();local row=self.cache[address]
  if row then
   local source=self:source(row)
   if source and row.sourceName==full then return source,full end
   self.cache[address]=nil
  end

  if bounded and self.lookupFrame==T.frameCounter then return nil,nil,true end
  self.lookupFrame=T.frameCounter
  local concrete=StaticFindObject(full:match('^%S+ (.+)$')or full)
  if not ctx.valid(concrete)or not concrete:IsA(ctx.UE.Object('/Script/Engine.MeshComponent'))then return nil end
  if concrete:GetAddress()~=o:GetAddress()or concrete:GetFullName()~=full then return nil end
  self.cache[address]={source=concrete,sourceName=full,sourceAddress109=address,concrete109=true}
  return concrete,full
 end
 function A:source(v)

  if not v.concrete109 then
   local o,name=self:resolve(v.source,v.sourceName)
   if not o then return nil end
   v.source=o;v.sourceName=name;v.sourceAddress109=o:GetAddress();v.concrete109=true
   return o
  end
  local o=v.source
  if not ctx.valid(o)or not o:IsA(ctx.UE.Object('/Script/Engine.MeshComponent'))then return nil end
  if o:GetAddress()~=v.sourceAddress109 or o:GetFullName()~=v.sourceName then return nil end
  return o
 end
 return A
end
