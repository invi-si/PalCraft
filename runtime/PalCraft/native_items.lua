-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local I={registry=dofile(ctx.base..'/item_registry.lua'),cache={}}
 I.native=dofile(ctx.base..'/native_inventory.lua')(ctx)
 function I:data(id)
  if ctx.valid(self.cache[id])then return self.cache[id]end
  for _,row in ipairs(FindAllOf('PalStaticItemDataBase')or{})do
   if ctx.valid(row)then self.cache[row.ID:ToString()]=row end
  end
  return self.cache[id]
 end
 function I:label(id)return id:gsub('^MC_',''):gsub('_',' ')end
 return I
end
