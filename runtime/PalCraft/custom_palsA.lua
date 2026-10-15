-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local data=dofile(ctx.base..'/custom_palsA_data.lua')
 local x8=dofile(ctx.base..'/slice_x8_data.lua').alpha
 data[x8.id]={name='PatchworkBrute',island='plains',attack=true,position=x8.position,ground=x8.ground}
 local C={data=data,classes={},events={},ready=false,scans=0,actors={},pending={},known={},cursor=0}
 C.motion=dofile(ctx.base..'/custom_motionAc.lua')(ctx)
 C.size=dofile(ctx.base..'/custom_sizeB.lua')(ctx)
 C.alphaX8=dofile(ctx.base..'/slice_alpha_x8.lua')(ctx)
 C.fx=dofile(ctx.base..'/custom_fxI.lua')(ctx)
 local function record(kind,id,extra)
  local v=extra or{};v.kind=kind;v.id=id;v.at=os.clock();C.events[#C.events+1]=v
  if #C.events>80 then table.remove(C.events,1)end
  ctx.log('MCA_CUSTOM_'..kind..' id='..tostring(id))
 end
 local function replace(context,_,actionClass)
  if not C.ready or not ctx.ready()then return end
  local component=context:get();if not valid(component)then return end
  local actor=component:GetOwner();if not valid(actor)then return end
  
  local e=ctx.environment()
  local cp=actor.CharacterParameterComponent;if not valid(cp)then return end
  local ip=cp:GetIndividualParameter();if not valid(ip)then return end
  local id=ip:GetCharacterID():ToString();local replacement=C.classes[id]
  if e and e.controller:IsRiding()and valid(e.controller.Pawn)and e.controller.Pawn:GetAddress()==actor:GetAddress()
   and id~='MC_Warden'and id~='MC_Wither'and id~='MC_EnderDragon'then return end
  if not valid(replacement)then return end
  local original=actionClass:get();if not valid(original)then return end
  local needle=(id=='MC_Wither'or id=='MC_EnderDragon')and'BP_ActionAirCanon_C'or id=='MC_Warden'and'BP_Action_Unique_Gorilla_GroundPunch_C'or'BP_Action_Unique_PinkCat_CatPunch_C'
  local originalName=original:GetFullName()
  local modern=needle:gsub('BP_Action_Unique_','BP_UniqueAction_')
  if not originalName:find(needle,1,true)and not originalName:find(modern,1,true)and not originalName:find('BP_DebugMissWaza_C',1,true)then return end
  actionClass:set(replacement);record('ATTACK_SELECTED',id,{actor=actor:GetAddress()})
  if id=='CP_FungalHost'then C.fx:queue(actor,os.clock(),true)end
 end
 T.hook('/Script/Pal.PalActionComponent:PlayAction',replace)
 T.hook('/Script/Pal.PalActionComponent:PlayActionParameter',replace)
 
 local notifiedX8={}
 for id,spec in pairs(data)do
  if not notifiedX8[spec.name]then notifiedX8[spec.name]=true
  NotifyOnNewObject('/Game/CustomPalsA1/BP_'..spec.name..'.BP_'..spec.name..'_C',function(a)
   if #C.pending<64 then C.pending[#C.pending+1]={actor=a,id=id,epoch=T.epoch}end
  end)
  end
 end
 T.loop(100,function()
  if not ctx.ready()then return end
  local e=ctx.environment();if not e then return end
  if not C.ready then

   if UE.loadingCover51 and(UE.loadingCover51.at or UE.loadingCover51.armed)then return end
   if not C.startupJobsX7 then
    C.startupJobsX7={};C.startupIndexX7=1
    for id,spec in pairs(data)do
     UE.zombie77.farmGround.data.species[id]=spec
     if spec.attack then
      local name='BP_Action_A_'..spec.name
      C.startupJobsX7[#C.startupJobsX7+1]={id=id,path='/Game/CustomPalsA1/'..name..'.'..name..'_C'}
     end
    end
    C.startupJobsX7[#C.startupJobsX7+1]={id='MC_IronGolem',path='/Game/CustomPalsA1/BP_Action_Ac_Golem.BP_Action_Ac_Golem_C'}
   end
   local job=C.startupJobsX7[C.startupIndexX7]
   if job then
    
    C.classes[job.id]=UE.zombie77:asset(job.path);C.startupIndexX7=C.startupIndexX7+1
    return false
   end
   C.startupJobsX7=nil;C.startupIndexX7=nil
   C.classes.MC_Wither=C.classes.MC_IronGolem;C.classes.MC_EnderDragon=C.classes.MC_IronGolem
   C.classes.MC_Warden=C.classes.MC_IronGolem
   C.ready=true;C.fx:install();record('READY','all')
  end
  C.fx:tick(e,os.clock())
  C.alphaX8:tick(e,os.clock())
  local row=table.remove(C.pending,1)
  if row and row.epoch==T.epoch and valid(row.actor)then
   local a=row.actor;local cp=a.CharacterParameterComponent
   if not valid(cp)then
    row.tries=(row.tries or 0)+1;if row.tries<20 then C.pending[#C.pending+1]=row end
   else
    local w=a:GetWorld()
    if valid(w)and w:GetAddress()==e.world:GetAddress()then
     local ip=cp:GetIndividualParameter();if not valid(ip)then C.pending[#C.pending+1]=row;return false end
     local actual=ip:GetCharacterID():ToString();if not data[actual]then return false end;row.id=actual
     local name=a:GetFullName();C.known[name]=row.id
     local found=false;for _,v in ipairs(C.actors)do if v.name==name then found=true end end
     if not found then C.actors[#C.actors+1]={actor=a,id=row.id,name=name}end
    end
   end
  end
  if #C.actors==0 then return end
  C.cursor=C.cursor%#C.actors+1;row=C.actors[C.cursor]
  local a,id=row.actor,row.id
  if not valid(a)then table.remove(C.actors,C.cursor);C.cursor=C.cursor-1;return end
  local now=os.clock();if now<(row.due or 0)then return end;row.due=now+1
  if valid(a.CharacterParameterComponent)then
   T.measure('custom:size',C.size.sample,C.size,a,e,id)
   if id==x8.id then C.alphaX8:check(a,e,id)else T.measure('custom:ground',UE.zombie77.farmGround.check,UE.zombie77.farmGround,a,e,id)end 
   if id~=x8.id then T.measure('custom:motion',C.motion.sample,C.motion,a,e,id)end 
  end
 end,'custom-palsA')
 T.onEpoch('custom-palsA',function()
  C.events={};C.scans=0;C.actors={};C.pending={};C.cursor=0;C.motion:reset();C.size:reset();C.alphaX8:reset()
  
  T.after(1000,function()for name,id in pairs(C.known)do local a=StaticFindObject(name);if valid(a)then C.pending[#C.pending+1]={actor=a,id=id,epoch=T.epoch}end end end,'custom-reacquire')
 end)
 return C
end
