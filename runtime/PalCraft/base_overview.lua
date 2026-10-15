-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,h)
    local B={page=0};local UE,valid,log=ctx.UE,ctx.valid,ctx.log;local nodes,root,model,container,rows;local pageSize=ctx.config.task20_ui and 7 or 8
    local icons={};for k,v in pairs(dofile(ctx.base..'/native_icons.lua'))do icons[k:lower()]=v end
    local function str(v)return type(v)=='string'and v or v:ToString()end
    function B:findModel(env)
        local c=env.player.InsideBaseCampCheckComponent;local m=valid(c)and c:GetInsideBaseCampModel();if valid(m)then return m end
    end
    function B:refresh(env)
        rows={};container=model.WorkerDirector.CharacterContainer;assert(valid(container),'Native base worker container unavailable')
        for i=0,container:Num()-1 do local slot=container:Get(i);if valid(slot)and not slot:IsEmpty()then
            local d=slot.ReplicateIndividualParameter;if valid(d)then local id=str(d:GetCharacterID());local nick=str(d.SaveParameter.NickName);if nick==''then local out={};_G.MC_OUT_K('GetDisplayNickName',UE.Object('/Script/Pal.Default__PalUIUtility'),env.player,UE.FindOrAddFName(id),UE.FindOrAddFName('None'),out);nick=out.OutNickName and str(out.OutNickName)or id end
                rows[#rows+1]={slot=slot,d=d,id=id,name=nick,icon=icons[('T_'..id..'_icon_normal'):lower()]}
            else rows[#rows+1]={slot=slot,name='Loading Pal...'}end
        end end
        local baseName=str(model:GetBaseCampName());if baseName==''or baseName:find('(仮)',1,true)or baseName:find('テンプレート',1,true)then baseName='Base 1'end
        h.text(nodes.Title,baseName..'    Lv '..model:GetLevel());h.text(nodes.BaseStats,'Pals '..#rows..' / '..container:Num())
        self.page=math.min(self.page,math.max(0,math.ceil(#rows/pageSize)-1))
        for i=1,8 do local r=i<=pageSize and rows[self.page*pageSize+i];h.icon(nodes['PalIcon'..i],r and r.icon);h.text(nodes['PalText'..i],r and(r.d and string.format('%s  Lv %d  HP %.0f/%d\nHunger %.0f%%  Sanity %.0f%%',r.name,r.d:GetLevel(),r.d:GetHP().Value/1000,r.d:GetMaxHP(),r.d:GetFullStomachRate()*100,r.d:GetSanityRate()*100)or r.name)or'')end
        h.text(nodes.Page,(self.page+1)..' / '..math.max(1,math.ceil(#rows/pageSize)))
        if not self.selected or not valid(self.selected.d)then self.selected=rows[1]end;self:detail(env,self.selected)
        local value=#rows..':'..container:Num();if self.logged~=value then self.logged=value;log('MC_H_BASE_DATA native_count='..#rows..' displayed='..#rows..' limit='..container:Num()..' level='..model:GetLevel())end
    end
    function B:detail(env,r)
        self.selected=r;h.icon(nodes.Portrait,r and r.icon)
        if not r then h.text(nodes.Name,'No base Pals');for _,n in ipairs({'Stats','Condition','Work','Status'})do h.text(nodes[n],'')end;h.text(nodes.MoveBox,'No Pal selected');return end
        if not valid(r.d)then h.text(nodes.Name,r.name);for _,n in ipairs({'Stats','Condition','Work','Status'})do h.text(nodes[n],'')end;h.text(nodes.MoveBox,self.actionAvailable and'Move to Pal Box'or'Membership actions: native screen');return end
        local d=r.d;h.text(nodes.Name,r.name..'    Lv '..d:GetLevel());h.text(nodes.Stats,string.format('HP %.0f / %d\nAttack %d  Defense %d',d:GetHP().Value/1000,d:GetMaxHP(),d:GetShotAttack(),d:GetDefense()))
        h.text(nodes.Condition,string.format('Hunger %.0f%%    Sanity %.0f%%',d:GetFullStomachRate()*100,d:GetSanityRate()*100))
        local works={};for i=1,13 do local n=d:GetWorkSuitabilityRank(i);if n>0 then works[#works+1]=h.nativeText(env,'GetWorkSuitabilityName',i)..' '..n end end
        h.text(nodes.Work,ctx.config.task20_ui and ctx.uiKit:wrap(table.concat(works,' / '),118,5)or'Work suitability: '..table.concat(works,', '))
        local handle=r.slot:GetHandle();local out={};local lib=UE.Object('/Script/Pal.Default__PalUIUtility')
        lib:GetWorkingDetailNameFromHandle(env.player,handle,out);h.text(nodes.Status,out.outName and str(UE.GetKismetTextLibrary():Conv_TextToString(out.outName))or'Native work status unavailable')
        h.text(nodes.MoveBox,self.actionAvailable and'Move to Pal Box'or'Membership actions: native screen')
    end
    function B:show(env,view,owner)
        nodes,root=view,owner;model=self:findModel(env);assert(valid(model),'No native base at this interaction');self.page=0;self.selected=nil

        self.actionAvailable=false;self:refresh(env)
    end
    function B:tick(env,tick)if tick%10==0 then self:refresh(env)end end
    function B:click(env,x,y)
        if ctx.config.task20_ui then x,y=ctx.uiKit:mapInput('WBP_MCBase',x,y)end
        if x>=65 and x<535 and y>=243 and y<283 and self.actionAvailable and self.selected then
            local slot=self.selected.slot;local total=#rows;local lib=UE.Object('/Script/Pal.Default__PalUtility');local net=lib:GetNetworkTransmitterByPlayerCharacter(env.player):GetBaseCamp()
            local s=slot:GetSlotId();local g=s.ContainerId.ID
            net:RequestMoveWorkerToPalBox_ToServer(model:GetId(),{ContainerId={ID={A=g.A,B=g.B,C=g.C,D=g.D}},SlotIndex=s.SlotIndex},0,model:GetOwnerMapObjectInstanceId())
            self.selected=nil;self:refresh(env);log('MC_H_BASE_MOVE_REQUEST before='..total..' after='..#rows..' native_rpc=true');return
        end
        if x>=65 and x<535 and y>=291 and y<331 then ctx.nativeBase();log('MC_H_BASE_NATIVE_SCREEN');return end
        if x>=-540 and x<30 and y>=-210 and y<254 then local i=math.floor((y+210)/58)+1;if i<=pageSize then self:detail(env,rows[self.page*pageSize+i])end;return end
        if y>=278 and y<320 then if x>=-40 and x<-2 then self.page=math.max(0,self.page-1)elseif x>=3 and x<41 then self.page=math.min(math.max(0,math.ceil(#rows/pageSize)-1),self.page+1)end;self:refresh(env)end
    end
    function B:cancel()nodes,root,model,container,rows=nil,nil,nil,nil,nil;self.selected=nil;self.logged=nil end
    dofile(ctx.base..'/timers.lua').onEpoch('base-overview',function()B:cancel()end)
    return B
end
