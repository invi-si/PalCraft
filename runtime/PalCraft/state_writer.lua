-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local W={};local J,S=ctx.json,ctx.state
 local refs,parts,meta,at
 function W:cancel()if ctx.cancelCommit then ctx.cancelCommit()end;refs=nil;parts=nil;meta=nil;at=nil end
 function W:active()return refs~=nil end
 function W:step(budget)
  local started=os.clock()
  if not refs then
   refs={};for _,c in pairs(ctx.cells())do refs[#refs+1]=c end
   parts={};at=1;meta=ctx.metadata()
  end
  while at<=#refs and (os.clock()-started)*1000<budget do
   local c=refs[at];local row=S.row(c,ctx.name(c));local encoded=J.encode(row)
   parts[#parts+1]=encoded;at=at+1
  end
  if at>#refs then
   if ctx.commitStep then if not ctx.commitStep(parts,meta)then return false end
   else ctx.commit(parts,meta)end
   self:cancel();return true
  end
  return false
 end
 return W
end
