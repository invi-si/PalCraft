-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
-- PalCraft local-data adapter; original jar-derived table excluded.
local base=debug.getinfo(1,'S').source:sub(2):match('^(.*)[/\\]')
return dofile(base..'/local_data.lua').load(base,'strings70')
