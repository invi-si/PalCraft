-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(recipes)
 local best,score,hidden={}, {},{}
 local function nativeCount(r)
  local n=0
  for _,options in ipairs(r.cells or r.ingredients or{})do
   if options then local mc=false;for _,id in ipairs(options)do if id:sub(1,3)=='MC_'then mc=true end end;if not mc then n=n+1 end end
  end
  return n
 end
 for _,r in ipairs(recipes)do if r.result:sub(1,3)=='MC_'then local n=nativeCount(r);score[r]=n;best[r.result]=math.min(best[r.result]or math.huge,n)end end
 local book={}
 for _,r in ipairs(recipes)do
  if score[r]and score[r]>best[r.result]then hidden[#hidden+1]={id=r.id,result=r.result,native_ingredients=score[r]}
  else book[#book+1]=r end
 end
 return book,hidden
end
