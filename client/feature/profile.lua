RegisterNUICallback('get-profile', function(_, cb)
    if not IsProfileLoaded() then
        -- Tenta carregar o profile se não estiver carregado
        lib.callback('z-phone:server:GetProfile', false, function(profile)
            if profile and next(profile) ~= nil then
                Profile = profile
                cb(profile)
            else
                print("^1[Z-PHONE] Falha ao carregar profile via NUI callback")
                cb(nil)
            end
        end)
    else
        cb(Profile)
    end
end)

RegisterNUICallback('update-profile', function(body, cb)
    lib.callback('z-phone:server:UpdateProfile', false, function(isOk)
        if isOk then
            lib.callback('z-phone:server:GetProfile', false, function(profile)
                Profile = profile
                cb(profile)
            end)
        end
    end, body)
end)