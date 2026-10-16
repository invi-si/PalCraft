-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local M={}
function M.read(doc)return type(doc)=='table'and doc.game_mode=='creative'and'creative'or'survival'end
function M.valid(mode)return mode=='survival'or mode=='creative'end
function M.placementDelta(mode)return mode=='creative'and 0 or-1 end
return M
