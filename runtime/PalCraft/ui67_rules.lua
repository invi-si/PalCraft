-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local R={}

function R.inventoryFit(width,height,requested,expanded)
 local scale=math.max(1,math.min(requested,math.floor(width/408),math.floor(height/240)))
 local half=width/(2*scale)-8
 local shift=expanded and -98 or -math.max(0,212-half)
 return scale,shift
end
function R.contains(s,q)return q==''or tostring(s or''):lower():find(q:lower(),1,true)~=nil end
function R.pals(rows,state)
 local out={};local q=state.query or''
 for _,r in ipairs(rows)do
  if (R.contains(r.name,q)or R.contains(r.id,q)or R.contains(r.number,q))and(not state.type or r.types[state.type])and(not state.passive or r.passives[state.passive])and(not state.work or(r.works[state.work]or 0)>0)and(not state.favourites or r.favourite)then out[#out+1]=r end
 end
 local key=state.sort or'Manual'
 table.sort(out,function(a,b)
  if key=='Level'and a.level~=b.level then return a.level>b.level end
  if key=='Name'and a.name~=b.name then return a.name<b.name end
  if key=='Favourite'and a.favourite~=b.favourite then return a.favourite end
  return a.index<b.index
 end);return out
end
function R.technology(rows,state)
 local out={};for _,r in ipairs(rows)do
  if (R.contains(r.label,state.query or'')or R.contains(r.id,state.query or''))and(not state.category or r.category==state.category)and(not state.available or(r.available and not r.unlocked))and(not state.pinned or state.pins[r.id])then out[#out+1]=r end
 end;return out
end
function R.page(index,count,size)return math.max(0,math.min(index or 0,math.max(0,math.ceil(count/size)-1)))end
function R.selection(rows,selected)
 local out={count=0,protected=0,locked=0,move={}}
 for _,r in ipairs(rows)do if selected[r.key]then out.count=out.count+1;if r.favourite then out.protected=out.protected+1 end;if r.locked then out.locked=out.locked+1 else out.move[#out.move+1]=r end end end
 return out
end
function R.canRelease(r)return r and not r.favourite and not r.locked end

function R.moveSelection(rows,state,current)
 local chosen=state.multi and state.selected or(current and{[current.key]=true}or{})
 local out=R.selection(rows,chosen);out.toParty={};out.toBox={}
 for _,r in ipairs(out.move)do local list=r.party and out.toBox or out.toParty;list[#list+1]=r end
 return out
end
return R
