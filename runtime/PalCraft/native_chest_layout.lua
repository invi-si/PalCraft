-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local layouts={}
for _,size in ipairs({27,54})do
    local slots={}
    for i=1,size do slots[#slots+1]={name='Storage'..i,kind='external',index=i,x=-240+(i-1)%9*54,y=(size==27 and-173 or-335)+math.floor((i-1)/9)*54}end
    for i=1,27 do slots[#slots+1]={name='Main'..i,kind='main',index=i,x=-240+(i-1)%9*54,y=25+math.floor((i-1)/9)*54}end
    for i=1,9 do slots[#slots+1]={name='Bar'..i,kind='bar',index=i,x=-240+(i-1)*54,y=199}end
    layouts['NativeChest'..size]={slots=slots,prev={160,-15,40,36},next={208,-15,40,36},storagePrev={-240,-30,40,36},storageNext={-188,-30,40,36}}
end
return layouts
