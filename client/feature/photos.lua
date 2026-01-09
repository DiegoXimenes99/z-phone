local function GetStreetName()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local streetName = GetStreetNameFromHashKey(GetStreetNameAtCoord(playerCoords.x, playerCoords.y, playerCoords.z))
    return streetName or "Unknown Location"
end

RegisterNUICallback('get-photos', function(_, cb)
    lib.callback('z-phone:server:GetPhotos', false, function(photos)
        cb(photos)
    end)
end)

RegisterNUICallback('save-photos', function(body, cb)
    print('[Z-PHONE] Saving photo to gallery: ' .. tostring(body.url))
    body.location = GetStreetName()
    lib.callback('z-phone:server:SavePhotos', false, function(isOk)
        print('[Z-PHONE] Photo save result: ' .. tostring(isOk))
        if isOk then
            xCore.Notify("Successful save to gallery!", 'success')
        else
            xCore.Notify("Failed to save photo!", 'error')
        end
        cb(isOk)
    end, body)
end)

RegisterNUICallback('delete-photos', function(body, cb)
    lib.callback('z-phone:server:DeletePhotos', false, function(isOk)
        if isOk then
            xCore.Notify("Successful delete from gallery!", 'success')
        end

        lib.callback('z-phone:server:GetPhotos', false, function(photos)
            cb(photos)
        end)
    end, body)
end)