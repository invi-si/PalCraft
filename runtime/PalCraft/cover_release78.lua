-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local C={}
function C.ready(s)
 if not s.alive or not s.controlled or not s.hudReady then return false end
 if s.seconds>=15 then return true,'alive-hud-timeout15s' end
 if s.sceneReady and not s.held then return true,'scene-ready' end
 return false
end
return C
