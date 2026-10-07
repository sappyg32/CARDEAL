fx_version 'cerulean'

name 'KOJA_CARDEALER'
author 'Koja Store'
version '1.0.1'
description 'Cardealer V2 with admin menu, promotions and limited stock'

lua54 'yes'

games {
  'gta5'
}

ui_page 'web/build/index.html'

shared_scripts {
   'init.lua',
   'shared/config.lua',
   'shared/utils.lua',
   'shared/s_utils.lua',
}

client_scripts {
  'client/cam.lua',
  'client/main.lua',
  'client/admin.lua',
  'client/leasing.lua',
  'client/functions.lua',
  'client/events.lua',
  'shared/c_utils.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/settings.lua',
  'server/prestige.lua',
  'server/main.lua',
  'server/dealers.lua',
  'server/promotions.lua',
  'server/coupons.lua',
  'server/vip.lua',
  'server/leasing.lua',
  'shared/s_utils.lua',
}

files {
  'web/build/index.html',
  'web/build/**/*',
  'web/build/**/**/*',
  'web/images/*',
  'web/images/**/*',
  'data/dealers.json',
  'locales/**.json'
}

escrow_ignore {
  '*.lua',
  '*.sql',
  '*.md',
  'init.lua',
  'fxmanifest.lua',
  'database.sql',
  'client/**',
  'server/**',
  'shared/**',
  'locales/**',
  'web/**',
  '**/*',
}

dependency '/assetpacks'
