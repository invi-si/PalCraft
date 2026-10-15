-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
    local Timers=dofile(ctx.base..'/timers.lua')
    local T={};local valid,UE,log=ctx.valid,ctx.UE,ctx.log
    function T:close(fromCallback)
        if self.handle then if not fromCallback then Timers.cancel(self.handle)end;self.handle=nil end
        if valid(self.widget)then self.widget:RemoveFromParent()end
        for _,r in ipairs(self.buttons or{})do if valid(r.node)then r.node:SetRenderOpacity(r.opacity)end end;self.buttons=nil
        self.widget,self.owner,self.panel,self.uiFactor,self.nodes=nil,nil,nil,nil,nil;self.allowTitleDialog=nil;log('MC_H_TITLE_CLOSED refs=0')
    end
    function T:show(force)
        if not force then for _,w in ipairs(FindAllOf('PalActivatableWidget')or{})do if valid(w)and w:IsActivated()and w:GetClass():GetFullName():lower():find('dialog',1,true)then log('MC_H_TITLE_WAIT_NATIVE_DIALOG dismiss_key=ESC timeout_s=10');return false end end end
        self:close();local root
        for _,w in ipairs(FindAllOf('WBP_TItle_C')or{})do if valid(w)and w:IsActivated()then root=w;break end end
        if not valid(root)or not valid(root.WBP_TitleMenu)then log('MC_H_TITLE_SKIP native_title_unavailable');return end
        if valid(root.CurrentWidget)and not force then local ok,active=pcall(function()return root.CurrentWidget:IsActivated()end);if ok and active then log('MC_H_TITLE_SKIP native_submenu_active');return end end
        local controller=root:GetOwningPlayer();if not valid(controller)then log('MC_H_TITLE_SKIP controller');return end
        local class=StaticFindObject('/Game/MinecraftBlocks/WBP_MCTitle.WBP_MCTitle_C')
        if not valid(class)then local lib=UE.GetKismetSystemLibrary();class=UE.Native109(lib,'LoadClassAsset_Blocking',lib:Conv_SoftClassPathToSoftClassRef(lib:MakeSoftClassPath('/Game/MinecraftBlocks/WBP_MCTitle.WBP_MCTitle_C')))end
        assert(valid(class),'Title overlay class unavailable')
        self.widget=UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(root,class,controller);assert(valid(self.widget))
        self.nodes=ctx.widgets(self.widget);if ctx.uiKit then self.uiFactor=ctx.uiKit:apply(self.widget,'WBP_MCTitle',{player=root,controller=controller})end;self.widget:AddToViewport(99)
        self.owner,self.panel,self.controller=root,root.WBP_TitleMenu,controller;self.buttons={};self.allowTitleDialog=force
        self.panel:GetClass():ForEachProperty(function(p)local key=p:GetFullName():match('([^:]+)$');if key:find('WBP_Title_MenuButton_',1,true)then local b=self.panel[key];if valid(b)then self.buttons[#self.buttons+1]={node=b,opacity=b:GetRenderOpacity()};b:SetRenderOpacity(0)end end end)
        local hidden=0;for key,b in pairs(ctx.widgets(self.panel))do if key=='logo'or key=='logo_1'or key=='logo_2'then self.buttons[#self.buttons+1]={node=b,opacity=b:GetRenderOpacity()};b:SetRenderOpacity(0);hidden=hidden+1 end end;log('MC_I_NATIVE_TITLE_LOGOS_HIDDEN count='..hidden)
        self.handle=Timers.loop(150,function()
            if not valid(self.owner)or not self.owner:IsActivated()then self:close(true);return true end
            if valid(self.owner.CurrentWidget)then local ok,active=pcall(function()return self.owner.CurrentWidget:IsActivated()end);if ok and active then local dialog=self.owner.CurrentWidget:GetClass():GetFullName():lower():find('dialog',1,true);if not(self.allowTitleDialog and dialog)then self:close(true);return true end end end
            if ctx.uiKit then local x,y=self:mouse();ctx.uiKit:hoverButtons(self.nodes,'WBP_MCTitle',x,y);if valid(self.nodes.GuiHint)then local t=UE.Object('/Script/Engine.Default__GameplayStatics'):GetRealTimeSeconds(self.owner);local p=1+.025*(1+math.sin(t*3));self.nodes.GuiHint:SetRenderScale({X=p,Y=p})end end;return false
        end);log('MC_H_TITLE_OPEN native_background=true')
    end
    function T:schedule()
        if self.pending then Timers.cancel(self.pending)end
        self.pending=Timers.after(15000,function()
            self.pending=nil
            local attempts=0;local wait
            wait=Timers.loop(500,function()attempts=attempts+1;local force=attempts>=21;if force then log('MC24_TITLE_DIALOG_TIMEOUT show_anyway=true')end;local ok,result=pcall(self.show,self,force)
                if not ok then self:close();log('MC_H_TITLE_SKIP '..tostring(result));return true end
                if result~=false then return true end;return false
            end)
        end)
    end
    function T:mouse()
        local lib=UE.Object('/Script/UMG.Default__WidgetLayoutLibrary');local p=lib:GetMousePositionOnViewport(self.owner);local size=lib:GetViewportSize(self.owner);local scale=lib:GetViewportScale(self.owner)
        local x,y=p.X-size.X/(2*scale),p.Y-size.Y/(2*scale);return x/(self.uiFactor or 1),y/(self.uiFactor or 1)
    end
    function T:click()
        if not valid(self.widget)or not valid(self.owner)then return false end
        local x,y=self:mouse()
        if x<-300 or x>300 then return true end
        local chosen;for i=1,4 do local a=-95+(i-1)*76;if y>=a and y<a+58 then chosen=i;break end end
        if not chosen then return true end
        local root,panel=self.owner,self.panel;local field=({'WBP_Title_MenuButton_StartLocalGame','WBP_Title_MenuButton_StartMultiGame_JoinServer','WBP_Title_MenuButton_Option','WBP_Title_MenuButton_ExitGame'})[chosen]
        local button=panel[field];assert(valid(button),'Native title route unavailable');self:close();root:OnClickedMenu_Internal(button);log('MC_H_TITLE_NATIVE_ROUTE index='..chosen)
    end
    function T:install()
        local fn='/Game/Pal/Blueprint/UI/Title/WBP_TItle.WBP_TItle_C:OnSetup'
        Timers.after(14000,function()
            if valid(StaticFindObject(fn))then self.hook=Timers.hook(fn,function()

                self:schedule()
            end)end
        end)
        self:schedule()
    end
    Timers.onEpoch('title-overlay',function()
        if T.handle then Timers.cancel(T.handle)end
        T.handle=nil;T.widget,T.owner,T.panel,T.controller,T.nodes,T.buttons=nil,nil,nil,nil,nil,nil
    end)
    return T
end
