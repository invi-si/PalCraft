-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,d)
 if d.x6Rebuilt then return d end
 local key=d.key or 'plains'
 assert(key=='plains' or key=='desert' or key=='jungle' or key=='mushroom')
 local spec=dofile(ctx.base..'/island_x6_'..key..'.lua')
 
 for _,a in ipairs({'X','Y','Z'})do assert(d.origin[a]==spec.origin[a],'X6 origin changed: '..key..' '..a)end
 for k in pairs(d)do d[k]=nil end
 for k,v in pairs(spec)do d[k]=v end
 if key=='plains'then dofile(ctx.base..'/slice_world_x8.lua')(ctx.base,d)end
 return d
end
