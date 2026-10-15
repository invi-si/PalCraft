-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(load,valid,log,clock)
 local S={failures={},reported={}}
 clock=clock or os.clock
 function S:failed(path,why)
  self.failures[path]=clock()+30
  if not self.reported[path]then
   self.reported[path]=true;log('MCZ4_SOUND_MISSING tolerated=true path='..path..' reason='..tostring(why))
  end
  return nil
 end
 function S:asset(path)
  if self.failures[path]and clock()<self.failures[path]then return nil end
  local ok,a=pcall(load,path)
  if not ok or not valid(a)then return self:failed(path,ok and 'invalid sound' or a)end
  self.failures[path]=nil;return a
 end
 function S:play(path,play)
  local a=self:asset(path);if not a then return false end
  local ok,why=pcall(play,a)
  if not ok then self:failed(path,why);return false end
  return true
 end
 return S
end
