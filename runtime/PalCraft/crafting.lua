-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(recipes)
    local function accepts(options,id)
        if not options then return id==nil end
        for _,candidate in ipairs(options)do if candidate==id then return true end end
        return false
    end
    local function shaped(recipe,grid,size)
        if recipe.width>size or recipe.height>size then return end
        for mirrored=0,1 do for y=0,size-recipe.height do for x=0,size-recipe.width do
            local used,good={},true
            for gy=0,size-1 do for gx=0,size-1 do
                local rx,ry=gx-x,gy-y;local required=false
                if rx>=0 and rx<recipe.width and ry>=0 and ry<recipe.height then
                    if mirrored==1 then rx=recipe.width-1-rx end
                    required=recipe.cells[ry*recipe.width+rx+1]
                end
                local index=gy*size+gx+1;local entry=grid[index]
                if not accepts(required,entry and entry.id)then good=false end
                if required then used[#used+1]=index end
            end end
            if good then return used end
        end end end
    end
    local function shapeless(recipe,grid,size)
        local present={}
        for i=1,size*size do if grid[i] and grid[i].id then present[#present+1]=i end end
        if #present~=#recipe.ingredients then return end
        local used={}
        local function assign(i)
            if i>#recipe.ingredients then return true end
            for _,index in ipairs(present)do
                if not used[index] and accepts(recipe.ingredients[i],grid[index].id)then
                    used[index]=true;if assign(i+1)then return true end;used[index]=nil
                end
            end
            return false
        end
        if assign(1)then return present end
    end
    return function(grid,size,preferred)
        local ordered=recipes
        if preferred then ordered={preferred};for _,r in ipairs(recipes)do if r~=preferred then ordered[#ordered+1]=r end end end
        for _,recipe in ipairs(ordered)do
            if type(recipe.result)=='string'and recipe.result:sub(1,3)=='MC_'then
            local used=recipe.kind=='crafting_shaped' and shaped(recipe,grid,size)or(recipe.kind=='crafting_shapeless' and shapeless(recipe,grid,size))
            if used then
                local maximum=math.huge
                for _,index in ipairs(used)do maximum=math.min(maximum,grid[index].count)end
                return recipe,used,maximum
            end
            end
        end
    end
end
