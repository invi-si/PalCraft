-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local G={}
function G.dx12(commandLine)
 local s=' '..tostring(commandLine or''):lower()..' '
 return s:match('%s%-dx12%s')~=nil or s:match('%s%-d3d12%s')~=nil
end
function G.entry(ctx,env)
 if ctx.UE.dxGuard68Seen then return end;ctx.UE.dxGuard68Seen=true
 local line=ctx.UE.GetKismetSystemLibrary():GetCommandLine():ToString()
 if G.dx12(line)then ctx.uiKit:notify('Minecraft','Minecraft mod: please launch in DX11 (remove -dx12)');ctx.log('MC68_DX12_WARNING shown=true')
 else ctx.log('MC68_DX12_WARNING shown=false')end
end
return G
