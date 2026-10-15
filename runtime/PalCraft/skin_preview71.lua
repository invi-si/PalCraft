-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local R={frames=16,width=80,height=112}
local function parts(slim)
 local a=slim and 3 or 4
 return {{-4,-4,24,8,8,8,0,0,32,0,.5},{-4,-2,12,8,4,12,16,16,16,32,.25},{-4-a,-2,12,a,4,12,40,16,40,32,.25},{4,-2,12,a,4,12,32,48,48,48,.25},{-4,-2,0,4,4,12,0,16,0,32,.25},{0,-2,0,4,4,12,16,48,0,48,.25}}
end
function R.frame(image,model,index,atlas)
 local angle=index*math.pi*2/R.frames;local c,s=math.cos(angle),math.sin(angle);local quads={};local width=R.width*R.frames
 local function project(x,y,z)return {R.width/2+(x*c+y*s)*2.9,100-z*2.9+(y*c-x*s)*.55,y*c-x*s}end
 for _,b in ipairs(parts(model=='slim'))do for layer=0,1 do
  local k=layer==1 and b[11]or 0;local x,y,z=b[1]-k,b[2]-k,b[3]-k;local xx,yy,zz=b[1]+b[4]+k,b[2]+b[5]+k,b[3]+b[6]+k
  local u,v=b[layer==0 and 7 or 9],b[layer==0 and 8 or 10];local w,d,h=b[4],b[5],b[6]
  local faces={
   {{x,y,zz},{x,y,z},{xx,y,z},{xx,y,zz},u+d,v+d,w,h,1},
   {{x,yy,zz},{x,yy,z},{x,y,z},{x,y,zz},u,v+d,d,h,.8},
   {{xx,y,zz},{xx,y,z},{xx,yy,z},{xx,yy,zz},u+d+w,v+d,d,h,.8},
   {{xx,yy,zz},{xx,yy,z},{x,yy,z},{x,yy,zz},u+2*d+w,v+d,w,h,.95},
   {{x,yy,zz},{x,y,zz},{xx,y,zz},{xx,yy,zz},u+d,v,w,d,1},
   {{x,y,z},{x,yy,z},{xx,yy,z},{xx,y,z},u+d+w,v,w,d,.65}}
  for fi,f in ipairs(faces)do
   local points={};for i=1,4 do points[i]=project(table.unpack(f[i]))end
   local winding=(points[2][1]-points[1][1])*(points[3][2]-points[1][2])-(points[2][2]-points[1][2])*(points[3][1]-points[1][1])
   if winding<0 then
    local function point(a,b)local p={};for j=1,3 do p[j]=points[1][j]*(1-a)*(1-b)+points[2][j]*(1-a)*b+points[3][j]*a*b+points[4][j]*a*(1-b)end;return p end
    for py=0,f[8]-1 do for px=0,f[7]-1 do
     local ty=fi==6 and(f[6]+f[8]-1-py)or(f[6]+py);local tex=image.pixels[ty*64+f[5]+px+1]
     if tex and tex[4]>=128 then local q={point(px/f[7],py/f[8]),point(px/f[7],(py+1)/f[8]),point((px+1)/f[7],(py+1)/f[8]),point((px+1)/f[7],py/f[8])};q.color={math.floor(tex[1]*f[9]),math.floor(tex[2]*f[9]),math.floor(tex[3]*f[9]),255};q.depth=(q[1][3]+q[3][3])/2;quads[#quads+1]=q end
    end end
   end
  end
 end end
 table.sort(quads,function(a,b)return a.depth>b.depth end)
 for _,q in ipairs(quads)do
  local lo,hi=R.height,0;for i=1,4 do lo=math.min(lo,q[i][2]);hi=math.max(hi,q[i][2])end
  for y=math.max(0,math.ceil(lo-.5)),math.min(R.height-1,math.floor(hi-.5))do
   local hits={};for i=1,4 do local a,b=q[i],q[i%4+1];if(y+.5>=a[2]and y+.5<b[2])or(y+.5>=b[2]and y+.5<a[2])then hits[#hits+1]=a[1]+(y+.5-a[2])*(b[1]-a[1])/(b[2]-a[2])end end
   if #hits>=2 then table.sort(hits);for x=math.max(0,math.ceil(hits[1]-.5)),math.min(R.width-1,math.floor(hits[#hits]-.5))do atlas[y*width+index*R.width+x+1]=q.color end end
  end
 end
end
return R
