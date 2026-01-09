PlayerJob = {}
Profile = {}
PhoneData = {
    SignalZone = Config.Signal.DefaultSignalZones,
    MetaData = {},
    isOpen = false,
    PlayerData = nil,
    AnimationData = {
        lib = nil,
        anim = nil,
    },
    CallData = {
        InCall = false,
        CallId = nil,
        AnsweredCall = false
    },
}

-- Função para carregar o profile com retry
local function LoadProfile(retryCount)
    retryCount = retryCount or 0
    local maxRetries = 5
    
    if retryCount >= maxRetries then
        print("^1[Z-PHONE] Falha ao carregar profile após " .. maxRetries .. " tentativas")
        return
    end
    
    lib.callback('z-phone:server:GetProfile', false, function(profile)
        if profile and next(profile) ~= nil then
            Profile = profile
            print("^2[Z-PHONE] Profile carregado com sucesso")
        else
            print("^3[Z-PHONE] Profile vazio, tentativa " .. (retryCount + 1) .. "/" .. maxRetries)
            Wait(1000 * (retryCount + 1)) -- Delay progressivo
            LoadProfile(retryCount + 1)
        end
    end)
end

-- Carregamento inicial do profile
CreateThread(function()
    -- Aguarda o jogador estar totalmente carregado
    while not xCore.GetPlayerData() do
        Wait(100)
    end
    
    Wait(1000) -- Aguarda um pouco mais para garantir que tudo esteja inicializado
    
    if next(Profile) == nil then
        LoadProfile()
    end
end)

function IsProfileLoaded()
    local isLoaded = Profile and next(Profile) ~= nil
    if not isLoaded then
        print("^3[Z-PHONE] Profile não está carregado, tentando recarregar...")
        -- Tenta recarregar o profile se não estiver carregado
        LoadProfile()
    end
    return isLoaded
end

-- Função para forçar recarregamento do profile
function ReloadProfile()
    print("^3[Z-PHONE] Forçando recarregamento do profile...")
    Profile = {}
    LoadProfile()
end

function GetStreetName()
    local pos = GetEntityCoords(PlayerPedId())
    local s1, s2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    local street1 = GetStreetNameFromHashKey(s1)
    local street2 = GetStreetNameFromHashKey(s2)
    local streetLabel = street1
    if street2 ~= nil then
        streetLabel = streetLabel .. ' ' .. street2
    end

    return streetLabel
end

local isMovementEnabled = false -- Começa travado

local function DisableDisplayControlActions()
    -- sempre bloqueados
    DisableControlAction(0, 177, true)
    DisableControlAction(0, 200, true)
    DisableControlAction(0, 202, true)
    DisableControlAction(0, 322, true)
    DisableControlAction(0, 245, true)

    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 47, true)
    DisableControlAction(0, 58, true)

    if not isMovementEnabled then
        -- 🔒 TRAVA MOVIMENTO
    end
end


local function ToggleMovement()
    isMovementEnabled = not isMovementEnabled

    SetNuiFocusKeepInput(true)

    -- ISSO É O QUE REALMENTE TRAVA
    SetPlayerControl(PlayerId(), isMovementEnabled, 0)

    if isMovementEnabled then
        xCore.Notify("Camera liberada", 'success', 1500)
    else
        xCore.Notify("Camera travada", 'info', 1500)
    end
end



function OpenPhone()
    local hasWeapon, weaponHash = GetCurrentPedWeapon(PlayerPedId(), true)
    if weaponHash ~= GetHashKey("WEAPON_UNARMED") then
        xCore.Notify("Cannot open phone!", 'error', 3000)
        return
    end

    lib.callback('z-phone:server:HasPhone', false, function(HasPhone)
        if HasPhone then
            PhoneData.PlayerData = xCore.GetPlayerData()
            -- Inicia como funcionava antes - com movimento liberado
            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(true) -- Já inicia com movimento liberado
            SendNUIMessage({
                event = 'z-phone',
                isOpen = true,
            })
            PhoneData.isOpen = true
            isMovementEnabled = true -- Começa com movimento liberado

            CreateThread(function()
                while PhoneData.isOpen do
                    DisableDisplayControlActions()
                    
                    -- ALT para alternar movimento
                    if IsDisabledControlJustPressed(0, 19) then -- LEFT ALT
                        print("^3[DEBUG] ALT detectado!")
                        ToggleMovement()
                    end
                    
                    Wait(1)
                end
                -- Reset quando fechar o celular
                isMovementEnabled = false
            end)

            if not PhoneData.CallData.InCall then
                DoPhoneAnimation('cellphone_text_in')
            else
                DoPhoneAnimation('cellphone_call_to_text')
            end

            SetTimeout(250, function()
                newPhoneProp()
            end)
        else
            xCore.Notify("You don't have a phone", 'error', 3000)
        end
    end)
end

RegisterCommand('phone', function()
    local PlayerData = xCore.GetPlayerData()
    if not PhoneData.isOpen and PlayerData then
        OpenPhone()
    end
end)

RegisterKeyMapping('phone', 'Open Phone', 'keyboard', Config.OpenPhone)

-- Comando para recarregar o profile
RegisterCommand('reloadprofile', function()
    ReloadProfile()
    xCore.Notify("Recarregando profile do celular...", 'info', 3000)
end, false)

-- Comando para verificar status do profile
RegisterCommand('checkprofile', function()
    if IsProfileLoaded() then
        xCore.Notify("Profile carregado: " .. Profile.name, 'success', 3000)
    else
        xCore.Notify("Profile não carregado!", 'error', 3000)
    end
end, false)

RegisterNUICallback('close', function(_, cb)
    isMovementEnabled = true
    SetPlayerControl(PlayerId(), true, 0)
    if not PhoneData.CallData.InCall then
        DoPhoneAnimation('cellphone_text_out')
        SetTimeout(400, function()
            StopAnimTask(PlayerPedId(), PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 2.5)
            deletePhone()
            PhoneData.AnimationData.lib = nil
            PhoneData.AnimationData.anim = nil
        end)
    else
        PhoneData.AnimationData.lib = nil
        PhoneData.AnimationData.anim = nil
        DoPhoneAnimation('cellphone_text_to_call')
    end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    local position = GetEntityCoords(PlayerPedId(), false)
	local object = GetClosestObjectOfType(position.x, position.y, position.z, 5.0, GetHashKey("prop_amb_phone"), false, false, false)
    if object ~= 0 then
		DeleteObject(object)
	end

    SetTimeout(500, function()
        PhoneData.isOpen = false
    end)
    cb('ok')
end)
-- Evento para recarregar o profile
RegisterNetEvent('z-phone:client:reloadProfile', function()
    ReloadProfile()
end)

-- Evento para quando o jogador spawnar
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000) -- Aguarda 2 segundos após o spawn
    if not IsProfileLoaded() then
        print("^3[Z-PHONE] Carregando profile após spawn do jogador")
        LoadProfile()
    end
end)

-- Evento para ESX
AddEventHandler('esx:playerLoaded', function()
    Wait(2000) -- Aguarda 2 segundos após o spawn
    if not IsProfileLoaded() then
        print("^3[Z-PHONE] Carregando profile após spawn do jogador (ESX)")
        LoadProfile()
    end
end)
-- Sistema de verificação periódica do profile
CreateThread(function()
    while true do
        Wait(30000) -- Verifica a cada 30 segundos
        
        if xCore.GetPlayerData() and not IsProfileLoaded() then
            print("^3[Z-PHONE] Profile perdido, tentando recarregar...")
            LoadProfile()
        end
    end
end)