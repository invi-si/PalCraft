-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx,h)
    local A={segments={}};local UE,valid,log=ctx.UE,ctx.valid,ctx.log
    local meshes=dofile(ctx.base..'/armor_meshes.lua')
    local mathlib
    local function vec(x,y,z)return{X=x,Y=y,Z=z}end
    local function delta(a,b)return vec(b.X-a.X,b.Y-a.Y,b.Z-a.Z)end
    local function length(v)return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end
    local function point(mesh,b)return mesh:GetSocketLocation(UE.FindOrAddFName(b))end
    function A:fit(env,mesh,r)
        if not valid(mathlib)then mathlib=UE.Object('/Script/Engine.Default__KismetMathLibrary')end
        local a,b=point(mesh,r.bone),point(mesh,r['end']);if r.bone==r['end']then b=vec(a.X,a.Y,a.Z+16);a=vec(a.X,a.Y,a.Z-1);r.width_ratio=1.55 end;local axis=delta(a,b);local span=length(axis)
        if span<=1 then log('MC_J_ARMOR_SEGMENT_SKIPPED zero_span='..r.bone);return end
        local width=span*r.width_ratio;local height=span*(1+r.inflate);local facing=mesh:GetSocketRotation(UE.FindOrAddFName(r.bone));local reference=mathlib:GetForwardVector(facing)
        local dot=(reference.X*axis.X+reference.Y*axis.Y+reference.Z*axis.Z)/span
        if math.abs(dot)>.9 then reference=mathlib:GetRightVector(facing)end
        local rotation=mathlib:MakeRotFromZX(axis,reference);local origin=vec(a.X,a.Y,a.Z)
        if r.kind=='head'then
            width=span*(self.headFactor or r.width_ratio)*(1+r.inflate);height=width;origin=vec(b.X,b.Y,b.Z);rotation=env.player:K2_GetActorRotation()
            log(string.format('MC_I_HEAD_MEASURE head_neck_cm=%.2f factor=%.3f size_cm=%.2f',span,self.headFactor or r.width_ratio,width))
        elseif r.kind=='chest'then width=length(delta(point(mesh,'upperarm_l'),point(mesh,'upperarm_r')))*r.width_ratio*(1+r.inflate)
        elseif r.kind=='waist'then width=length(delta(point(mesh,'thigh_l'),point(mesh,'thigh_r')))*r.width_ratio*(1+r.inflate)
        else width=width*(1+r.inflate)end
        width=width*(self.widthFactor or 1);local depth=width*r.depth_ratio*(self.depthFactor or 1)
        log(string.format('MC_I_ARMOR_FIT bone=%s end=%s kind=%s length=%.2f width=%.2f depth=%.2f ratio=%.3f depthRatio=%.3f',r.bone,r['end'],r.kind,height,width,depth,r.width_ratio,r.depth_ratio))
        return origin,rotation,vec(depth/r.unit_cm,width/r.unit_cm,height/r.unit_cm)
    end
    local function destroy(v)if valid(v)then v:K2_DestroyComponent(v)end end
    function A:clear(touch)
        local n=0;for _,v in pairs(self.segments)do n=n+1;if touch then destroy(v.component)end end
        if touch and self.nativeHat and valid(self.nativeHat.node)then self.nativeHat.node:SetVisibility(self.nativeHat.visible,false)end
        self.segments={};self.nativeHat=nil;self.token=nil
        if n>0 then log('MC_H_ARMOR_CLEARED previous='..n..' remaining=0 touch='..tostring(touch))end
    end
    function A:tick(env)
        if env.player.CharacterParameterComponent:GetIndividualParameter():IsDead()then self:clear(true);return end
        local native=ctx.items.native;local c=native:container(env,4);local ids={}
        for i=0,c:Num()-1 do local id=native:id(c:Get(i));if meshes[id]then ids[#ids+1]=id end end
        table.sort(ids);local cosmetic=ctx.steve and ctx.steve.mesh
        local fp=ctx.steve and ctx.steve.firstPerson or false
        for _,v in pairs(self.segments)do if valid(v.component)then v.component:SetOwnerNoSee(fp and not(v.bone:find('arm')or v.bone:find('hand'))or false)end end
        local token=table.concat(ids,',')..'@'..(valid(cosmetic)and cosmetic:GetAddress()or 0);if token==self.token then return end
        self:clear(true);self.token=token;local mesh=valid(cosmetic)and cosmetic or env.player.Mesh
        local supported=true;for _,id in ipairs(ids)do if not(id:match('^MC_Iron')or id:match('^MC_Diamond')or id:match('^MC_Leather'))then supported=false end end
        if valid(cosmetic)and supported then
            assert(cosmetic:GetNumBones()==17,'Steve armor requires accepted17-bone rig')
            local n=0
            for _,id in ipairs(ids)do
                local tier,piece=id:match('^MC_(%a-)(Helmet)$');if not tier then tier,piece=id:match('^MC_(%a-)(Chestplate)$')end;if not tier then tier,piece=id:match('^MC_(%a-)(Leggings)$')end;if not tier then tier,piece=id:match('^MC_(%a-)(Boots)$')end
                assert(tier and piece,'Unsupported Steve armor '..id)
                local path='/Game/MinecraftSteve/Task36/SK_MC36'..piece
                local asset=h.asset(path..'.SK_MC36'..piece);assert(valid(asset)and not valid(asset.PhysicsAsset),'Steve armor physics forbidden')
                local identity={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
                local comp=env.player:AddComponentByClass(UE.Object('/Script/Engine.SkeletalMeshComponent'),true,identity,false);assert(valid(comp))
                comp:SetCollisionEnabled(0);assert(comp:K2_AttachToComponent(cosmetic,UE.FindOrAddFName('None'),2,2,2,false));comp:SetSkeletalMeshAsset(asset);comp:SetLeaderPoseComponent(cosmetic,true,false);comp:AddTickPrerequisiteComponent(cosmetic);comp:SetComponentTickEnabled(true)
                local layer=piece=='Leggings'and 2 or 1;local material='/Game/MinecraftSteve/Task36/M_MC36_'..tier:lower()..'_'..layer
                local mat=h.asset(material..'.M_MC36_'..tier:lower()..'_'..layer);assert(valid(mat),'Steve armor material unavailable')
                for i=0,comp:GetNumMaterials()-1 do comp:SetMaterial(i,mat)end
                comp:SetOwnerNoSee(fp);comp:SetOnlyOwnerSee(cosmetic.bOnlyOwnerSee);n=n+1;self.segments[n]={component=comp,item=id,bone='all',steve=true}
            end
            log('MC36_STEVE_ARMOR_READY pieces='..n..' native_ids='..token..' leader_pose=true defense_unchanged=true');return
        end
        if not self.bonesLogged then local names={};for i=0,mesh:GetNumBones()-1 do names[#names+1]=mesh:GetBoneName(i):ToString()end;log('MC_H_ARMOR_BONES '..table.concat(names,','));self.bonesLogged=true end
        local n=0
        for _,id in ipairs(ids)do for _,spec in ipairs(meshes[id])do
            local r={};for k,v in pairs(spec)do r[k]=v end
            if valid(cosmetic)then
                if r.bone=='Head'then r.bone='head';r.width_ratio=6
                elseif r.bone:find('upperarm')or r.bone:find('lowerarm')then r.width_ratio=1.05
                elseif r.bone:find('thigh')then r['end']=r.bone:gsub('thigh','foot');r.width_ratio=.34
                elseif r.bone:find('calf')then r.bone=r.bone:gsub('calf','foot');r['end']=r.bone
                elseif r.bone:find('foot')then r['end']=r.bone end
            end
            local bone=UE.FindOrAddFName(r.bone);assert(mesh:DoesSocketExist(bone),'Armor bone unavailable '..r.bone)
            local t={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
            local comp=env.player:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),true,t,false)
            assert(valid(comp));comp:SetMobility(2);comp:SetCollisionEnabled(0)
            assert(comp:SetStaticMesh(h.asset(r.mesh)))
            if r.unit_cm then local p,rotation,scale=self:fit(env,mesh,r);if p then _G.MC_OUT_K('K2_SetWorldLocation',comp,p,false,ignoredHitJ(),true);_G.MC_OUT_K('K2_SetWorldRotation',comp,rotation,false,ignoredHitJ(),true);comp:SetWorldScale3D(scale);assert(comp:K2_AttachToComponent(mesh,bone,1,1,1,false))else destroy(comp);comp=nil end
            else assert(comp:K2_AttachToComponent(mesh,bone,2,2,2,false));comp:SetRelativeScale3D({X=r.scale[1],Y=r.scale[2],Z=r.scale[3]});_G.MC_OUT_K('K2_SetRelativeLocation',comp,{X=r.offset[1],Y=r.offset[2],Z=r.offset[3]},false,ignoredHitJ(),true)end
            if valid(comp)then comp:SetOwnerNoSee(fp and not(r.bone:find('arm')or r.bone:find('hand'))or false);n=n+1;self.segments[n]={component=comp,item=id,bone=r.bone}end
        end end
        for _,id in ipairs(ids)do if id:find('Helmet$')then
            local hat=env.player.HairAttachAccessory
            if valid(hat)and valid(hat.SkeletalMesh)and hat.SkeletalMesh:GetFullName():find('/HeadEquip/',1,true)then self.nativeHat={node=hat,visible=hat.bVisible};hat:SetVisibility(false,false)end
        end end
        log('MC_H_ARMOR_READY native_ids='..token..' segments='..n..' cosmetic_steve='..tostring(valid(cosmetic))..' defense_unchanged=true')
    end
    function A:cancel(touch)self:clear(touch);self.bonesLogged=nil end
    dofile(ctx.base..'/timers.lua').onEpoch('armor-visuals',function()A:clear(false);A.bonesLogged=nil;mathlib=nil end)
    return A
end
