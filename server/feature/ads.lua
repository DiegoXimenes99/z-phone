-- Aguarda o xCore ser inicializado
CreateThread(function()
    while not xCore do
        print("^3[Z-PHONE] Aguardando xCore ser inicializado (ads.lua)...")
        Wait(1000)
    end
    print("^2[Z-PHONE] Registrando callbacks de ads...")
    
    lib.callback.register('z-phone:server:GetAds', function(source)
        local Player = xCore.GetPlayerBySource(source)
        if Player == nil then return {} end

        local query = [[
            select 
                zpa.content,
                zpa.media,
                zpa.citizenid,
                DATE_FORMAT(zpa.created_at, '%d/%m/%Y %H:%i') as time,
                zpu.avatar,
                zpu.phone_number,
                zpu.name as name
            from zp_ads zpa
            JOIN zp_users zpu ON zpu.citizenid = zpa.citizenid
            ORDER BY zpa.id DESC
            LIMIT 100
        ]]

        local result = MySQL.query.await(query)
        if not result then
            return {}
        end
        
        return result
    end)

    lib.callback.register('z-phone:server:SendAds', function(source, body)
        local Player = xCore.GetPlayerBySource(source)
        if Player == nil then return false end
        
        local citizenid = Player.citizenid
        local query = "INSERT INTO zp_ads (citizenid, media, content) VALUES (?, ?, ?)"

        local id = MySQL.insert.await(query, {
            citizenid,
            body.media,
            body.content,
        })

        if not id then
            return false
        end
         
        TriggerClientEvent("z-phone:client:sendNotifInternal", -1, {
            type = "Notification",
            from = "Ads",
            message = "New ads posted!"
        })
        return true
    end)
    
    print("^2[Z-PHONE] Callbacks de ads registrados com sucesso!")
end)