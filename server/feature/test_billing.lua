print("^1[TEST] === ARQUIVO DE TESTE CARREGADO ===")

RegisterCommand('testfile', function(source, args)
    print("^2[TEST] Comando testfile funcionando!")
    if source == 0 then
        print("^2[TEST] Executado do console")
    else
        print("^2[TEST] Executado por player: " .. tostring(source))
    end
end, true)

print("^1[TEST] === COMANDO TESTFILE REGISTRADO ===")