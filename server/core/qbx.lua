if Config.Core == "QBX" then 
    print("^3[Z-PHONE] Inicializando xCore para QBX...")
    xCore = {}
    local QBX = exports["qb-core"]:GetCoreObject()
    local ox_inventory = exports.ox_inventory

    xCore.GetPlayerBySource = function(source)
        local ply = QBX.Functions.GetPlayer(source)
        if not ply or not ply.PlayerData then 
            print("^1[Z-PHONE] Player ou PlayerData não encontrado para source: " .. tostring(source))
            return nil 
        end

        if not ply.PlayerData.citizenid then
            print("^1[Z-PHONE] CitizenID não encontrado para source: " .. tostring(source))
            return nil
        end

        return {
            source = ply.PlayerData.source,
            citizenid = ply.PlayerData.citizenid,
            name = (ply.PlayerData.charinfo.firstname or "") .. ' '.. (ply.PlayerData.charinfo.lastname or ""),
            job = {
                name = ply.PlayerData.job.name or "unemployed",
                label = ply.PlayerData.job.label or "Unemployed"
            },
            money = {
                cash = ply.PlayerData.money.cash or 0,
                bank = ply.PlayerData.money.bank or 0,
            },
            removeCash = function (amount)
                ply.Functions.RemoveMoney('cash', amount)
            end,
            removeAccountMoney = function (account, amount, reason)
                ply.Functions.RemoveMoney(account, amount, reason)
            end,
            addAccountMoney = function (account, amount, reason)
                ply.Functions.AddMoney(account, amount, reason)
            end
        }
    end

    xCore.GetPlayerByIdentifier = function(identifier)
        local ply = QBX.Functions.GetPlayerByCitizenId(identifier)
        if not ply then return nil end
        return {
            source = ply.PlayerData.source,
            citizenid = ply.PlayerData.citizenid,
            name = ply.PlayerData.charinfo.firstname .. ' '.. ply.PlayerData.charinfo.lastname,
            job = {
                name = ply.PlayerData.job.name,
                label = ply.PlayerData.job.label
            },
            money = {
                cash = ply.PlayerData.money.cash,
                bank = ply.PlayerData.money.bank,
            },
            removeCash = function (amount)
                ply.Functions.RemoveMoney('cash', amount)
            end,
            removeAccountMoney = function (account, amount, reason)
                ply.Functions.RemoveMoney(account, amount, reason)
            end,
            addAccountMoney = function (account, amount, reason)
                ply.Functions.AddMoney(account, amount, reason)
            end
        }
    end

    xCore.HasItemByName = function(source, item)
        local success, result = pcall(function()
            return ox_inventory:GetItem(source, item, nil, false).count >= 1
        end)
        return success and result or false
    end

    xCore.AddMoneyBankSociety = function(society, amount, reason)
        exports['qb-banking']:AddMoney(society, amount, reason)
    end

    xCore.queryPlayerVehicles = function()
        local query = [[
            select 
                pv.vehicle,
                pv.plate,
                pv.garage,
                pv.fuel,
                pv.engine,
                pv.body,
                pv.state,
                DATE_FORMAT(now(), '%d %b %Y %H:%i') as created_at
            from player_vehicles pv WHERE pv.citizenid = ? order by plate asc
        ]]

        return query
    end

    xCore.queryPlayerHouses = function()
        local query = [[
            SELECT 
                hl.id,
                hl.property_name AS name, 
                0 as tier,
                hl.coords,
                0 as is_has_garage, 
                1 AS is_house_locked, 
                1 AS is_garage_locked, 
                1 AS is_stash_locked, 
                hl.keyholders 
            FROM 
                properties hl 
            WHERE hl.owner = ?
            ORDER BY hl.id DESC
        ]]

        return query
    end

    xCore.bankHistories = function(citizenid)
        local query = [[
            select transactions
            from player_transactions
            where id = ? order by id desc
        ]]

        local histories = MySQL.single.await(query, { citizenid })
        if not histories then
            histories = {}
        else
            histories = json.decode(histories.transactions)
        end

        local historiesNew = {}
        for i, v in pairs(histories) do
            historiesNew[#historiesNew + 1] = {
                type = v.trans_type,
                label = v.title,
                total = v.amount,
                created_at = os.date("%Y-%m-%d %H:%M:%S", v.time),
            }
        end
        return historiesNew
    end

    xCore.bankInvoices = function(citizenid)
        return {}
    end

    xCore.bankInvoiceByCitizenID = function(id, citizenid)
        print("^3[Z-PHONE] bankInvoiceByCitizenID não implementado")
        return nil
    end

    xCore.deleteBankInvoiceByID = function(id)
        print("^3[Z-PHONE] deleteBankInvoiceByID não implementado")
    end
    
    print("^2[Z-PHONE] xCore inicializado com sucesso para QBX")
end