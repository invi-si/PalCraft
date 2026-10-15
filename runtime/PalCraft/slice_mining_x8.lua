-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local M={}
local allowed={MC_WoodenPickaxe=true,MC_StonePickaxe=true,MC_IronPickaxe=true,MC_GoldenPickaxe=true,MC_DiamondPickaxe=true,MC_NetheritePickaxe=true}
function M.allowed(block,item)
 if not block.name:match('_ore$')then return true end
 return allowed[item]==true
end
return M
