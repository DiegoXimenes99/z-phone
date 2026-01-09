-- Arquivo de inicialização do Z-Phone Server
print("^3[Z-PHONE] === INICIANDO SERVIDOR Z-PHONE ===")
print("^3[Z-PHONE] Config.Core: " .. tostring(Config.Core))

-- Teste imediato das dependências
print("^3[Z-PHONE] Testando dependências...")
print("^3[Z-PHONE] MySQL disponível: " .. tostring(MySQL ~= nil))
print("^3[Z-PHONE] lib disponível: " .. tostring(lib ~= nil))
print("^3[Z-PHONE] Config disponível: " .. tostring(Config ~= nil))

-- Aguarda o framework estar disponível
CreateThread(function()
    local maxAttempts = 30
    local attempts = 0
    
    while not xCore and attempts < maxAttempts do
        attempts = attempts + 1
        print("^3[Z-PHONE] Aguardando framework ser carregado... Tentativa " .. attempts .. "/" .. maxAttempts)
        print("^3[Z-PHONE] xCore atual: " .. tostring(xCore))
        Wait(1000)
    end
    
    if xCore then
        print("^2[Z-PHONE]  Framework carregado com sucesso!")
        print("^2[Z-PHONE]  Core: " .. Config.Core)
        print("^2[Z-PHONE]  xCore.GetPlayerBySource: " .. tostring(xCore.GetPlayerBySource ~= nil))
        print("^2[Z-PHONE]  Servidor Z-Phone inicializado!")
    else
        print("^1[Z-PHONE]  ERRO: Framework não foi carregado após " .. maxAttempts .. " tentativas!")
        print("^1[Z-PHONE]  Verifique se o Config.Core está correto: " .. tostring(Config.Core))
        print("^1[Z-PHONE]  Frameworks suportados: QBX, QB, ESX")
        print("^1[Z-PHONE]  Verifique se o qb-core está iniciado antes do z-phone")
    end
end)