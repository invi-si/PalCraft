-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
if package.loaded['PalCraft.local_data']then return package.loaded['PalCraft.local_data']end
local cache={};local L={}
function L.load(base,name)
 assert(type(name)=='string'and name:match('^[%w_]+$'),'Invalid local data module')
 local key=base..'/'..name;if cache[key]then return cache[key]end
 local path=base..'/assets/minecraft/_palcraft/data/'..name..'.json'
 local file=io.open(path,'rb')
 if not file then return dofile(base..'/jar_data.lua').load(base,name)end
 local text=file:read(16777217);file:close()
 assert(text and #text<=16777216,'Generated Minecraft data exceeds size limit: '..name)
 local J=dofile(base..'/json.lua');local value=J.decode(text)
 if type(value)=='table'and value.format=='palcraft-lua-table-v1'then
  local function unpackTable(node)
   if type(node)~='table'then return node end
   assert(type(node.entries)=='table','Invalid generated table encoding')
   local result={}
   for _,entry in ipairs(node.entries)do
    local k=entry.key;assert(type(k)=='string'or type(k)=='number','Invalid generated table key')
    assert(result[k]==nil,'Duplicate generated table key')
    result[k]=unpackTable(entry.value)
   end
   return result
  end
  value=unpackTable(value.value)
 end
 assert(type(value)=='table','Generated Minecraft data must be a table: '..name)
 if name=='registry'then
  assert(value[1]and value[1].name=='dirt','Generated registry must preserve the legacy dirt slot')
  local seen={};for _,row in ipairs(value)do
   assert(type(row.name)=='string'and not seen[row.name]and type(row.mesh)=='string','Invalid generated block binding')
   seen[row.name]=true
  end
 elseif name=='item_registry'then
  assert(type(value.items)=='table'and type(value.order)=='table','Invalid generated item registry')
 elseif name=='strings57'then
  assert(type(value.items)=='table'and type(value.ui)=='table'and type(value.fragments)=='table','Invalid generated language table')
 end
 cache[key]=value;return value
end
package.loaded['PalCraft.local_data']=L
return L
