fx_version 'cerulean'
game 'gta5'
author 'Gemini'
description 'GTA World Style House Furniture System for QBCore'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- รองรับ oxmysql ในการเชื่อมฐานข้อมูล
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}