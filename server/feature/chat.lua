lib.callback.register('z-phone:server:StartOrContinueChatting', function(source, body)
    local Player = xCore.GetPlayerBySource(source)
    if Player == nil then 
        print('[Z-PHONE] Player not found for StartOrContinueChatting')
        return nil 
    end

    local citizenid = Player.citizenid
    print('[Z-PHONE] StartOrContinueChatting - CitizenID: ' .. citizenid)

    if body.to_citizenid == citizenid then 
        TriggerClientEvent("z-phone:client:sendNotifInternal", source, {
            type = "Notification",
            from = "Message",
            message = "Cannot chat to your self!"
        })
        return nil 
    end

    if body.phone_number then
        print('[Z-PHONE] Looking for phone number: ' .. body.phone_number)
        local queryCheckUserTarget = [[
            select zpu.* from zp_users zpu WHERE zpu.phone_number = ? LIMIT 1
        ]]
        local userTarget = MySQL.single.await(queryCheckUserTarget, {
            body.phone_number,
        })

        if not userTarget then
            print('[Z-PHONE] Phone number not found: ' .. body.phone_number)
            TriggerClientEvent("z-phone:client:sendNotifInternal", source, {
                type = "Notification",
                from = "Message",
                message = "Invalid phone number!"
            })
            return nil 
        end

        body.to_citizenid = userTarget.citizenid
        print('[Z-PHONE] Found target citizenid: ' .. body.to_citizenid)
    end

    if body.to_citizenid == citizenid then 
        TriggerClientEvent("z-phone:client:sendNotifInternal", source, {
            type = "Notification",
            from = "Message",
            message = "Cannot chat to your self!"
        })
        return nil 
    end
    
    local queryGetConversationID = [[
        WITH ConversationParticipants AS (
            SELECT conversationid
            FROM zp_conversation_participants
            WHERE citizenid IN (?, ?)
            GROUP BY conversationid
            HAVING COUNT(DISTINCT citizenid) = 2
        ),
        InvalidConversations AS (
            SELECT conversationid
            FROM zp_conversation_participants
            GROUP BY conversationid
            HAVING COUNT(DISTINCT citizenid) > 2
        )
        SELECT 
            CASE 
                WHEN EXISTS (SELECT 1 FROM InvalidConversations) THEN NULL
                ELSE (SELECT conversationid FROM ConversationParticipants)
            END AS conversationid
    ]]

    local conversationid = MySQL.scalar.await(queryGetConversationID, {
        citizenid,
        body.to_citizenid
    })
    
    print('[Z-PHONE] Existing conversation ID: ' .. tostring(conversationid))
     
    if conversationid == nil then
        print('[Z-PHONE] Creating new conversation')
        local queryNewConv = "INSERT INTO zp_conversations (is_group) VALUES (?)"
        conversationid = MySQL.insert.await(queryNewConv, {
            false,
        })

        local queryParticipant = "INSERT INTO zp_conversation_participants (conversationid, citizenid) VALUES (?, ?)"
        local participanOne = MySQL.insert.await(queryParticipant, {
            conversationid,
            citizenid,
        })

        local participanTwo = MySQL.insert.await(queryParticipant, {
            conversationid,
            body.to_citizenid,
        })
        
        print('[Z-PHONE] New conversation created with ID: ' .. conversationid)
    end

    local queryChatting = [[
        SELECT
            from_user.avatar,
			from_user.citizenid,
            CASE
                WHEN c.is_group = 0 THEN
                    COALESCE(
                        contact.contact_name,
                        from_user.phone_number
                    )
                ELSE c.name
            END AS conversation_name,
            DATE_FORMAT(from_user.last_seen, '%d/%m/%Y %H:%i') as last_seen,
            0 as is_read,
            c.id as conversationid,
			c.is_group
        FROM
            zp_conversations c
        JOIN
            zp_conversation_participants p
            ON c.id = p.conversationid
        LEFT JOIN
            zp_conversation_participants other_participant
            ON c.id = other_participant.conversationid
            AND other_participant.citizenid != p.citizenid
        LEFT JOIN
            zp_users from_user
            ON other_participant.citizenid = from_user.citizenid
        LEFT JOIN
            zp_contacts contact
            ON contact.citizenid = p.citizenid
            AND contact.contact_citizenid = other_participant.citizenid
        WHERE
            c.id = ? and p.citizenid = ?
        LIMIT 1
        ]]
            
    local result = MySQL.single.await(queryChatting, {
        conversationid,
        citizenid
    })
    
    print('[Z-PHONE] Chat result: ' .. tostring(result and 'found' or 'not found'))
     
    if result then 
        print('[Z-PHONE] Returning conversation: ' .. result.conversation_name)
        return result
    else
        print('[Z-PHONE] Failed to get conversation details')
        return nil
    end
end)

lib.callback.register('z-phone:server:GetChats', function(source)
    local Player = xCore.GetPlayerBySource(source)
    if Player ~= nil then
        local citizenid = Player.citizenid

        MySQL.Async.execute('UPDATE zp_users SET last_seen = now() WHERE citizenid = ?', { citizenid })

        local query = [[
            WITH LatestMessages AS (
                SELECT
                    conversationid,
                    content,
                    created_at,
                    is_deleted,
                    ROW_NUMBER() OVER (PARTITION BY conversationid ORDER BY created_at DESC) AS rn
                FROM
                    zp_conversation_messages
            )
            SELECT
                from_user.avatar,
				from_user.citizenid,
                CASE
                    WHEN c.is_group = 0 THEN
                        COALESCE(
                            contact.contact_name,
                            from_user.phone_number
                        )
                    ELSE c.name
                END AS conversation_name,
                from_user.phone_number,
                DATE_FORMAT(from_user.last_seen, '%d/%m/%Y %H:%i') as last_seen,
                0 as isRead,
				CASE
                    WHEN last_msg.is_deleted = 1 THEN
                        'This message was deleted'
                    WHEN last_msg.content = '' THEN
                        'media'
                    ELSE last_msg.content
                END AS last_message,
                DATE_FORMAT(last_msg.created_at, '%H:%i') AS last_message_time,
                c.id as conversationid,
				c.is_group
            FROM
                zp_conversations c
            JOIN
                zp_conversation_participants p
                ON c.id = p.conversationid
            LEFT JOIN
                zp_conversation_participants other_participant
                ON c.id = other_participant.conversationid
                AND other_participant.citizenid != p.citizenid
            LEFT JOIN
                zp_users from_user
                ON other_participant.citizenid = from_user.citizenid
            LEFT JOIN
                zp_contacts contact
                ON contact.citizenid = p.citizenid
                AND contact.contact_citizenid = other_participant.citizenid
            LEFT JOIN
                LatestMessages last_msg
                ON c.id = last_msg.conversationid AND last_msg.rn = 1
            WHERE
                p.citizenid = ?
            GROUP BY conversation_name
            ORDER BY
                last_msg.created_at DESC
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

lib.callback.register('z-phone:server:GetChatting', function(source, body)
    local Player = xCore.GetPlayerBySource(source)

    if Player ~= nil then
        local citizenid = Player.citizenid
        
        print('[Z-PHONE] Getting chat messages for conversation: ' .. tostring(body.conversationid))
        
        -- Query simples primeiro para testar
        local query = [[
            SELECT
                zpcm.id,
                zpcm.content as message,
                zpcm.media,
                0 as audio_duration,
                0 as is_audio,
                DATE_FORMAT(zpcm.created_at, '%d %b %Y %H:%i') as time,
                zpcm.sender_citizenid,
                COALESCE(zpcm.is_deleted, 0) as is_deleted,
                TIMESTAMPDIFF(MINUTE, zpcm.created_at, NOW()) AS minute_diff
            FROM
                zp_conversation_messages zpcm 
            WHERE
                conversationid = ? 
            ORDER BY
                id ASC
            LIMIT 200;
        ]]

        local result = MySQL.query.await(query, {
            body.conversationid
        })

        if result then
            print('[Z-PHONE] Found ' .. #result .. ' messages')
            for i, msg in ipairs(result) do
                print('[Z-PHONE] Message ' .. i .. ': ' .. tostring(msg.message) .. ' | Media: ' .. tostring(msg.media))
            end
            return result
        else
            print('[Z-PHONE] No messages found or query failed')
            return {}
        end
    end
    
    print('[Z-PHONE] Player not found')
    return {}
end)

lib.callback.register('z-phone:server:SendChatting', function(source, body)
    local Player = xCore.GetPlayerBySource(source)

    if Player == nil then return false end
    local citizenid = Player.citizenid
    
    print('[Z-PHONE] Sending message - Media: ' .. tostring(body.media) .. ' Message: ' .. tostring(body.message))
    
    local query = "INSERT INTO zp_conversation_messages (conversationid, sender_citizenid, content, media) VALUES (?, ?, ?, ?)"

    local id = MySQL.insert.await(query, {
        body.conversationid,
        citizenid,
        body.message,
        body.media,
    })

    if not id then 
        print('[Z-PHONE] Failed to insert message')
        return false 
    end

    print('[Z-PHONE] Message sent successfully with ID: ' .. id)

    if not body.is_group then
        local contactName = MySQL.scalar.await([[
            SELECT
            COALESCE(
                (SELECT contact_name FROM zp_contacts WHERE citizenid = ? and contact_citizenid = ?),
                (SELECT phone_number FROM zp_users WHERE citizenid = ?)
            ) AS name
        ]], { body.to_citizenid, citizenid, citizenid })
        if contactName then
            body.from = contactName
            body.from_citizenid = citizenid
            local TargetPlayer = xCore.GetPlayerByIdentifier(body.to_citizenid)
            if TargetPlayer ~= nil then
                TriggerClientEvent("z-phone:client:sendNotifMessage", TargetPlayer.source, body)
            end
        end
    else
        local queryGetParticipants = [[
            SELECT * FROM zp_conversation_participants WHERE conversationid = ?
        ]]
        local participans = MySQL.query.await(queryGetParticipants, {body.conversationid})
    
        if not participans then
            return false
        end

        for i, v in pairs(participans) do
            if v.citizenid ~= citizenid then
                local TargetPlayer = xCore.GetPlayerByIdentifier(v.citizenid)
                if TargetPlayer ~= nil then
                    body.to_citizenid = v.citizenid
                    body.from = body.conversation_name
                    body.from_citizenid = citizenid
                    TriggerClientEvent("z-phone:client:sendNotifMessage", TargetPlayer.source, body)
                end
            end
        end
    end

    return id
end)

-- Callback para enviar mensagens de áudio
lib.callback.register('z-phone:server:SendAudioMessage', function(source, body)
    local Player = xCore.GetPlayerBySource(source)

    if Player == nil then return false end
    local citizenid = Player.citizenid
    
    print('[Z-PHONE] Sending audio message - Duration: ' .. tostring(body.duration))
    
    -- Gerar nome único para o arquivo de áudio
    local audioFileName = 'audio_' .. citizenid .. '_' .. os.time() .. '_' .. math.random(1000, 9999) .. '.webm'
    local audioPath = GetResourcePath(GetCurrentResourceName()) .. '/html/sounds/messages/' .. audioFileName
    local audioUrl = './sounds/messages/' .. audioFileName
    
    print('[Z-PHONE] Saving audio to: ' .. audioPath)
    
    -- Salvar o arquivo de áudio no servidor
    local success = false
    if body.audioData and body.audioData ~= "" then
        -- Decodificar base64 e salvar como arquivo
        local audioData = body.audioData
        
        -- Criar o diretório se não existir
        local dir = GetResourcePath(GetCurrentResourceName()) .. '/html/sounds/messages/'
        os.execute('mkdir "' .. dir .. '" 2>nul') -- Windows
        
        -- Salvar arquivo usando Lua
        local file = io.open(audioPath, 'wb')
        if file then
            -- Converter base64 para binário (implementação simples)
            local binaryData = base64Decode(audioData)
            if binaryData then
                file:write(binaryData)
                file:close()
                success = true
                print('[Z-PHONE] Audio file saved successfully: ' .. audioFileName)
            else
                file:close()
                print('[Z-PHONE] Failed to decode base64 audio data')
            end
        else
            print('[Z-PHONE] Failed to create audio file: ' .. audioPath)
        end
    end
    
    -- Se não conseguiu salvar o arquivo, usar fallback
    if not success then
        print('[Z-PHONE] Using fallback - saving as text message')
        audioUrl = '' -- URL vazia para indicar que é só texto
    end
    
    -- Inserir mensagem no banco de dados
    local query = "INSERT INTO zp_conversation_messages (conversationid, sender_citizenid, content, media, audio_duration, is_audio) VALUES (?, ?, ?, ?, ?, ?)"

    local id = MySQL.insert.await(query, {
        body.conversationid,
        citizenid,
        success and '' or '🎤 Audio message (' .. body.duration .. 's)', -- Se salvou arquivo, content vazio; senão, texto
        audioUrl,
        body.duration,
        1 -- is_audio = true
    })

    if not id then 
        print('[Z-PHONE] Failed to insert audio message')
        return false 
    end

    print('[Z-PHONE] Audio message sent successfully with ID: ' .. id)

    -- Notificar outros participantes
    if not body.is_group then
        local contactName = MySQL.scalar.await([[
            SELECT
            COALESCE(
                (SELECT contact_name FROM zp_contacts WHERE citizenid = ? and contact_citizenid = ?),
                (SELECT phone_number FROM zp_users WHERE citizenid = ?)
            ) AS name
        ]], { body.to_citizenid, citizenid, citizenid })
        if contactName then
            body.from = contactName
            body.from_citizenid = citizenid
            body.message = "🎤 Audio message"
            local TargetPlayer = xCore.GetPlayerByIdentifier(body.to_citizenid)
            if TargetPlayer ~= nil then
                TriggerClientEvent("z-phone:client:sendNotifMessage", TargetPlayer.source, body)
            end
        end
    else
        local queryGetParticipants = [[
            SELECT * FROM zp_conversation_participants WHERE conversationid = ?
        ]]
        local participans = MySQL.query.await(queryGetParticipants, {body.conversationid})
    
        if not participans then
            return false
        end

        for i, v in pairs(participans) do
            if v.citizenid ~= citizenid then
                local TargetPlayer = xCore.GetPlayerByIdentifier(v.citizenid)
                if TargetPlayer ~= nil then
                    body.to_citizenid = v.citizenid
                    body.from = body.conversation_name
                    body.from_citizenid = citizenid
                    body.message = "🎤 Audio message"
                    TriggerClientEvent("z-phone:client:sendNotifMessage", TargetPlayer.source, body)
                end
            end
        end
    end

    return {
        messageId = id,
        audioUrl = audioUrl,
        success = success
    }
end)

-- Função para decodificar base64 (implementação simples)
function base64Decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

lib.callback.register('z-phone:server:DeleteMessage', function(source, body)
    local Player = xCore.GetPlayerBySource(source)

    if Player == nil then return false end
    local citizenid = Player.citizenid

    local query = [[
        UPDATE zp_conversation_messages SET is_deleted = 1 WHERE id = ? and sender_citizenid = ?
    ]]

    MySQL.update.await(query, {
        body.id,
        citizenid
    })

    return true
end)

lib.callback.register('z-phone:server:CreateGroup', function(source, body)
    local Player = xCore.GetPlayerBySource(source)

    if Player == nil then return false end
    local citizenid = Player.citizenid

    local queryGetUser = [[
        SELECT * FROM zp_users WHERE phone_number IN (?)
    ]]
    local users = MySQL.query.await(queryGetUser, {body.phone_numbers})

    if not users then
        return false
    end

    local queryNewConv = "INSERT INTO zp_conversations (name, is_group, admin_citizenid) VALUES (?, ?, ?)"
    local conversationid = MySQL.insert.await(queryNewConv, {
        body.name,
        true,
        citizenid,
    })

    local queryParticipant = "INSERT INTO zp_conversation_participants (conversationid, citizenid) VALUES (?, ?)"
    MySQL.insert.await(queryParticipant, {
        conversationid,
        citizenid,
    })

    for i, v in pairs(users) do
        MySQL.Async.insert(queryParticipant, {
            conversationid,
            v.citizenid,
        })

        if v.citizenid ~= citizenid then
            local TargetPlayer = xCore.GetPlayerByIdentifier(v.citizenid)
            if TargetPlayer ~= nil then
                TriggerClientEvent("z-phone:client:sendNotifInternal", TargetPlayer.source, {
                    type = "Notification",
                    from = "Message",
                    message = "You invited to group ".. body.name
                })
            end
        end
    end

    local queryInitChat = "INSERT INTO zp_conversation_messages (conversationid, sender_citizenid, content) VALUES (?, ?, ?)"
    MySQL.insert.await(queryInitChat, {
        conversationid,
        citizenid,
        "Created this group."
    })
    return conversationid
end)