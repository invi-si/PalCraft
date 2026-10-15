-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(load,valid)
 local Q={rows={},seen={},index=1,ready={}}
 function Q:add(key,paths)
  if self.ready[key]~=nil then return end
  self.ready[key]=false
  for _,p in ipairs(paths)do if not self.seen[p]then self.seen[p]=true;self.rows[#self.rows+1]={path=p}end end
  self.rows[#self.rows+1]={key=key}
 end
 function Q:tick()
  while self.rows[self.index]do
   local row=self.rows[self.index];self.index=self.index+1
   if row.key then self.ready[row.key]=true else load(row.path);return true end
  end
  return false
 end
 function Q:pending()return self.index<=#self.rows end
 return Q
end
