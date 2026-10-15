-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
    local UE,valid,log=ctx.UE,ctx.valid,ctx.log
    local N={containers={}}
    function N:guid()
        local g=UE.Object('/Script/Engine.Default__KismetGuidLibrary'):NewGuid()
        return {A=g.A,B=g.B,C=g.C,D=g.D}
    end
    local fields={'CommonContainerId','DropSlotContainerId','EssentialContainerId','WeaponLoadOutContainerId','PlayerEquipArmorContainerId','FoodEquipContainerId'}
    function N:inventory(env)return env.controller:GetPalPlayerState():GetInventoryData()end
    function N:container(env,kind)
        if valid(self.containers[kind])then return self.containers[kind]end
        assert(type(kind)=='number','External native container is closed')
        local inventory=self:inventory(env);local out={}
        if _G.MC_OUT_K('TryGetContainerFromInventoryType',inventory,kind,out) and valid(out.OutContainer)then self.containers[kind]=out.OutContainer;return out.OutContainer end
        local manager=UE.Object('/Script/Pal.Default__PalUtility'):GetItemContainerManager(env.player)
        local c=manager:GetContainer(inventory.MyInventoryInfo[assert(fields[kind+1])]);assert(valid(c),'Missing native container '..kind)
        self.containers[kind]=c;return c
    end
    function N:slotId(slot)
        local native=slot:GetSlotId();local g=native.ContainerId.ID
        return {ContainerId={ID={A=g.A,B=g.B,C=g.C,D=g.D}},SlotIndex=native.SlotIndex}
    end
    function N:id(slot)
        return valid(slot)and not slot:IsEmpty() and slot:GetItemId().StaticId:ToString()or nil
    end
    function N:count(env,id)
        if not id then return 0 end
        local count=0
        for _,kind in ipairs(id=='MC_Saddle'and{0,2,3,4,5}or{0,3,4,5})do local c=self:container(env,kind)
            for i=0,c:Num()-1 do local slot=c:Get(i)
                if self:id(slot)==id then count=count+slot:GetStackCount()end
            end
        end
        return count
    end
    function N:find(env,id)
        for _,kind in ipairs(id=='MC_Saddle'and{0,2,3,4,5}or{0,3,4,5})do local c=self:container(env,kind)
            for i=0,c:Num()-1 do local slot=c:Get(i)
                if self:id(slot)==id then return slot,kind,i end
            end
        end
    end
    function N:network(env)
        local transmitter=UE.Object('/Script/Pal.Default__PalUtility'):GetNetworkTransmitterByPlayerCharacter(env.player)
        assert(valid(transmitter));local network=transmitter:GetItem();assert(valid(network));return network
    end
    function N:move(env,source,target,num)
        assert(valid(source)and valid(target),'Native move needs two slots')
        assert(not source:IsEmpty()and num>0 and num<=source:GetStackCount(),'Invalid native move count')
        local id=self:id(source);local before=self:moveCount(env,id);local from=source:GetStackCount()
        self:network(env):RequestMove_ToServer(self:guid(),self:slotId(target),{{SlotId=self:slotId(source),Num=num}})
        assert(self:moveCount(env,id)==before,'Native move changed combined container count')
        local after=self:id(source)==id and source:GetStackCount()or 0
        if after~=from-num then log('MC_NATIVE_MOVE_REJECT id='..id..' requested='..num..' delta='..(from-after));return false end
        log('MC_NATIVE_MOVE id='..id..' num='..num..' conserved='..before..' external='..tostring(valid(self.containers.external))..' from='..self:slotId(source).SlotIndex..' to='..self:slotId(target).SlotIndex)
        if self.changed then self.changed()end
        return true
    end
    function N:moveCount(env,id)
        local count=self:count(env,id);local c=self.containers.external
        if valid(c)then
            for _,kind in ipairs({0,3,4,5})do if self:container(env,kind):GetAddress()==c:GetAddress()then return count end end
            for i=0,c:Num()-1 do local s=c:Get(i);if self:id(s)==id then count=count+s:GetStackCount()end end
        end
        return count
    end
    function N:dispose(env,slot,num)
        assert(valid(slot)and not slot:IsEmpty()and num>0 and num<=slot:GetStackCount())
        local id=self:id(slot);local before=self:count(env,id)
        self:network(env):RequestDispose_ToServer(self:guid(),{SlotId=self:slotId(slot),Num=num})
        assert(self:count(env,id)==before-num,'Native disposal did not settle; stop crafting')
        if self.changed then self.changed()end
    end
    function N:add(env,id,num)
        local before=self:count(env,id)
        if id=='MC_Saddle'and before>0 then log('MCA_SADDLE_ALREADY_OWNED');return end
        local result=self:inventory(env):AddItem_ServerInternal(UE.FindOrAddFName(id),num,false,0,true)
        assert(self:count(env,id)==before+num,'Native grant did not settle '..id..' result='..tostring(result))
        log('MC_NATIVE_ADD '..id..' count='..num)
        if self.changed then self.changed()end
    end
    function N:use(env,slot)
        local id=assert(self:id(slot));local before=self:count(env,id)
        local target=UE.Object('/Script/Pal.Default__PalUtility'):GetIndividualIDByActor(env.player)
        local parameter=env.player.CharacterParameterComponent;local satiety=parameter:GetFullStomach()
        env.controller:RequestUseItemToCharacter({SlotId=self:slotId(slot),Num=1},target)
        log('MC_NATIVE_USE '..id..' before='..before..' after='..self:count(env,id)..' satiety_before='..satiety..' satiety_after='..parameter:GetFullStomach())
        if self.changed then self.changed()end
    end
    function N:drop(env,slot,num)
        local id=assert(self:id(slot));local before=self:count(env,id)
        if id:sub(1,3)=='MC_'and ctx.UE.drops66 then log('MC66_Q_DIRECT id='..id..' before='..before..' after='..before..' retained=true');return true end
        local p=env.player:K2_GetActorLocation();local f=env.player:GetActorForwardVector()
        self:network(env):RequestDrop_ToServer({{SlotId=self:slotId(slot),Num=num}},
            {X=p.X+f.X*150,Y=p.Y+f.Y*150,Z=p.Z},false)
        local after=self:count(env,id)
        log('MC_NATIVE_DROP id='..id..' requested='..num..' delta='..(before-after))
        if self.changed then self.changed()end
        return before-after==num
    end
    dofile(ctx.base..'/timers.lua').onEpoch('native-inventory',function()N.containers={}end)
    return N
end
