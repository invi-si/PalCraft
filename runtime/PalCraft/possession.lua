-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local P={}
function P.sameLevelDeath(old,current)
 return old~=nil and current~=nil and old.epoch==current.epoch
  and old.world==current.world and old.level~=nil and old.level==current.level
  and old.controller==current.controller
  and (old.deathSeen or not old.alive or current.status=='dead')
end
function P.sameRide(old,current)
 return old~=nil and current~=nil and old.alive and current.alive and old.epoch==current.epoch
  and old.world==current.world and old.controller==current.controller and old.player==current.player
  and (current.riding or old.riding or current.mountPossessed)
end
return P
