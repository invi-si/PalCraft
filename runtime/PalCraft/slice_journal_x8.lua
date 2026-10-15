-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(J,path)
 local M={}
 function M.load()
  local f=io.open(path,'rb');if not f then
   local previous=io.open(path..'.previous','rb');if previous then previous:close();error('X8 journal missing with previous receipt; recovery required')end
   return nil
  end
  local s=f:read('*a');f:close()
  local base=debug.getinfo(1,'S').source:sub(2):gsub('slice_journal_x8.lua$','')
  return dofile(base..'npc_legacy.lua').journal(J.decode(s))
 end
 function M.save(state)
  local data=J.encode(state);assert(J.decode(data).version==1)
  local f=assert(io.open(path..'.tmp','wb'));assert(f:write(data));assert(f:close())
  local old=io.open(path,'rb');if old then local b=old:read('*a');old:close();local p=assert(io.open(path..'.previous','wb'));assert(p:write(b));assert(p:close())end
  
  f=assert(io.open(path,'wb'));assert(f:write(data));assert(f:close())
  f=assert(io.open(path,'rb'));local actual=f:read('*a');f:close();assert(actual==data,'X8 journal verify failed')
 end
 return M
end
