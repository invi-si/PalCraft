-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,D,E,F,h)
 local U,UE,valid=ctx.uiKit,ctx.UE,ctx.valid
 local R=dofile(ctx.base..'/ui67_rules.lua');local View=dofile(ctx.base..'/ui67_view.lua');local J=dofile(ctx.base..'/json.lua')
 local S={states={},palCache={}};local ns,mode,env,V
 local titles={Pals='Pals',PC='Pal Box',Technology='Technology',Palpedia='Palpedia'}
 local function str(v)
  local kind=type(v)
  if kind=='string'then return v end
  if v==nil then return'None'end
  if kind=='number'or kind=='boolean'then return tostring(v)end
  return v:ToString()
 end
 local function txt(v)return str(UE.GetKismetTextLibrary():Conv_TextToString(v))end
 local function unwrap(v)local ok,o=pcall(function()return v:get()end);return ok and o or v end
 local function arr(v)local a={};if type(v)=='table'then for _,x in ipairs(v)do a[#a+1]=unwrap(x)end else v:ForEach(function(_,x)a[#a+1]=unwrap(x)end)end;return a end
 local function native(method,id)local o={};local u=UE.Object('/Script/Pal.Default__PalUIUtility');u[method](u,env.player,id,o);return o.outName and txt(o.outName)or o.OutText and txt(o.OutText)or tostring(id)end
 local function db()return UE.Object('/Script/Pal.Default__PalUtility'):GetDatabaseCharacterParameter(env.player)end
 local function t(s)return UE.language57:t(s)end
 local function num(n)return string.format('%g',n or 0)end
 local function hp(n)return string.format('%.0f',n or 0)end
 local function inside(r,x,y)return x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h end
 function S:supports(k)return titles[k]~=nil end
 function S:state(k)
  if not self.states[k]then self.states[k]={query='',page=0,sort='Manual',selected={},dexTab='Pals',dexFilter='All'}end;return self.states[k]
 end
 function S:loadPins()
  local path=UE.worldScope65:path('ui-pins');if self.pinPath==path then return end
  self.pinPath=path;self.pins={};local f=io.open(path,'rb');if f then local ok,d=pcall(J.decode,f:read('*a'));f:close();if ok and type(d)=='table'then for k,v in pairs(d)do if type(k)=='string'and v==true then self.pins[k]=true end end end end
 end
 function S:savePins()local f=assert(io.open(self.pinPath..'.tmp','wb'));f:write(J.encode(self.pins));f:close();os.remove(self.pinPath);assert(os.rename(self.pinPath..'.tmp',self.pinPath))end
 function S:pal(slot,index,inParty)
  local p=E:pal(slot);if not p then return end
  local d=p.d;local key=tostring(d:GetAddress());local cached=self.palCache[key]
  if not cached then
   cached={key=key,id=p.id,name=p.name,icon=p.icon,types={},passives={},passiveLabels={},works={},workLabels={},number=tostring(db():GetZukanIndex(UE.FindOrAddFName(p.id)))}
   local a,b={},{};db():GetElementType(UE.FindOrAddFName(p.id),a,b);for _,id in ipairs({a.Element1 or 0,b.Element2 or 0})do if id>0 then cached.types[id]=true end end
   for _,id in ipairs(arr(d.SaveParameter.PassiveSkillList))do local name=str(id);cached.passives[name]=true;cached.passiveLabels[#cached.passiveLabels+1]=native('GetPassiveSkillName',id)end
   for id=1,13 do local rank=d:GetWorkSuitabilityRank(id);if rank>0 then cached.works[id]=rank;cached.workLabels[#cached.workLabels+1]=native('GetWorkSuitabilityName',id)..' '..rank end end
   cached.partner=native('GetPartnerSkillName',UE.FindOrAddFName(p.id));self.palCache[key]=cached
  end
  cached.slot,cached.d,cached.index,cached.party=slot,d,index,inParty;cached.name=p.name;cached.level=d:GetLevel();cached.hp=d:GetHP().Value/1000;cached.max=d:GetMaxHP();cached.favourite=d:IsFavoritePal();cached.locked=slot:IsLocked()
  return cached
 end
 function S:palRows()
  self.party,self.box=E:containers(env);local parties,boxes={},{}
  for i=0,self.party:Num()-1 do parties[i+1]=self:pal(self.party:Get(i),i,true)or false end
  
  local st=self:state('PC');local start=st.box or 0
  for i=start*30,math.min(self.box:Num()-1,start*30+29)do local p=self:pal(self.box:Get(i),i,false);if p then boxes[#boxes+1]=p end end
  self.partyRows,self.boxRows=parties,boxes
 end
 function S:selectedPal()
  local st=self:state(mode);for _,r in pairs(self.partyRows or{})do if r and r.key==st.pal then return r end end
  for _,r in ipairs(self.boxRows or{})do if r.key==st.pal then return r end end
  for _,r in pairs(self.partyRows or{})do if r then st.pal=r.key;return r end end
  if self.boxRows[1]then st.pal=self.boxRows[1].key;return self.boxRows[1]end
 end
 function S:detail(p,x,y,w)
  if not p then V:text('NoPal',x,y,w,'Empty slot');return end
  V:text('SelectedName',x,y,w,p.name,true,nil,2);V:text('SelectedLevel',x,y+24,w,'Lv '..p.level)
  local labels={};for id in pairs(p.types)do labels[#labels+1]=native('GetPalElementTypeName',id)end
  V:text('Types',x,y+36,w,table.concat(labels,' / '))
  V:text('HP',x,y+52,w,'HP '..hp(p.hp)..' / '..hp(p.max));V:bar('HP',x,y+65,w,p.hp/math.max(1,p.max))
  V:text('Stats',x,y+78,w,'Attack '..p.d:GetShotAttack()..'   Defense '..p.d:GetDefense())
  V:text('PartnerTitle',x,y+96,w,'Partner skill');V:well('Partner',x,y+109,w,24);V:text('Partner',x+4,y+115,w-8,p.partner,false)
  V:text('ActiveTitle',x,y+138,w,'Active skills')
  local database=UE.Object('/Script/Pal.Default__PalUtility'):GetWazaDatabase(env.player)
  for i,id in ipairs(arr(p.d:GetEquipWaza()))do if i>3 then break end;local out={};if _G.MC_OUT_K('FindWazaForBP',database,id,out)then local row=out.OutData or out;V:text('Active'..i,x,y+152+(i-1)*12,w,native('GetWazaName',id)..' / '..row.Power)end end
  V:text('PassiveTitle',x,y+191,w,'Passive skills')
  V:text('Passives',x,y+204,w,#p.passiveLabels>0 and table.concat(p.passiveLabels,' / ')or'None',true,nil,2)
 end
 function S:paintPals()
  local st=self:state(mode);local p=self:selectedPal();local count=0
  for i=1,5 do local r=self.partyRows[i];local y=-108+(i-1)*40
   V:button('Party'..i,-290,y,132,'','party:'..i,false,r and p and r.key==p.key,37)
   if r then count=count+1;V:icon('PartyIcon'..i,-286,y+4,28,h.asset(r.icon));V:text('PartyName'..i,-253,y+3,90,r.name,false,nil,2);V:text('PartyLevel'..i,-253,y+25,32,'Lv '..r.level,false);V:bar('PartyHP'..i,-215,y+28,53,r.hp/math.max(1,r.max))end
  end
  V:text('PartyTotal',-290,-129,132,'Party '..count..' / 5')
  V:well('Portrait',-150,-108,164,156);if p then V:icon('Portrait',-144,-104,152,h.asset(p.icon));V:text('Exp',-148,50,158,'EXP '..p.d:GetExp(),true)
   local xp=UE.Object('/Script/Pal.Default__PalUtility'):GetExpDatabase(env.player);local low,high=xp:GetTotalExp(p.level,false),xp:GetTotalExp(p.level+1,false)
   V:bar('XP',-148,64,158,(p.d:GetExp()-low)/math.max(1,high-low));V:text('XPProgress',-148,71,158,num(p.d:GetExp()-low)..' / '..num(high-low))
  end
  V:button('Summon',-149,102,78,'Summon','summon',not p);V:button('Compare',-66,102,78,'Compare','compare',not p,st.compare)
  if not st.compare then self:detail(p,27,-108,263)end
  if p then
   V:text('Work',-149,85,158,'Work '..p.d:GetCraftSpeed())
   if st.compare then local other;for _,r in pairs(self.partyRows)do if r and r~=p then other=r;break end end
    if other then V:well('Compare',27,-108,263,222);V:text('ComparisonTitle',34,-99,249,'Compare',false);V:text('ComparisonName',34,-80,249,p.name..' / '..other.name,false,nil,2);V:text('ComparisonHP',34,-48,249,'HP '..hp(p.max)..' / '..hp(other.max),false);V:text('ComparisonAttack',34,-28,249,'Attack '..p.d:GetShotAttack()..' / '..other.d:GetShotAttack(),false);V:text('ComparisonDefense',34,-8,249,'Defense '..p.d:GetDefense()..' / '..other.d:GetDefense(),false);V:text('ComparisonWork',34,12,249,'Work '..p.d:GetCraftSpeed()..' / '..other.d:GetCraftSpeed(),false)end
   end
  end
  V:text('ActionSummary',-290,120,450,'Drag a party card to reorder')
 end
 function S:paintPC()
  local st=self:state(mode);st.box=st.box or 0;local rows=R.pals(self.boxRows,st);self.visibleRows=rows
  V:field('Search',-290,-111,154,st.query,'Search name / number...')
  V:button('Type',-132,-111,84,'Type: '..(st.type and native('GetPalElementTypeName',st.type)or t('All')),'type')
  V:button('Passive',-44,-111,104,'Passive: '..(st.passive and native('GetPassiveSkillName',UE.FindOrAddFName(st.passive))or t('All')),'passive')
  V:button('Work',64,-111,100,'Work: '..(st.work and native('GetWorkSuitabilityName',st.work)or t('All')),'work')
  V:button('Sort',168,-111,122,'Sort: '..st.sort,'sort')
  V:text('PartyLabel',-290,-87,122,'Party');V:button('BoxPrev',-157,-88,18,'<','boxprev');V:text('BoxName',-134,-84,150,'Box '..(st.box+1));V:button('BoxNext',39,-88,18,'>','boxnext')
  V:text('BoxCount',67,-84,100,#rows..' / 30')
  for i=1,5 do local p=self.partyRows[i];local y=-68+(i-1)*32
   V:button('Party'..i,-290,y,124,'','party:'..i,false,p and st.pal==p.key,30)
   if p then V:icon('PartyIcon'..i,-286,y+2,26,h.asset(p.icon));V:text('PartyName'..i,-256,y+3,85,p.name,false);V:text('PartyLevel'..i,-256,y+16,85,'Lv '..p.level,false)end
  end
  for i=1,30 do local p=rows[i];local x,y=-156+(i-1)%6*32,-68+math.floor((i-1)/6)*32
   V:sprite('Slot'..i,x,y,32,32,'T_MC_UI_slot');if p then V:icon('BoxIcon'..i,x+2,y+2,28,h.asset(p.icon));V:text('BoxLevel'..i,x+1,y+21,29,p.level,false,nil,1,2)
    if p.favourite then V:text('Star'..i,x+1,y+1,10,'*',false,{R=1,G=1,B=.3,A=1})end
    if st.selected[p.key]then V:fill('Checked'..i,x+1,y+1,5,5,'55FFFF')end
    if st.pal==p.key then V:fill('Selected'..i,x,y,32,1,'FFFFFF')end
    V.buttons[#V.buttons+1]={x=x,y=y,w=32,h=32,action='box:'..i,pal=p}
   end
  end
  local p=self:selectedPal();V:well('Selected',47,-68,243,160)
  if p then V:icon('SelectedPortrait',53,-62,58,h.asset(p.icon));V:text('SelectedName',119,-61,163,p.name,false,nil,2);V:text('SelectedLv',119,-36,160,'Lv '..p.level,false)
   V:text('SelectedHP',55,1,227,'HP '..hp(p.hp)..' / '..hp(p.max),false);V:bar('SelectedHP',55,15,227,p.hp/math.max(1,p.max))
   V:text('SelectedWork',55,30,227,'Work '..p.d:GetCraftSpeed()..' / '..table.concat(p.workLabels,', '),false,nil,2)
   V:text('SelectedPassives',55,55,227,table.concat(p.passiveLabels,', '),false,nil,2)
  end
  V:button('Favourite',47,96,117,p and p.favourite and'Unmark favourite'or'Mark favourite','favourite',not p)
  V:button('Multi',169,96,121,'Multi-select','multi',false,st.multi)
  local all={};for _,r in pairs(self.partyRows)do if r then all[#all+1]=r end end;for _,r in ipairs(self.boxRows)do all[#all+1]=r end
  local summary=R.moveSelection(all,st,p);self.actionSummary=summary
  V:text('Summary',-290,120,276,summary.count..' selected / '..summary.protected..' favourites protected / '..summary.locked..' locked')
  local busy=E.pending or self.queue or self.swapChoice
  V:button('MoveParty',-290,96,124,'Move to party','moveparty',busy or #summary.toParty==0);V:button('MoveBox',-160,96,96,'Move to box','movebox',busy or #summary.toBox==0)
  if self.swapChoice then V:text('Summary',-290,120,576,'Party full: choose a party Pal to swap')end
  V:button('Clear',-59,96,100,'Clear','clear')
 end
 function S:techRows()
  local language=UE.language57.lang
  if not self.technologies or self.techLanguage67~=language then
   E:techRows(env);self.tech=E.tech;local rows={}
   for _,r in ipairs(E.rows67)do
   local name=txt(self.tech:GetTechnologyName(r.name));name=name:gsub('<itemName id=|([^|]+)|/>',function(id)return ctx.items:label(id)end):gsub('<mapObjectName id=|([^|]+)|/>',function(id)return native('GetMapObjectName',UE.FindOrAddFName(id))end)
   local unlock=self.tech:GetRecipeTechlonogy(r.name);r.builds=arr(unlock.UnlockBuildObjects);r.recipes=arr(unlock.UnlockItemRecipes)
   r.label=name;r.category=r.row.IsBossTechnology and'Ancient'or #r.builds>0 and'Buildings'or'Items'
    rows[#rows+1]=r
   end;self.technologies=rows;self.techLanguage67=language
  end

  E.tech=self.tech
  for _,r in ipairs(self.technologies)do
   r.unlocked=self.tech:IsUnlockRecipeTechnology(r.name);r.available=self.tech:IsUnlockableRecipeTechnology(r.name)
   r.materials67=nil
  end
 end
 function S:techIcon(r)
  if valid(r.icon67)then return r.icon67 end
  local icon=E:techIcon(env,r);if valid(icon)then r.icon67=icon;U:retainTexture(icon)end;return icon
 end
 function S:techReason(r)
  if r.unlocked then return'Unlocked'end;if r.available then return'Available now'end
  local lv=env.player.CharacterParameterComponent:GetIndividualParameter():GetLevel();if lv<r.row.LevelCap then return t('Requires Lv')..' '..r.row.LevelCap..' / '..t('Current level')..' '..lv end
  local points=r.row.IsBossTechnology and self.tech:GetBossTechnologyPoints()or self.tech:GetTechnologyPoints();if points<r.row.Cost then return'Not enough points'end
  local requirement=str(r.row.RequireTechnology);if requirement~='None'and requirement~=''and not self.tech:IsUnlockRecipeTechnology(r.row.RequireTechnology)then return t('Requires technology')..': '..txt(self.tech:GetTechnologyName(r.row.RequireTechnology))end
  local boss=str(r.row.RequireDefeatTowerBoss);if boss~='None'and boss~=''and boss~='0'then return t('Requires boss')..': '..boss end
  local research=str(r.row.RequireResearchId);if research~='None'and research~=''then return t('Requires research')..': '..research end
  return'Native restriction'
 end
 function S:paintTechnology()
  local st=self:state(mode);st.pins=self.pins;local rows=R.technology(self.technologies,st);self.visibleRows=rows;st.page=R.page(st.page,#rows,20)
  V:text('Points',71,-129,219,'Points '..self.tech:GetTechnologyPoints()..' / Ancient '..self.tech:GetBossTechnologyPoints(),true,nil,1,2)
  V:field('Search',-290,-111,177,st.query,'Search technology...');V:button('Category',-108,-111,123,'Category: '..(st.category or'All'),'category')
  V:button('Available',20,-111,131,'Available now','available',false,st.available);local n=0;for _ in pairs(self.pins)do n=n+1 end
  V:button('Pins',156,-111,134,'Pinned recipes: '..n,'pins',false,st.pinned)
  V:sprite('TechBG',-290,-85,360,180,'T_MC_UI20_tech_background')
  for i=1,20 do local r=rows[st.page*20+i];if r then local x,y=-263+(i-1)%5*65,-71+math.floor((i-1)/5)*41
   V:sprite('TechFrame'..i,x,y,26,26,r.unlocked and'T_MC_UI20_tech_obtained'or'T_MC_UI20_tech_unobtained');local icon=V:icon('TechIcon'..i,x+5,y+5,16,self:techIcon(r));local light=(r.unlocked or r.available)and 1 or .4;icon:SetColorAndOpacity({R=light,G=light,B=light,A=1})
   V:text('TechLevel'..i,x-11,y+28,52,'Lv '..r.row.LevelCap..' / '..r.row.Cost,false)
   if self.pins[r.id]then V:text('TechPinned'..i,x+19,y-2,9,'*',false,{R=1,G=1,B=.3,A=1})end
   V.buttons[#V.buttons+1]={x=x,y=y,w=26,h=26,action='tech:'..i,tech=r}
  end end
  local selected;for _,r in ipairs(self.technologies)do if r.id==st.tech then selected=r;break end end;selected=selected or rows[1];self.selectedTech=selected
  if selected then local r=selected;V:text('TechName',82,-83,208,r.label,true,nil,2);V:icon('TechSelectedIcon',256,-52,32,self:techIcon(r));V:text('TechTier',82,-55,166,'Level '..r.row.LevelCap..' / '..r.category)
   V:text('LockReason',82,-33,208,self:techReason(r),true,nil,3)
   local points=r.row.IsBossTechnology and self.tech:GetBossTechnologyPoints()or self.tech:GetTechnologyPoints()
   V:text('TechCost',82,5,208,'Unlock: '..r.row.Cost..' points');V:text('After',82,20,208,'After unlock: '..math.max(0,points-r.row.Cost))
   V:text('Requirements',82,42,208,'Crafting requirements');local mats=self:materials(r)
   for i,m in ipairs(mats)do if i>3 then break end;V:icon('MaterialIcon'..i,83,55+(i-1)*16,14,ctx.items:icon(m.id));V:text('MaterialText'..i,102,57+(i-1)*16,183,ctx.items:label(m.id)..' '..m.have..' / '..m.need)end
   V:button('Unlock',82,101,119,'Unlock - '..r.row.Cost,'unlock',r.unlocked or not r.available);V:button('Pin',206,101,84,self.pins[r.id]and'Unpin recipe'or'Pin recipe','pin')
  end
  V:button('Prev',-290,100,24,'<','prev');V:button('Next',-260,100,24,'>','next');V:text('Page',-226,105,286,(st.page+1)..' / '..math.max(1,math.ceil(#rows/20)))
  V:text('Summary',-290,124,504,'Select to inspect; use Unlock to spend points')
 end
 function S:materials(r)
  if r.materials67 then return r.materials67 end;r.materials67={}

  local ok,err=pcall(function()
   local tables=UE.Object('/Script/Pal.Default__PalUtility'):GetMasterDataTables(env.player)
   local access=#r.recipes>0 and tables.Access_ItemRecipeDataTable or tables.Access_BuildObjectDataTable
   local recipe=r.recipes[1]or r.builds[1];if not recipe then return end
   local result={};local row=access:BP_FindRow(recipe,result);if result.bResult==false then return end
   for i=1,(#r.recipes>0 and 5 or 4)do local id=str(row['Material'..i..'_Id']);local need=row['Material'..i..'_Count'];if id~='None'and need>0 then r.materials67[#r.materials67+1]={id=id,need=need,have=ctx.items.native:count(env,id)}end end
  end)
  if not ok and not self.materialReported then self.materialReported=true;ctx.log('MC67_MATERIAL_API_UNAVAILABLE '..tostring(err))end
  return r.materials67
 end
 local mobs={{id='zombie',label='Zombie',item='MC_RottenFlesh'},{id='skeleton',label='Skeleton',item='MC_Bone'},{id='spider',label='Spider',item='MC_String'},{id='creeper',label='Creeper',item='MC_Gunpowder'}}
 function S:paintPalpedia()
  local st=self:state(mode);V:button('Pals',-290,-111,105,'Pals','dexpals',false,st.dexTab=='Pals');V:button('Bestiary',-180,-111,110,'Bestiary','dexmobs',false,st.dexTab=='Bestiary')
  V:field('Search',-65,-111,185,st.query,'Search name / number...');V:button('Filter',126,-111,164,'Show: '..st.dexFilter,'dexfilter')
  local rows={};for _,r in ipairs(st.dexTab=='Bestiary'and mobs or self.dexRows)do
   if R.contains(r.label,st.query)or R.contains(r.id,st.query)or R.contains(r.number,st.query)then
    if st.dexTab=='Bestiary'or st.dexFilter=='All'or(st.dexFilter=='Seen'and r.detail>=2)or(st.dexFilter=='Caught'and r.detail>=3)then rows[#rows+1]=r end
   end
  end;self.visibleRows=rows;st.page=R.page(st.page,#rows,12);V:well('Index',-290,-84,146,192)
  local selected;for _,r in ipairs(rows)do if r.id==(st.dexTab=='Bestiary'and st.mob or st.dex)then selected=r end end;selected=selected or rows[1]
  for i=1,12 do local r=rows[st.page*12+i];if r then local y=-79+(i-1)*15
   if selected==r then V:fill('Selected'..i,-286,y,138,14,'555555')end
   V:text('DexRow'..i,-282,y+2,130,(r.number and'#'..r.number..' 'or'')..((not r.detail or r.detail>=2)and r.label or'???'),false)
   V.buttons[#V.buttons+1]={x=-286,y=y,w=138,h=15,action='dex:'..i,dex=r}
  end end
  if selected then local r=selected;V:well('Portrait',-134,-84,160,150)
   if st.dexTab=='Bestiary'then

    local texture=self:mobIcon(r.id);if texture then V:icon('MobPortrait',-116,-63,120,texture)end
    V:text('DexName',38,-82,252,r.label);V:text('Habitat',38,-62,252,'Habitat: Island outskirts');V:text('Time',38,-46,252,'Time: Night only');V:text('Catchable',38,-25,252,'Not catchable')
    V:text('Drops',38,-4,252,'Drops');V:icon('Drop1',38,12,18,ctx.items:icon(r.item));V:text('DropName',63,17,226,ctx.items:label(r.item));V:text('NoBonus',-132,78,420,'No capture bonus')
   else
    local discovered=r.detail>=2;local icon=r.icon and h.asset(r.icon);local n=V:icon('Portrait',-124,-80,140,icon);if not discovered then n:SetColorAndOpacity({R=0,G=0,B=0,A=1})end
    V:text('DexName',38,-82,252,discovered and r.label or'???')
    if discovered then
     V:text('Habitat',38,-62,252,'Habitat: See habitat map');V:text('Time',38,-46,252,'Time: '..(db():GetNocturnal(r.name)and'Night only'or'Day and night'))
     local description=native('GetPalLongDescription',r.name);V:text('Description',38,-25,252,description,true,nil,4)
     local rank={};db():GetWorkSuitabilityRank(r.name,rank);local work={};local vals=rank.WorkSuitabilities or{}
     local function add(k,v)k,v=unwrap(k),unwrap(v);if v>0 then work[#work+1]=native('GetWorkSuitabilityName',k)..' '..v end end
     if type(vals)=='table'then for k,v in pairs(vals)do add(k,v)end else vals:ForEach(add)end
     V:text('Work',38,28,252,table.concat(work,' / '),true,nil,2);V:text('Partner',38,58,252,native('GetPartnerSkillName',r.name),true,nil,2)
     local o={};if _G.MC_OUT_K('GetDropItemData',db(),r.name,1,o)then local drop=o.OutData or o;for i=1,5 do local id=str(drop['ItemId'..i]);if id~='None'then V:icon('Drop'..i,38+(i-1)*24,87,18,ctx.items:icon(id));V.buttons[#V.buttons+1]={x=38+(i-1)*24,y=87,w=18,h=18,item=id}end end end
    else V:text('NotSeen',38,-60,252,'Not encountered')end
    V:text('Capture',-132,75,162,'Caught: '..(r.capture55 or 0)..' / Capture bonus: '..(r.bonus55 or 0),true,nil,2)
   end
  end
  V:button('Prev',-290,114,24,'<','prev');V:button('Next',-260,114,24,'>','next');V:text('Page',-225,119,84,(st.page+1)..' / '..math.max(1,math.ceil(#rows/12)))
  local collected=env.controller:GetPalPlayerState():GetRecordData():GetUnlockedPaldexCount();V:text('Collection',75,-129,215,'Collection '..collected..' / '..#self.dexRows,true,nil,1,2)
 end
 function S:mobIcon(id)
  self.mobIcons=self.mobIcons or{};if self.mobIcons[id]~=nil then return self.mobIcons[id]or nil end
  self.mobIcons[id]=U:asset67(id)or false;return self.mobIcons[id]or nil
 end
 function S:paint()
  local at=os.clock();V=View(ctx,U,ns,ns.unit67)
  V:sprite('Panel',-300,-137,600,274,'T_MC_UI_panel');V:text('Title',-290,-129,270,titles[mode])
  V:button('Back',244,116,46,'Back','back')
  if mode=='Pals'then self:paintPals()elseif mode=='PC'then self:paintPC()elseif mode=='Technology'then self:paintTechnology()else self:paintPalpedia()end
  V:finish();self.dirty=false;ctx.log(string.format('MC67_PAINT mode=%s ms=%.3f',mode,(os.clock()-at)*1000))
 end
 function S:show(e,k,nodes,root)
  env,mode,ns=e,k,nodes;local _,u,dpi,size=U:metrics(e);local scale=math.max(1,math.min(math.floor(u*dpi+.5),math.floor(size.X/616),math.floor(size.Y/328)));ns.unit67=scale/dpi;D.uiFactor=ns.unit67/3;D.uiOffset46=0;ns.ui67=true;self:loadPins();U:hideTooltip(ns)
  local canvas=ns.CanvasPanel_0;local dim=ns.Dim
  for key,node in pairs(ns)do if key:sub(1,4)~='S67_'and valid(node)and node:GetAddress()~=canvas:GetAddress()and(not valid(dim)or node:GetAddress()~=dim:GetAddress())then pcall(function()node:SetRenderOpacity(0)end)end end
  canvas:SetRenderOpacity(1);if valid(dim)then dim:SetRenderOpacity(1)end
  U:navTabs(ns,e,k)
  if k=='Pals'or k=='PC'then E:prepare67(e,nodes);self:palRows()
  elseif k=='Technology'then E:prepare67(e,nodes,k);self:techRows()
  else F:prepare67(e,root);self.dexRows=F.catalog55 and F.catalog55.rows or{}end
  self:paint();self.open=true;self.nextData=os.clock()+1;self.ns67=ns;self.mode67=k
 end
 function S:close()self.open=false;self.drag=nil;self.queue=nil;self.swapChoice=nil;self.ns67=nil;self.mode67=nil;ns,mode,env,V=nil,nil,nil,nil end
 function S:move(e,source,target)
  E:move(e,source,target)
  
  if not E.pending then self:palRows();self.dirty=true end
 end
 function S:cycle(st,key,choices)
  local current=st[key];local index=0;for i,v in ipairs(choices)do if v==current then index=i;break end end;st[key]=choices[index+1];st.page=0
 end
 function S:click(e,x,y,shift,right)
  if not self.open then return end;env=e;local hit
  for _,r in ipairs(ns.buttons67 or{})do if inside(r,x,y)then hit=r;break end end
  if hit and hit.field then U:focusField(env,hit.field);return end
  if U:editing()then U:clearField()end
  if not hit or hit.disabled or not hit.action then return end
  local st=self:state(mode);local a=hit.action;ctx.log('MC67_ACTION mode='..mode..' action='..a)
  if a=='back'then D:close();return
  elseif a=='type'then self:cycle(st,'type',{1,2,3,4,5,6,7,8,9})
  elseif a=='work'then self:cycle(st,'work',{1,2,3,4,5,6,7,8,9,10,11,12,13})
  elseif a=='passive'then local list,seen={},{};for _,r in ipairs(self.boxRows)do for id in pairs(r.passives)do if not seen[id]then seen[id]=true;list[#list+1]=id end end end;table.sort(list);self:cycle(st,'passive',list)
  elseif a=='sort'then self:cycle(st,'sort',{'Manual','Level','Name','Favourite'});st.sort=st.sort or'Manual'
  elseif a=='boxprev'or a=='boxnext'then local storage=env.controller:GetPalPlayerState():GetPalStorage();st.box=R.page((st.box or 0)+(a=='boxprev'and-1 or 1),storage:GetPageNum(),1);env.controller:GetPalPlayerState():RequestPalBoxSyncPage_ToServer(st.box);self:palRows()
  elseif a=='multi'then st.multi=not st.multi
  elseif a=='clear'then st.selected={};self.queue=nil;self.swapChoice=nil
  elseif a=='favourite'then local p=self:selectedPal();if p then UE.Object('/Script/Pal.Default__PalUIUtility'):ToggleFavoritePalBySlot(env.player,p.slot);self:palRows()end
  elseif a=='moveparty'or a=='movebox'then self.queue={};local target=a=='moveparty'and self.party or self.box
   for _,r in ipairs(a=='moveparty'and self.actionSummary.toParty or self.actionSummary.toBox)do self.queue[#self.queue+1]={source=r.slot,target=target,key=r.key,toParty=a=='moveparty'}end
  elseif a:match('^party:')then local i=tonumber(a:match('%d+'));local p=self.partyRows[i]
   if self.swapChoice then local job=self.swapChoice;local target=self.party:Get(i-1)
    if not target:IsLocked()then self.swapChoice=nil;st.selected[job.key]=nil;self:move(e,job.source,target)end
   elseif p then st.pal=p.key;if st.multi or shift then st.multi=true;st.selected[p.key]=not st.selected[p.key]else self.drag={pal=p,x=x,y=y,index=i}end end
  elseif a:match('^box:')then local p=hit.pal;st.pal=p.key;if st.multi or shift then st.multi=true;st.selected[p.key]=not st.selected[p.key]end
  elseif a=='summon'then local p=self:selectedPal();if p and p.party then local holder=env.controller.BP_OtomoPalHolderComponent;for _=1,5 do if holder:GetSelectedOtomoID()==p.index then break end;env.controller:OnOtomoChangeIncrement()end;D:close();env.controller:OnOtomo_Pressed();env.controller:OnOtomo_ShortReleased();return end
  elseif a=='compare'then st.compare=not st.compare
  elseif a=='category'then self:cycle(st,'category',{'Buildings','Items','Ancient'})
  elseif a=='available'then st.available=not st.available;st.page=0
  elseif a=='pins'then st.pinned=not st.pinned;st.page=0
  elseif a=='pin'then local r=self.selectedTech;if r then self.pins[r.id]=not self.pins[r.id]or nil;self:savePins()end
  elseif a=='unlock'then local r=self.selectedTech;if r then E:unlock(env,r);self:techRows()end
  elseif a:match('^tech:')then st.tech=hit.tech.id
  elseif a=='prev'or a=='next'then st.page=R.page(st.page+(a=='prev'and-1 or 1),#self.visibleRows,mode=='Technology'and 20 or 12)
  elseif a=='dexpals'or a=='dexmobs'then st.dexTab=a=='dexpals'and'Pals'or'Bestiary';st.page=0
  elseif a=='dexfilter'then self:cycle(st,'dexFilter',{'All','Seen','Caught'});st.dexFilter=st.dexFilter or'All';st.page=0
  elseif a:match('^dex:')then st[st.dexTab=='Bestiary'and'mob'or'dex']=hit.dex.id
  end
  ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);self:paint()
 end
 function S:tick(e)
  if not self.open then return end;env=e;local st=self:state(mode);local field=ns.field67
  if valid(field)then local q=txt(field:GetText());if q~=st.query then st.query=q;st.page=0;self.dirty=true;ctx.log('MC67_SEARCH mode='..mode..' query='..q)end end
  if E.pending then E:checkMove(e);if not E.pending then self:palRows();self.dirty=true end end
  if self.queue and not E.pending and not self.swapChoice then
   local job=table.remove(self.queue,1)
   if job then
    local target;for i=0,job.target:Num()-1 do local slot=job.target:Get(i);if slot:IsEmpty()and not slot:IsLocked()then target=slot;break end end
    if target then st.selected[job.key]=nil;self:move(e,job.source,target)
    elseif job.toParty then self.swapChoice=job;ctx.log('MCA_PC_SWAP_CHOICE party_full=true')
    else ctx.log('MC_E_PC_QUICK_REJECT no_free_slot');self.queue=nil;U:notify('No free slots','')end
   else self.queue=nil end
   self.dirty=true
  end
  local x,y=ctx.items:mouse(e);x,y=x/3,y/3
  if self.drag and not e.controller:IsInputKeyDown({KeyName=UE.FindOrAddFName('LeftMouseButton')})then
   local drag=self.drag;self.drag=nil;if math.abs(x-drag.x)+math.abs(y-drag.y)>8 then for _,r in ipairs(ns.buttons67 or{})do if r.action and r.action:match('^party:')and inside(r,x,y)then local i=tonumber(r.action:match('%d+'));if i~=drag.index then self:move(e,drag.pal.slot,self.party:Get(i-1))end;break end end end
  end
  if self.dirty then self:paint()end
  local tip;for _,r in ipairs(ns.buttons67 or{})do if inside(r,x,y)then
   if r.tech then tip={title=r.tech.label,lines={self:techReason(r.tech),'Cost: '..r.tech.row.Cost..' points'},source='Palworld',exclude=r}
   elseif r.pal then tip={title=r.pal.name,lines={'Lv '..r.pal.level,'HP '..hp(r.pal.hp)..' / '..hp(r.pal.max)},source='Palworld',exclude=r}
   elseif r.item then U:tooltip(ns,{id=r.item,exclude=r},ctx.items:label(r.item),x,y,ns.unit67);return end;break end end
  U:richTooltip(ns,tip,x,y,ns.unit67);U:navHover(ns,e,x,y)
 end
 dofile(ctx.base..'/timers.lua').onEpoch('screens67',function()S:close();S.palCache={};S.states={};S.mobIcons=nil;S.pinPath=nil;S.queue=nil;S.technologies=nil;S.tech=nil;S.techLanguage67=nil end)
 return S
end
