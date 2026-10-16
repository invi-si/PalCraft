-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local L={width=195,height=136,columns=9,rows=5,pitch=18}
L.search={82-97.5,6-68,86,10}
L.track={175-97.5,18-68,12,90}
L.delete={173-97.5,111-68,18,18}
L.tabs={
 {category='building',label='Building Blocks',icon='MC_Bricks',x=0,y=-28},
 {category='coloured',label='Colored Blocks',icon='MC_RedWool',x=28,y=-28},
 {category='natural',label='Natural Blocks',icon='MC_GrassBlock',x=56,y=-28},
 {category='functional',label='Functional Blocks',icon='MC_CraftingTable',x=84,y=-28},
 {category='search',label='Search Items',icon='MC_Compass',x=167,y=-28},
 {category='tools',label='Tools & Utilities',icon='MC_IronPickaxe',x=0,y=132},
 {category='combat',label='Combat',icon='MC_IronSword',x=28,y=132},
 {category='food',label='Food & Drinks',icon='MC_Bread',x=56,y=132},
 {category='materials',label='Ingredients',icon='IronIngot',x=84,y=132},
 {category='inventory',label='Survival Inventory',icon='MC_Chest',x=167,y=132},
}
L.container={width=L.width,height=L.height,slots={},prev={0,0,0,0},next={0,0,0,0}}
for i=1,45 do L.container.slots[#L.container.slots+1]={name='Main'..i,kind='main',index=i,x=9-97.5+(i-1)%9*18,y=18-68+math.floor((i-1)/9)*18}end
for i=1,9 do L.container.slots[#L.container.slots+1]={name='Bar'..i,kind='bar',index=i,x=9-97.5+(i-1)*18,y=112-68}end
function L.maxRow(count)return math.max(0,math.ceil(count/9)-5)end
function L.clampRow(row,count)return math.max(0,math.min(L.maxRow(count),math.floor(row or 0)))end
function L.dragRow(y,count)return L.clampRow(math.floor(((y-L.track[2]-7.5)/75)*L.maxRow(count)+.5),count)end
function L.thumbY(row,count)local max=L.maxRow(count);return L.track[2]+(max>0 and math.floor(75*L.clampRow(row,count)/max+.5)or 0)end
function L.tabSprite(t,selected)
 local side=t.y<0 and'top'or'bottom';local column=t.x==0 and 1 or t.x==167 and 7 or 2
 return 'T_MC_UI_creative_tab_'..side..'_'..(selected and'selected'or'unselected')..'_'..column
end

function L.pause(height)
 local buttons={[2]={-102,0,204},[1]={-102,0,204},[4]={-102,0,98},[9]={4,0,98},[3]={-102,0,98},[6]={4,0,98},[7]={-102,0,98},[5]={4,0,98},[8]={-102,0,204}}
 local rows={[2]=5,[1]=0,[4]=1,[9]=1,[3]=2,[6]=2,[7]=3,[5]=3,[8]=4}
 for i,b in pairs(buttons)do b[2]=8-height/4+rows[i]*24 end
 return buttons,{-102,40-height/2,204,15}
end
return L
