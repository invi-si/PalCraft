-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local U,UE,valid=ctx.uiKit,ctx.UE,ctx.valid;local C={open=false};local View=dofile(ctx.base..'/ui67_view.lua')
 local function str(s)return type(s)=='string'and s or s:ToString()end
 local function text(n)return str(UE.GetKismetTextLibrary():Conv_TextToString(n:GetText()))end
 local function number(s)return tonumber(s:gsub('<[^>]+>',''):gsub(',',''):match('[%d%.]+'))end
 function C:native(env)
  if valid(self.owner)and self.epoch==ctx.epoch()and self.rows and#self.rows==5 then return self.owner end
  self.owner=nil;self.rows={}
  for _,w in ipairs(FindAllOf('WBP_InventoryEquipment_C')or{})do if valid(w)and w:GetOwningPlayer():GetAddress()==env.controller:GetAddress()then self.owner=w;break end end
  if not self.owner then return end;self.epoch=ctx.epoch()
  local names={HP='HP',SP='Stamina',MaxHP='HP',MaxSP='Stamina',Power='Attack',Attack='Attack',WorkSpeed='Work speed',CraftSpeed='Work speed',MaxInventoryWeight='Weight',Weight='Weight'}
  names['最大HP']='HP';names['最大SP']='Stamina';names['攻撃力']='Attack';names['作業速度']='Work speed';names['所持重量']='Weight'
  for i=0,5 do local w=self.owner['WBP_InventoryEquipment_StatusPointButton'..(i==0 and''or'_'..i)];if valid(w)then
   local name=str(w.BindStatusPointName);local label=names[name];ctx.log('MC67_STAT_BIND name='..name..' label='..text(w.Text_Main))
   if label then self.rows[#self.rows+1]={name=name,label=label,widget=w}end
  end end
  table.sort(self.rows,function(a,b)local order={HP=1,Stamina=2,Attack=3,['Work speed']=4,Weight=5};return order[a.label]<order[b.label]end)
  return self.owner
 end
 function C:snapshot(env)
  local d=env.player.CharacterParameterComponent:GetIndividualParameter();local out={points=d:GetUnusedStatusPoint(),level=d:GetLevel(),rows={}}
  if not self:native(env)then return out end
  for _,r in ipairs(self.rows)do
   local w=r.widget;local base={};w['Get Base Parameter'](w,false,base)
   local add,enhance={},{};local allowed=d:IsStatusPointAddable(w.BindStatusPointName,add);w:CanEnhanceStat(enhance);allowed=allowed and enhance.bCanEnhance
   
   w:ResetSimulate();w['Update Binded Status Detail'](w,false);local before=number(text(w.Text_Param))or base.Parameter
   w:AddSimulatePoint(1);w['Update Binded Status Detail'](w,false);local after=number(text(w.Text_Param));w:ResetSimulate();w['Update Binded Status Detail'](w,false)
   out.rows[#out.rows+1]={name=r.name,label=r.label,current=before,next=after,gain=after and before and after-before,allowed=allowed and(add.AddablePoint or 0)>0,widget=w}
  end
  return out
 end
 function C:paint(ns,env,B)
  local snapshot=self:snapshot(env);self.last=snapshot;self.ns=ns;local u=B.uiUnit
  local V=View(ctx,U,ns,u);UE.drawer67Open=self.open
  if self.open then
   V:sprite('CharacterPanel',96,-83,188,166,'T_MC_UI_panel');V:text('CharacterTitle',104,-75,138,'Character');V:button('Collapse',265,-77,12,'<','collapse',false,false,12)
   V:text('CharacterLevel',104,-60,75,'Level '..snapshot.level);V:text('CharacterPoints',175,-60,100,snapshot.points..' points available',true,nil,1,2)
   V:text('Attribute',104,-44,79,'Attribute');V:text('CurrentNext',183,-44,90,'Current > next',true,nil,1,2)
   for i,r in ipairs(snapshot.rows)do local y=-29+(i-1)*19
    V:text('StatName'..i,104,y,61,r.label)
    V:text('StatValue'..i,168,y,82,r.current and r.next and(string.format('%g > %g',r.current,r.next))or'Stat preview unavailable',true,nil,1,2)
    V:text('StatGain'..i,165,y+8,85,r.gain and('+'..string.format('%g',r.gain)..' / 1 point')or'',true,nil,1,2)
    V:button('StatAdd'..i,257,y,19,'+','spend:'..i,snapshot.points<1 or not r.allowed or not r.gain or r.gain<=0,false,16)
   end
   V:text('Defense',104,69,169,'Defense '..env.player.CharacterParameterComponent:GetDefense()..' / Equipment only')
  else V:button('Character',96,-80,116,'Character > '..snapshot.points..' points','expand')end
  V:finish();U:navTabs(ns,env,'Inventory')
 end
 function C:click(env,x,y,B)
  if not self.ns then return false end
  for _,r in ipairs(self.ns.buttons67 or{})do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then
   if r.disabled then return true end
   if r.action=='expand'or r.action=='collapse'then self.open=r.action=='expand';UE.drawer67Open=self.open;B.dirty=true;B:refresh(env);return true end
   local i=tonumber(r.action:match('^spend:(%d+)$'));if i then
    if self.pendingUntil and os.clock()<self.pendingUntil then return true end
    local now=self:snapshot(env);local row=now.rows[i];if not row or now.points<1 or not row.allowed or not row.gain or row.gain<=0 then return true end
    local owner=assert(self:native(env));self.pendingUntil=os.clock()+.5
    owner['Change to Edit Status Point Mode'](owner,true)
    owner:OnClickedStatusPointIncrementButton(row.widget);owner:ConfirmStatusPoint()
    local after=env.player.CharacterParameterComponent:GetIndividualParameter():GetUnusedStatusPoint()
    ctx.log('MC67_STAT_SPEND stat='..row.name..' before='..now.points..' after='..after..' preview_gain='..row.gain..' native_confirm=true')
    B.dirty=true;B:refresh(env);return true
   end
  end end;return false
 end
 dofile(ctx.base..'/timers.lua').onEpoch('character67',function()C.owner=nil;C.rows=nil;C.ns=nil;C.last=nil;C.pendingUntil=nil end)
 return C
end
