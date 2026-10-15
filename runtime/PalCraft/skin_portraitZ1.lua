-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local R={width=24,height=36}
function R.render(image,model)
 local pixels={};for i=1,R.width*R.height do pixels[i]={0,0,0,0}end
 local arm=model=='slim'and 3 or 4
 local function face(x,y,w,h,u,v)
  for yy=0,h-1 do for xx=0,w-1 do
   local p=image.pixels[(v+yy)*64+u+xx+1];local i=(y+yy)*R.width+x+xx+1
   if p and p[4]>0 then
    local b=pixels[i];local a=p[4]/255;local ba=b[4]/255;local out=a+ba*(1-a)
    pixels[i]={math.floor((p[1]*a+b[1]*ba*(1-a))/out+.5),math.floor((p[2]*a+b[2]*ba*(1-a))/out+.5),math.floor((p[3]*a+b[3]*ba*(1-a))/out+.5),math.floor(out*255+.5)}
   end
  end end
 end
 face(8,2,8,8,8,8);face(8,10,8,12,20,20)
 face(8-arm,10,arm,12,44,20);face(16,10,arm,12,36,52)
 face(8,22,4,12,4,20);face(12,22,4,12,20,52)
 face(8,2,8,8,40,8);face(8,10,8,12,20,36)
 face(8-arm,10,arm,12,44,36);face(16,10,arm,12,52,52)
 face(8,22,4,12,4,36);face(12,22,4,12,4,52)
 return pixels
end
return R
