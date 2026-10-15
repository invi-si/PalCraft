-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local M={}
local function key(value)
 if type(value)~='string'then return value end
 return(value:gsub('^sunny_','bram_'):gsub('^zuri_','rina_'))
end
function M.journal(state)
 if type(state)~='table'then return state end
 if type(state.limits)=='table'then
  local changes={}
  for name,row in pairs(state.limits)do if key(name)~=name then changes[#changes+1]={old=name,new=key(name),row=row}end end
  for _,change in ipairs(changes)do
   local existing=state.limits[change.new]
   if existing and type(existing)=='table'and type(change.row)=='table'then

    existing.used=math.max(tonumber(existing.used)or 0,tonumber(change.row.used)or 0)
    existing.resetAt=math.max(tonumber(existing.resetAt)or 0,tonumber(change.row.resetAt)or 0)
   else state.limits[change.new]=change.row end
   state.limits[change.old]=nil
  end
 end
 if type(state.pending)=='table'then state.pending.key=key(state.pending.key)end
 if type(state.receipts)=='table'then for _,row in pairs(state.receipts)do if type(row)=='table'then row.key=key(row.key)end end end
 return state
end
return M
