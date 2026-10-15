-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,C)
    local V={};local dirs={{0,-1},{1,0},{0,1},{-1,0}};local faces={'north','east','south','west'}
    local function state(c)return ctx.registry[c.type].states[(c.variant or 0)+1]end
    local function key(c,z)return ctx.key(c.x,c.y,z or c.z)end
    local function variant(d,wanted)
        for i,s in ipairs(d.states)do local ok=true;for k,v in pairs(wanted)do if s[k]~=v then ok=false;break end end;if ok then return i-1 end end
        error('Minecraft state absent '..d.name)
    end
    local function cube(c)
        if not c then return false end;local d=ctx.registry[c.type]
        return not d.kind or d.kind=='cube'or(d.kind=='slab'and c.variant==2)
    end
    function V:connect(k)
        local c=ctx.cells()[k];if not c then return end;local d=ctx.registry[c.type]
        if not d.connectGroup then return end;local mask=0
        for i,o in ipairs(dirs)do local n=ctx.cells()[ctx.key(c.x+o[1],c.y+o[2],c.z)]
            if n then local nd=ctx.registry[n.type];if cube(n)or nd.connectGroup==d.connectGroup then mask=mask+2^(i-1)end end end
        if c.variant~=mask then ctx.setVariant(k,mask);ctx.log('MC_E_CONNECT type='..d.name..' mask='..mask)end
    end
    function V:neighbors(c)
        self:connect(key(c));for _,o in ipairs(dirs)do self:connect(ctx.key(c.x+o[1],c.y+o[2],c.z))end
    end
    function V:placement(env,hit,c)
        local d=ctx.registry[c.type];if not d.states then return c end
        local facing=faces[(math.floor((env.controller.PlayerCameraManager:GetCameraRotation().Yaw+45)/90)+1)%4+1]
        c.open=false
        if d.kind=='fence'or d.kind=='wall'or d.kind=='pane'then c.variant=0
        elseif d.kind=='gate'then c.variant=variant(d,{facing=facing,open='false'})
        elseif d.kind=='door'then
            local p=hit.ImpactPoint;local lateral=facing=='north'or facing=='south';local half=(lateral and p.X or p.Y)/100%1
            c.variant=variant(d,{facing=facing,hinge=half>.5 and'right'or'left',half='lower',open='false'})
        elseif d.kind=='trapdoor'then c.variant=variant(d,{facing=facing,half=(hit.ImpactNormal.Z<-.5 or(math.abs(hit.ImpactNormal.Z)<.5 and hit.ImpactPoint.Z/100%1>.5))and'top'or'bottom',open='false'})
        elseif d.kind=='ladder'then
            if math.abs(hit.ImpactNormal.Z)>.5 then return nil end
            local n=hit.ImpactNormal;facing=math.abs(n.X)>math.abs(n.Y)and(n.X>0 and'east'or'west')or(n.Y>0 and'south'or'north')
            c.variant=variant(d,{facing=facing});local ch=ctx.hitChunk and ctx.hitChunk(hit);c.support=ch and ch.keys[hit.Item]
        end;return c
    end
    function V:canPlace(c,env)
        local d=ctx.registry[c.type];if d.kind~='door'or state(c).half~='lower'then return true end
        local upper={x=c.x,y=c.y,z=c.z+1,type=c.type};if ctx.cells()[key(upper)]or ctx.intersectsPlayer(upper,env)then ctx.log('MC_E_DOOR_PLACE_REJECT upper_occupied_or_player');return false end
        return true
    end
    function V:changed(c,env)
        if ctx.cells()[key(c)]and ctx.registry[c.type].kind=='door'and state(c).half=='lower'then
            local k=key(c,c.z+1);if not ctx.cells()[k]then local s=state(c);local upper={x=c.x,y=c.y,z=c.z+1,type=c.type,debug=c.debug,open=c.open,support=key(c),variant=variant(ctx.registry[c.type],{facing=s.facing,hinge=s.hinge,half='upper',open=s.open})}
                ctx.addVisual(upper,env);ctx.cells()[k]=upper;ctx.log('MC_E_DOOR_PAIR placed_one_item_two_cells=true')end
        end
        self:neighbors(c)
    end
    function V:beforeBreak(k,env)
        if self.removing then return true end;local c=ctx.cells()[k];if not c or ctx.registry[c.type].kind~='door'then return true end
        local z=c.z+(state(c).half=='lower'and 1 or-1);local other=key(c,z);local pair=ctx.cells()[other]
        if pair and pair.type==c.type then self.removing=true;ctx.remove(other);self.removing=false;ctx.log('MC_E_DOOR_PAIR removed_two_cells_one_refund=true')end;return true
    end
    function V:interact(env,k)
        if not ctx.gameplayInput(env)then return false end;local c=ctx.cells()[k];if not c then return false end;local d=ctx.registry[c.type]
        if d.kind~='door'and d.kind~='gate'and d.kind~='trapdoor'then return false end
        if d.name=='iron_door'then ctx.log('MC_E_IRON_DOOR_LOCKED no_redstone');return true end
        local s=state(c);local wanted={facing=s.facing,open=s.open=='true'and'false'or'true',half=s.half,hinge=s.hinge};local opened=wanted.open=='true'
        ctx.setVariant(k,variant(d,wanted),opened)
        if d.kind=='door'then local other=key(c,c.z+(s.half=='lower'and 1 or-1));local pair=ctx.cells()[other]
            if pair and pair.type==c.type then wanted.half=s.half=='lower'and'upper'or'lower';ctx.setVariant(other,variant(d,wanted),opened)end end
        ctx.save();local sound=d.kind=='gate'and'fence_gate'or d.kind=='trapdoor'and(d.name=='iron_trapdoor'and'iron_trapdoor'or'wooden_trapdoor')or'wooden_door'
        C:play('block.'..sound..(opened and'.open'or'.close'),{X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+50},.6)
        ctx.log('MC_E_TOGGLE type='..d.name..' open='..tostring(opened)..' collision='..(opened and'visibility_only'or'BlockAll'));return true
    end
    V.state=state;V.variant=variant;return V
end
