-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(view,bindings)
 local bar,seen={},{}
 for i=1,9 do
  local id=bindings[i];local native=id and tonumber(id:match('^native_(%d)$'))
  local e=native and view.slots[3][native-1]or view.first[id]
  bar[i]=e and e.id and(native and e or{id=e.id,count=view.totals[id],slot=e.slot,kind=e.kind,index=e.index})or{count=0}
  if e and e.id then seen[e.id]=true end
 end
 for j=0,view.sizes[3]-1 do local e=view.slots[3][j]
  if e.id and not seen[e.id]then
   for i=1,9 do if not bar[i].id then bar[i]=e;seen[e.id]=true;break end end
  end
 end
 local main={};for i=0,view.sizes[0]-1 do main[#main+1]=view.slots[0][i]end

 local empty=1
 for _,kind in ipairs({3,5})do for i=0,view.sizes[kind]-1 do local e=view.slots[kind][i]
  if e.id then
   while empty<=#main and main[empty].id do empty=empty+1 end
   if empty<=#main then main[empty]=e;empty=empty+1 else main[#main+1]=e end
  end
 end end
 view.barQ3,view.mainQ3=bar,main
end
