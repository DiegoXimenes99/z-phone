local WebHook = 'https://discord.com/api/webhooks/1458658709726035999/yFkLuKj7GvzM72GyXNGA2G6a9ei9-Pmg4w_xVz-NtTuiBDCfnWlrThTEZlb6w0PvIMFJ'

print("^3[Z-PHONE] === CARREGANDO MAIN.LUA ===")

-- Registra callbacks imediatamente
lib.callback.register('z-phone:server:HasPhone', function(source)
    print("^3[Z-PHONE] Callback HasPhone chamado para source: " .. tostring(source))
    if not xCore then
        print("^1[Z-PHONE] xCore não disponível para HasPhone")
        return false
    end
    return xCore.HasItemByName(source, 'phone')
end)

lib.callback.register('z-phone:server:GetWebhook', function(_)
    print("^3[Z-PHONE] Callback GetWebhook chamado")
    if WebHook ~= '' then
        print('[Z-PHONE] Webhook available for real photo capture')
        return WebHook
    else
        print('[Z-PHONE] No webhook configured, will use local system')
        return nil
    end
end)

lib.callback.register('z-phone:server:TakePhotoLocal', function(source)
    print("^3[Z-PHONE] Callback TakePhotoLocal chamado para source: " .. tostring(source))
    -- Lista de URLs de imagens de teste
    local testImages = {
        'https://picsum.photos/400/600?random=1',
        'https://picsum.photos/400/600?random=2', 
        'https://picsum.photos/400/600?random=3',
        'https://picsum.photos/400/600?random=4',
        'https://picsum.photos/400/600?random=5'
    }
    
    -- Seleciona uma imagem aleatoria
    local randomIndex = math.random(1, #testImages)
    local photoUrl = testImages[randomIndex]
    
    print('[Z-PHONE] Photo taken by player ' .. source .. ': ' .. photoUrl)
    return photoUrl
end)

print("^2[Z-PHONE]  Callbacks principais registrados!")

-- Aguarda o xCore ser inicializado para verificação
CreateThread(function()
    while not xCore do
        print("^3[Z-PHONE] Aguardando xCore ser inicializado (main.lua)...")
        Wait(1000)
    end
    print("^2[Z-PHONE]  xCore disponível para callbacks principais")
end)

-- Comando de debug para verificar xCore
RegisterCommand('debugphone', function(source, args)
    if source == 0 then -- Console
        print("^3[Z-PHONE DEBUG]")
        print("Config.Core: " .. tostring(Config.Core))
        print("xCore exists: " .. tostring(xCore ~= nil))
        if xCore then
            print("xCore.GetPlayerBySource exists: " .. tostring(xCore.GetPlayerBySource ~= nil))
        end
        print("MySQL exists: " .. tostring(MySQL ~= nil))
        print("lib exists: " .. tostring(lib ~= nil))
    end
end, true)

-- Comando para testar callback do profile
RegisterCommand('testprofile', function(source, args)
    if source == 0 and args[1] then -- Console
        local targetSource = tonumber(args[1])
        if targetSource then
            print("^3[Z-PHONE] Testando callback do profile para source: " .. targetSource)
            lib.callback('z-phone:server:GetProfile', targetSource, function(profile)
                if profile then
                    print("^2[Z-PHONE] Profile obtido com sucesso: " .. profile.name)
                else
                    print("^1[Z-PHONE] Falha ao obter profile")
                end
            end)
        end
    end
end, true)

-- Comando para listar callbacks registrados
RegisterCommand('listcallbacks', function(source, args)
    if source == 0 then -- Console
        print("^3[Z-PHONE] === VERIFICANDO CALLBACKS ===")
        
        -- Testa se os callbacks existem
        local callbacks = {
            'z-phone:server:GetProfile',
            'z-phone:server:UpdateProfile', 
            'z-phone:server:HasPhone',
            'z-phone:server:GetWebhook',
            'z-phone:server:TakePhotoLocal'
        }
        
        for _, callbackName in ipairs(callbacks) do
            -- Tenta chamar o callback para ver se existe
            local success = pcall(function()
                lib.callback(callbackName, -1, function() end)
            end)
            
            if success then
                print("^2[Z-PHONE]  " .. callbackName .. " - REGISTRADO")
            else
                print("^1[Z-PHONE]  " .. callbackName .. " - NÃO ENCONTRADO")
            end
        end
        
        print("^3[Z-PHONE] === FIM DA VERIFICAÇÃO ===")
    end
end, true)