-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local C={}
function C.new(limit,ttl)return{rows={},order={},limit=limit,ttl=ttl,hits=0,misses=0}end
function C.get(c,key,now,revision)
 if c.revision~=revision then c.rows={};c.order={};c.revision=revision end
 local row=c.rows[key]
 if row and now<row.untilAt then c.hits=c.hits+1;return true,row.value end
 c.misses=c.misses+1;return false
end
function C.put(c,key,now,value)
 if not c.rows[key]then
  if #c.order>=c.limit then c.rows[table.remove(c.order,1)]=nil end
  c.order[#c.order+1]=key
 end
 c.rows[key]={untilAt=now+c.ttl,value=value}
end
function C.ray(a,b)return string.format('%.4f,%.4f,%.4f:%.4f,%.4f,%.4f',a.X,a.Y,a.Z,b.X,b.Y,b.Z)end
return C
