print("^3[Z-PHONE] === CARREGANDO PROFILE.LUA ===")

-- Registra callback imediatamente para teste
lib.callback.register('z-phone:server:GetProfile', function(source)
    print("^3[Z-PHONE] Callback GetProfile chamado para source: " .. tostring(source))
    
    if not xCore then
        print("^1[Z-PHONE] xCore não inicializado!")
        return nil
    end
    
    local Player = xCore.GetPlayerBySource(source)
    if Player == nil then 
        print("^1[Z-PHONE] Player não encontrado para source: " .. tostring(source))
        return nil 
    end

    local citizenid = Player.citizenid
    if not citizenid then
        print("^1[Z-PHONE] CitizenID não encontrado para source: " .. tostring(source))
        return nil
    end

    print("^3[Z-PHONE] Carregando profile para citizenid: " .. citizenid)
    
    local query = [[
        select 
            zpu.name,
            zpu.citizenid,
            zpu.phone_number,
            zpu.created_at,
            zpu.last_seen,
            zpu.avatar,
            zpu.unread_message_service,
            zpu.unread_message,
            zpu.wallpaper,
            zpu.is_anonim,
            zpu.is_donot_disturb,
            zpu.frame,
            zpu.iban,
            zpu.active_loops_userid,
            zpu.inetmax_balance,
            zpu.phone_height
        from zp_users zpu WHERE zpu.citizenid = ? LIMIT 1
    ]]

    local result = MySQL.single.await(query, {
        citizenid
    })

    if not result then
        print("^3[Z-PHONE] Profile não encontrado, criando novo para citizenid: " .. citizenid)
        local phone_number = math.random(81, 89)..math.random(100000, 999999)
        local iban = math.random(7, 9)..math.random(1000000000, 9999999999)
        local queryNew = "INSERT INTO zp_users (citizenid, name, phone_number, iban, inetmax_balance) VALUES (?, ?, ?, ?, ?)"

        local success, id = pcall(MySQL.insert.await, queryNew, {
            citizenid,
            Player.name,
            phone_number,
            iban,
            5000000
        })

        if not success then
            print("^1[Z-PHONE] Erro ao criar profile: " .. tostring(id))
            return nil
        end

        print("^2[Z-PHONE] Profile criado com sucesso, ID: " .. tostring(id))

        -- Busca o profile recém-criado
        result = MySQL.single.await(query, {
            citizenid
        })
        
        if not result then
            print("^1[Z-PHONE] Erro ao buscar profile recém-criado")
            return nil
        end
    end

    -- Atualiza informações do jogador
    result.name = Player.name
    result.job = {}
    result.job.name = Player.job.name
    result.job.label = Player.job.label
    result.signal = Config.Signal.Zones[Config.Signal.DefaultSignalZones].ChanceSignal
    
    print("^2[Z-PHONE] Profile carregado com sucesso para: " .. result.name)
    return result
end)

lib.callback.register('z-phone:server:UpdateProfile', function(source, body)
    print("^3[Z-PHONE] Callback UpdateProfile chamado")
    
    if not xCore then
        print("^1[Z-PHONE] xCore não inicializado para UpdateProfile!")
        return false
    end
    
    local affectedRows = nil
    local Player = xCore.GetPlayerBySource(source)
    if Player ~= nil then
        local citizenid = Player.citizenid
        if body.type == 'avatar' then
            affectedRows = MySQL.update.await('UPDATE zp_users SET avatar = ? WHERE citizenid = ?', {
                body.value, citizenid
            })
        elseif body.type == 'wallpaper' then
            affectedRows = MySQL.update.await('UPDATE zp_users SET wallpaper = ? WHERE citizenid = ?', {
                body.value, citizenid
            })
        elseif body.type == 'is_anonim' then
            affectedRows = MySQL.update.await('UPDATE zp_users SET is_anonim = ? WHERE citizenid = ?', {
                body.value, citizenid
            })
        elseif body.type == 'is_donot_disturb' then
            affectedRows = MySQL.update.await('UPDATE zp_users SET is_donot_disturb = ? WHERE citizenid = ?', {
                body.value, citizenid
            })
        elseif body.type == 'frame' then
            affectedRows = MySQL.update.await('UPDATE zp_users SET frame = ? WHERE citizenid = ?', {
                body.value, citizenid
            })
        elseif body.type == 'phone_height' then
            affectedRows = MySQL.update.await('UPDATE zp_users SET phone_height = ? WHERE citizenid = ?', {
                body.value, 
                citizenid
            })
        else
            print("^1[Z-PHONE] Tipo de update inválido: " .. tostring(body.type))
        end

        if affectedRows then
            TriggerClientEvent("z-phone:client:sendNotifInternal", source, {
                type = "Notification",
                from = "Setting",
                message = "Success updated!"
            })
            return true
        else
            return false
        end
    end

    return false
end)

print("^2[Z-PHONE] ✅ Callbacks do profile registrados!")

-- Aguarda o xCore ser inicializado para verificação
CreateThread(function()
    while not xCore do
        print("^3[Z-PHONE] Aguardando xCore ser inicializado (profile.lua)...")
        Wait(1000)
    end
    print("^2[Z-PHONE] ✅ xCore disponível para profile callbacks")
end)

-- Comando para admin recarregar profile de um jogador
RegisterCommand('reloadplayerprofile', function(source, args)
    if source == 0 then -- Console
        if args[1] then
            local targetSource = tonumber(args[1])
            if targetSource then
                TriggerClientEvent('z-phone:client:reloadProfile', targetSource)
                print("^2[Z-PHONE] Profile reload enviado para jogador: " .. targetSource)
            end
        end
    else
        -- Verifica se o jogador tem permissão (adapte conforme seu sistema de permissões)
        if xCore then
            local Player = xCore.GetPlayerBySource(source)
            if Player and Player.job.name == 'admin' then -- Adapte conforme necessário
                if args[1] then
                    local targetSource = tonumber(args[1])
                    if targetSource then
                        TriggerClientEvent('z-phone:client:reloadProfile', targetSource)
                        TriggerClientEvent('chat:addMessage', source, {
                            color = {0, 255, 0},
                            multiline = false,
                            args = {"ADMIN", "Profile reload enviado para jogador: " .. targetSource}
                        })
                    end
                end
            end
        end
    end
end, true)