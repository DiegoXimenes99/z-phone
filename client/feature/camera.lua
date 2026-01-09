local frontCam = false

local function CellFrontCamActivate(activate)
    return Citizen.InvokeNative(0x2491A93618B7D838, activate)
end

RegisterNUICallback('TakePhoto', function(_, cb)
    SetNuiFocus(false, false)
    CreateMobilePhone(1)
    CellCamActivate(true, true)
    local takePhoto = true
    while takePhoto do
        if IsControlJustPressed(1, 27) then -- Toogle Mode
            frontCam = not frontCam
            CellFrontCamActivate(frontCam)
        elseif IsControlJustPressed(1, 177) then -- CANCEL
            DestroyMobilePhone()
            CellCamActivate(false, false)
            cb(nil)
            break
        elseif IsControlJustPressed(1, 176) then -- TAKE.. PIC
            print('[Z-PHONE] Taking photo...')
            
            -- Primeiro tenta usar o webhook se estiver configurado
            lib.callback('z-phone:server:GetWebhook', false, function(hook)
                if hook and hook ~= '' then
                    print('[Z-PHONE] Using webhook for real photo capture')
                    exports['screenshot-basic']:requestScreenshotUpload(tostring(hook), 'files[]', function(data)
                        local success, result = pcall(json.decode, data)
                        if success and result and result.attachments and result.attachments[1] then
                            local photoUrl = result.attachments[1].proxy_url
                            print('[Z-PHONE] Real photo captured via Discord: ' .. photoUrl)
                            DestroyMobilePhone()
                            CellCamActivate(false, false)
                            cb(photoUrl)
                            takePhoto = false
                        else
                            print('[Z-PHONE] Discord upload failed, using fallback')
                            -- Fallback para sistema local
                            lib.callback('z-phone:server:TakePhotoLocal', false, function(fallbackUrl)
                                DestroyMobilePhone()
                                CellCamActivate(false, false)
                                cb(fallbackUrl)
                                takePhoto = false
                            end)
                        end
                    end)
                else
                    print('[Z-PHONE] No webhook configured, using local system')
                    -- Usa sistema local se não houver webhook
                    lib.callback('z-phone:server:TakePhotoLocal', false, function(photoUrl)
                        print('[Z-PHONE] Local photo URL: ' .. tostring(photoUrl))
                        DestroyMobilePhone()
                        CellCamActivate(false, false)
                        cb(photoUrl)
                        takePhoto = false
                    end)
                end
            end)
        end
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(8)
        HideHudComponentThisFrame(9)
        HideHudComponentThisFrame(6)
        HideHudComponentThisFrame(19)
        HideHudAndRadarThisFrame()
        EnableAllControlActions(0)
        Wait(0)
    end
    Wait(1000)
    SetNuiFocus(true, true)
    if not PhoneData.CallData.InCall then
        DoPhoneAnimation('cellphone_text_in')
    else
        DoPhoneAnimation('cellphone_call_to_text')
    end
end)