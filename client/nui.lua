RegisterNetEvent("hidemenu")
AddEventHandler("hidemenu", function()
    InBank = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        status = "closebank"
    })
end)

RegisterNUICallback("NUIFocusOff", function(data, cb)
    InBank = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        status = "closebank"
    })
end)

RegisterNetEvent('qb-banking:client:newCardSuccess')
AddEventHandler('qb-banking:client:newCardSuccess', function(cardno, ctype)
    SendNUIMessage({
        status = "updateCard",
        number = cardno,
        cardtype = ctype
    })
end)

RegisterNUICallback("createSavingsAccount", function(data, cb)
    TriggerServerEvent('qb-banking:createSavingsAccount')
end)

RegisterNUICallback("doDeposit", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:doQuickDeposit', data.amount)
        TriggerServerEvent('logsystem:log', GetPlayerServerId(PlayerId()), "Deposited Money ("..tostring(data.amount)..")")
        openAccountScreen()
    end
end)

RegisterNUICallback("doWithdraw", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:doQuickWithdraw', data.amount, true)
        TriggerServerEvent('logsystem:log', GetPlayerServerId(PlayerId()), "Withdrew Money ("..tostring(data.amount)..")")
        openAccountScreen()
    end
end)



--biz 
RegisterNUICallback("doBizDeposit", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:doBizQuickDeposit', data.amount, data.bizacc)
        TriggerServerEvent('logsystem:log', GetPlayerServerId(PlayerId()), "Deposited Biz Money ("..tostring(data.amount)..") to ("..tostring(data.bizacc)..")")
        openAccountScreen()
    end
end)

RegisterNUICallback("doBizWithdraw", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:doBizQuickWithdraw', data.amount, data.bizacc)
        TriggerServerEvent('logsystem:log', GetPlayerServerId(PlayerId()), "Withdrew Biz Money ("..tostring(data.amount)..") to ("..tostring(data.bizacc)..")")
        openAccountScreen()
    end
end)
--biz




RegisterNUICallback("doATMWithdraw", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:doQuickWithdraw', data.amount, false)
        TriggerServerEvent('logsystem:log', GetPlayerServerId(PlayerId()), "Withdrew Money ("..tostring(data.amount)..")")
        openAccountScreen()
    end
end)

RegisterNUICallback("savingsDeposit", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:savingsDeposit', data.amount)
        openAccountScreen()
    end
end)

RegisterNUICallback("requestNewCard", function(data, cb)
    TriggerServerEvent('qb-banking:createNewCard')
end)

RegisterNUICallback("savingsWithdraw", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:savingsWithdraw', data.amount)
        openAccountScreen()
    end
end)

RegisterNUICallback("createbusinessaccount", function(data, cb)
    if data ~= nil then
        TriggerServerEvent('qb-banking:createbusinessaccount', data)
    end
end)

RegisterNUICallback("doTransfer", function(data, cb)
    if data ~= nil then
        TriggerServerEvent('qb-banking:initiateTransfer', data)
        TriggerServerEvent('logsystem:log', GetPlayerServerId(PlayerId()), "Transfer Money ("..tostring(data.amount)..") from ("..tostring(data.bizacc)..") to ("..tostring(data.account)..")")
    end
end)

RegisterNUICallback("createDebitCard", function(data, cb)
    if data.pin ~= nil then
        TriggerServerEvent('qb-banking:createBankCard', data.pin, data.bizacc)
    end
end)

RegisterNUICallback("lockCard", function(data, cb)
    TriggerServerEvent('qb-banking:toggleCard', true)
end)

RegisterNUICallback("unLockCard", function(data, cb)
    TriggerServerEvent('qb-banking:toggleCard', false)
end)

RegisterNUICallback("updatePin", function(data, cb)
    if data.pin ~= nil then 
        TriggerServerEvent('qb-banking:updatePin', data.pin)
    end
end)

RegisterNUICallback("businesssignin", function(data, cb)
    TriggerServerEvent("qb-banking:businesssignin", data)
end)

RegisterNUICallback("bizrefresh", function(data, cb)
    TriggerServerEvent("qb-banking:bizrefresh", data)
end)