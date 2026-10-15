-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,d)
 if d.x5Expanded then return d end
 local key=d.key or 'plains';local spec=assert(dofile(ctx.base..'/island_x5_manifest.lua')[key])
 local o=d.origin
 local function move(p)if p then p.X=o.X+2*(p.X-o.X);p.Y=o.Y+2*(p.Y-o.Y)end end
 for _,f in ipairs({'dock','arrival','statue'})do move(d[f])end
 for _,c in ipairs(d.chests or {})do move(c.position)end
 local old=d.heights;local h={}
 for x=1,280 do h[x]={};for z=1,280 do h[x][z]=old[math.ceil(x/2)][math.ceil(z/2)]end end
 for _,p in ipairs(spec.heightPatches)do h[p[1]][p[2]]=math.max(h[p[1]][p[2]],p[3])end
 local water={}
 for k,v in pairs(d.water or {})do local x,z=k:match('^(-?%d+):(-?%d+)$');if x then x=tonumber(x);z=tonumber(z);for a=0,1 do for b=0,1 do water[(x*2+a)..':'..(z*2+b)]=v end end end end
 d.key=key;d.min=-140;d.size=280;d.heights=h;d.water=water;d.classPath=spec.classPath;d.chunks=spec.chunks
 d.arrival={X=spec.arrival.X,Y=spec.arrival.Y,Z=spec.arrival.Z};d.resourcesStatic=false;d.x5Resources=spec.resources;d.x5Expanded=true
 return d
end
