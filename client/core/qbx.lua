if Config.Core == "QBX" then 
    xCore = {}
    local QBX = exports["qb-core"]:GetCoreObject()

    xCore.GetPlayerData = function()
        local ply = QBX.Functions.GetPlayerData()
        if not ply or not ply.citizenid then 
            return nil 
        end
        return {
            citizenid = ply.citizenid
        }
    end

    xCore.Notify = function(msg, typ, time)
        if typ == 'success' then
            TriggerEvent('QBCore:Notify', msg, 'success', time or 5000)
        elseif typ == 'error' then
            TriggerEvent('QBCore:Notify', msg, 'error', time or 5000)
        else
            TriggerEvent('QBCore:Notify', msg, 'primary', time or 5000)
        end
    end

    xCore.HasItemByName = function(item)
        return QBX.Functions.HasItem(item)
    end

    xCore.GetClosestPlayer = function ()
        return QBX.Functions.GetClosestPlayer()
    end
end