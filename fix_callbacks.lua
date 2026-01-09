-- Script temporário para corrigir callbacks
-- Este arquivo será usado para aplicar correções em massa

local files_to_fix = {
    "server/feature/ads.lua",
    "server/feature/bank.lua", 
    "server/feature/calls.lua",
    "server/feature/chat.lua",
    "server/feature/contact.lua",
    "server/feature/emails.lua",
    "server/feature/garages.lua",
    "server/feature/houses.lua",
    "server/feature/inetmax.lua",
    "server/feature/loops.lua",
    "server/feature/news.lua",
    "server/feature/photos.lua",
    "server/feature/services.lua"
}

-- Template para envolver callbacks
local wrapper_start = [[
-- Aguarda o xCore ser inicializado
CreateThread(function()
    while not xCore do
        print("^3[Z-PHONE] Aguardando xCore ser inicializado (%s)...")
        Wait(1000)
    end
    print("^2[Z-PHONE] Registrando callbacks de %s...")
    
]]

local wrapper_end = [[
    
  print("^2[Z-PHONE] Callbacks de %s registrados com sucesso!")
end)
]]