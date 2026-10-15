-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local function overlaps(a,b)
 return a.x<b.x+b.w and a.x+a.w>b.x and a.y<b.y+b.h and a.y+a.h>b.y
end
return function(x,y,w,h,screen,exclude)
 local function clamp(v,a,b)return math.max(a,math.min(b,v))end
 local px,py=x+12,y-12
 if px+w>screen.right then px=x-w-12 end
 if py+h>screen.bottom then py=y-h-12 end
 px=clamp(px,screen.left,screen.right-w);py=clamp(py,screen.top,screen.bottom-h)
 local xs,ys={px},{py}
 for _,r in ipairs(exclude or{})do
  xs[#xs+1]=clamp(r.x-w-4,screen.left,screen.right-w);xs[#xs+1]=clamp(r.x+r.w+4,screen.left,screen.right-w)
  ys[#ys+1]=clamp(r.y-h-4,screen.top,screen.bottom-h);ys[#ys+1]=clamp(r.y+r.h+4,screen.top,screen.bottom-h)
 end
 local best,score
 for _,xx in ipairs(xs)do for _,yy in ipairs(ys)do
  local a={x=xx,y=yy,w=w,h=h};local clear=true
  for _,r in ipairs(exclude or{})do if overlaps(a,r)then clear=false;break end end
  local d=(xx-px)^2+(yy-py)^2
  if clear and(not score or d<score)then best,score=a,d end
 end end
 return best
end
