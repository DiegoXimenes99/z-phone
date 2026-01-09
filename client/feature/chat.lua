RegisterNUICallback('new-or-continue-chat', function(body, cb)
    lib.callback('z-phone:server:StartOrContinueChatting', false, function(chatting)
        cb(chatting)
    end, body)
end)

RegisterNUICallback('get-chats', function(_, cb)
    lib.callback('z-phone:server:GetChats', false, function(chats)
        cb(chats)
    end)
end)

RegisterNUICallback('get-chatting', function(body, cb)
    print('[Z-PHONE CLIENT] Getting chatting for conversation: ' .. tostring(body.conversationid))
    lib.callback('z-phone:server:GetChatting', false, function(chatting)
        print('[Z-PHONE CLIENT] Received chatting result: ' .. tostring(chatting and #chatting or 'nil'))
        if chatting then
            for i, msg in ipairs(chatting) do
                print('[Z-PHONE CLIENT] Message ' .. i .. ': ' .. tostring(msg.message))
            end
        end
        cb(chatting)
    end, body)
end)

RegisterNUICallback('send-chatting', function(body, cb)
    if not IsAllowToSendOrCall() then
        TriggerEvent("z-phone:client:sendNotifInternal", {
            type = "Notification",
            from = Config.App.InetMax.Name,
            message = Config.MsgSignalZone
        })
        cb(false)
        return
    end
    
    if not IsProfileLoaded() then
        TriggerEvent("z-phone:client:sendNotifInternal", {
            type = "Notification",
            from = "Phone",
            message = "Profile not loaded, try again"
        })
        cb(false)
        return
    end
    
    if Profile.inetmax_balance < Config.App.InetMax.InetMaxUsage.MessageSend then
        TriggerEvent("z-phone:client:sendNotifInternal", {
            type = "Notification",
            from = Config.App.InetMax.Name,
            message = Config.MsgNotEnoughInternetData
        })
        cb(false)
        return
    end

    lib.callback('z-phone:server:SendChatting', false, function(isOk)
        TriggerServerEvent("z-phone:server:usage-internet-data", Config.App.Message.Name, Config.App.InetMax.InetMaxUsage.MessageSend)
        cb(isOk)
    end, body)
end)

RegisterNUICallback('send-audio-message', function(body, cb)
    if not IsAllowToSendOrCall() then
        TriggerEvent("z-phone:client:sendNotifInternal", {
            type = "Notification",
            from = Config.App.InetMax.Name,
            message = Config.MsgSignalZone
        })
        cb(false)
        return
    end
    
    if not IsProfileLoaded() then
        TriggerEvent("z-phone:client:sendNotifInternal", {
            type = "Notification",
            from = "Phone",
            message = "Profile not loaded, try again"
        })
        cb(false)
        return
    end
    
    if Profile.inetmax_balance < Config.App.InetMax.InetMaxUsage.MessageSend then
        TriggerEvent("z-phone:client:sendNotifInternal", {
            type = "Notification",
            from = Config.App.InetMax.Name,
            message = Config.MsgNotEnoughInternetData
        })
        cb(false)
        return
    end

    lib.callback('z-phone:server:SendAudioMessage', false, function(result)
        if result then
            TriggerServerEvent("z-phone:server:usage-internet-data", Config.App.Message.Name, Config.App.InetMax.InetMaxUsage.MessageSend)
        end
        cb(result)
    end, body)
end)

RegisterNUICallback('delete-message', function(body, cb)
    lib.callback('z-phone:server:DeleteMessage', false, function(isOk)
        cb(isOk)
    end, body)
end)

RegisterNUICallback('create-group', function(body, cb)
    lib.callback('z-phone:server:CreateGroup', false, function(isOk)
        if (isOk) then
            TriggerEvent("z-phone:client:sendNotifInternal", {
                type = "Notification",
                from = "Message",
                message = "Group chat created!"
            })
        end
        cb(isOk)
    end, body)
end)