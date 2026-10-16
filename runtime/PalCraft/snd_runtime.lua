-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local S={mode='cooked_vorbis',lazy=false,played=0,skipped=0}
 function S:available()return true end
 function S:preload()return nil end
 function S:play(event)
  self.skipped=self.skipped+1
  if not self.reported then
   self.reported=true
   ctx.log('PALCRAFT_AUDIO_FALLBACK mode=cooked_vorbis')
  end
  return false
 end
 function S:status()return{mode=self.mode,played=self.played,skipped=self.skipped,source='installer_patched_soundwaves'}end
 return S
end
