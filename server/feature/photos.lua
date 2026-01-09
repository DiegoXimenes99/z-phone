lib.callback.register('z-phone:server:GetPhotos', function(source)
    local Player = xCore.GetPlayerBySource(source)
    if Player ~= nil then
        local citizenid = Player.citizenid
        local query = [[
            select 
                zpp.id,
                zpp.media as photo,
                DATE_FORMAT(zpp.created_at, '%d/%m/%Y %H:%i') as created_at
            from zp_photos zpp
            WHERE zpp.citizenid = ? ORDER BY zpp.id DESC
        ]]

        local result = MySQL.query.await(query, {
            citizenid
        })

        if result then
            return result
        else
            return {}
        end
    end
    return {}
end)

lib.callback.register('z-phone:server:SavePhotos', function(source, body)
    local Player = xCore.GetPlayerBySource(source)
    if Player ~= nil then
        local citizenid = Player.citizenid
        print('[Z-PHONE] Saving photo for citizen: ' .. citizenid .. ' URL: ' .. tostring(body.url))
        
        local query = "INSERT INTO zp_photos (citizenid, media, location) VALUES (?, ?, ?)"

        local id = MySQL.insert.await(query, {
            citizenid,
            body.url,
            body.location,
        })

        if id then
            print('[Z-PHONE] Photo saved successfully with ID: ' .. id)
            return true
        else
            print('[Z-PHONE] Failed to save photo to database')
            return false
        end
    end
    print('[Z-PHONE] Player not found for source: ' .. source)
    return false
end)

lib.callback.register('z-phone:server:DeletePhotos', function(source, body)
    local Player = xCore.GetPlayerBySource(source)
    if Player ~= nil then
        local citizenid = Player.citizenid
        local query = "DELETE from zp_photos WHERE id = ? AND citizenid = ?"

        MySQL.query.await(query, {
            body.id,
            citizenid,
        })

        return true
    end
    return false
end)