-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local S={mode='silent',played=0,skipped=0}
 function S:available()return false end
 function S:preload()return nil end
 function S:play(event)
  self.skipped=self.skipped+1
  if not self.reported then
   self.reported=true
   ctx.log('PALCRAFT_AUDIO_UNAVAILABLE mode=silent reason=no_reflected_runtime_OGG_importer native_audio_unchanged=true')
  end
  return false
 end
 function S:status()return{mode=self.mode,played=self.played,skipped=self.skipped,reason='no_reflected_runtime_OGG_importer'}end
 return S
end
