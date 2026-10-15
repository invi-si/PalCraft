-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(base,testWorld)
 local W={id=nil,testWorld=testWorld}
 function W:valid(id)return type(id)=='string'and #id==32 and id:match('^%x+$')~=nil end
 function W:path(stem,extension)
  assert(self:valid(self.id),'World identity not admitted')
  return base..'/'..stem..'-'..self.id..(extension or '.json')
 end
 function W:select(id,canChange,reset)
  if not self:valid(id)then return false end;id=id:upper()
  if id==self.id then return true end
  if not canChange then return false end
  local previous=self.id;self.id=id;reset(id,previous);return true
 end
 function W:testsAllowed()return self.id==self.testWorld end
 return W
end
