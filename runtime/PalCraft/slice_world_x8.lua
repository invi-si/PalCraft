-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(base,d)
 if d.sliceX8 then return end
 local x=dofile(base..'/slice_x8_data.lua');d.x5Resources=d.x5Resources or{};d.chests=d.chests or{}
 local seen={};for _,n in ipairs(d.x5Resources)do seen[n.id]=true end
 for _,n in ipairs(x.nodes)do if not seen[n.id]then d.x5Resources[#d.x5Resources+1]=n end end
 local found=false;for _,c in ipairs(d.chests)do if c.id==x.reward.id then found=true end end
 if not found then d.chests[#d.chests+1]={id=x.reward.id,position=x.reward.position}end
 d.sliceX8=true
end
