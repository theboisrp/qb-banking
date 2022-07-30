local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    local accts = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_type = ?', { 'Business' })
    if accts[1] ~= nil then
        for _, v in pairs(accts) do
            local acctType = v.business
            if businessAccounts[acctType] == nil then
                businessAccounts[acctType] = {}
            end
            businessAccounts[acctType][tonumber(v.businessid)] = GeneratebusinessAccount(tonumber(v.account_number), tonumber(v.sort_code), tonumber(v.businessid))
            while businessAccounts[acctType][tonumber(v.businessid)] == nil do Wait(0) end
        end
    end

    local savings = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_type = ?', { 'Savings' })
    if savings[1] ~= nil then
        for _, v in pairs(savings) do
            savingsAccounts[v.citizenid] = generateSavings(v.citizenid)
        end
    end

    local gangs = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_type = ?', { 'Gang' })
    if gangs[1] ~= nil then
        for _, v in pairs(gangs) do
            gangAccounts[v.gangid] = loadGangAccount(v.gangid)
        end
    end
end)

exports('business', function(acctType, bid)
    if businessAccounts[acctType] then
        if businessAccounts[acctType][tonumber(bid)] then
            return businessAccounts[acctType][tonumber(bid)]
        end
    end
end)

exports('registerAccount', function(cid)
    local _cid = tonumber(cid)
    currentAccounts[_cid] = generateCurrent(_cid)
end)

exports('current', function(cid)
    if currentAccounts[cid] then
        return currentAccounts[cid]
    end
end)

exports('debitcard', function(cardnumber)
    if bankCards[tonumber(cardnumber)] then
        return bankCards[tonumber(cardnumber)]
    else
        return false
    end
end)

exports('savings', function(cid)
    if savingsAccounts[cid] then
        return savingsAccounts[cid]
    end
end)

exports('gang', function(gid)
    if gangAccounts[gid] then
        return gangAccounts[gid]
    end
end)

RegisterNetEvent('qb-banking:createNewCard', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)

    if xPlayer ~= nil then
        local cid = xPlayer.PlayerData.citizenid
        if (cid) then
            currentAccounts[cid].generateNewCard()
        end
    end

    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")**" .. " created new card")
end)

--[[ -- Only used by the following "qb-banking:initiateTransfer"

local function getCharacterName(cid)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local name = player.PlayerData.name
end

local function checkAccountExists(acct, sc)
    local success
    local cid
    local actype
    local processed = false
    local exists = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_number = ? AND sort_code = ?', { acct, sc })
    if exists[1] ~= nil then
        success = true
        cid = exists[1].character_id
        actype = exists[1].account_type
    else
        success = false
        cid = false
        actype = false
    end
    processed = true
    repeat Wait(0) until processed == true
    return success, cid, actype
end



RegisterServerEvent('qb-base:itemUsed')
AddEventHandler('qb-base:itemUsed', function(_src, data)
    if data.item == "moneybag" then
        TriggerClientEvent('qb-banking:client:usedMoneyBag', _src, data)
    end
end)
]]
QBCore.Functions.CreateCallback('qb-banking:server:checkbank', function(source, cb)
    local src = source
    exports.oxmysql:single('SELECT * FROM `info` WHERE name = "bank";', {}, function(result)
        if result then
            cb(result.bool)
        else
            cb("false")
        end
    end)
end)
RegisterServerEvent('qb-banking:server:unpackMoneyBag')
AddEventHandler('qb-banking:server:unpackMoneyBag', function(item)
    local _src = source
    if item ~= nil then
        local xPlayer = QBCore.Functions.GetPlayer(_src)
        local xPlayerCID = xPlayer.PlayerData.citizenid
        local decode = json.decode(item.metapublic)
        --_char:Inventories():Remove().Item(item, 1)
        --_char:Cash().Add(tonumber(decode.amount))
        --TriggerClientEvent('pw:notification:SendAlert', _src, {type = "success", text = "The cashier has counted your money bag and gave you $"..decode.amount.." cash.", length = 5000})
    end
end)


local function isbanklocked(xPlayer, cb)
    local citizenid = xPlayer.PlayerData.citizenid
    exports.oxmysql:single('SELECT * FROM players where citizenid = ?', { citizenid }, function(result)
        if result then
            print(result.banklocked)
            cb(result.banklocked)
        else
            cb("false")
        end
    end)
end
function getCharacterName(cid)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local name = player.PlayerData.name
end

RegisterServerEvent('qb-banking:initiateTransfer')
AddEventHandler('qb-banking:initiateTransfer', function(data)
    amount = data.amount
    iban = data.account
    bizacc = data.bizacc
    if bizacc == nil then
        local Player = QBCore.Functions.GetPlayer(source)
        if (Player.PlayerData.money.bank - amount) >= 0 then
            local query = '%' .. iban .. '%'
            local result = exports.oxmysql:executeSync('SELECT * FROM players WHERE charinfo LIKE ?', {query})
            if result[1] ~= nil then
                local Reciever = QBCore.Functions.GetPlayerByCitizenId(result[1].citizenid)

                Player.Functions.RemoveMoney('bank', amount)

                if Reciever ~= nil then
                    Reciever.Functions.AddMoney('bank', amount)
                else
                    local RecieverMoney = json.decode(result[1].money)
                    RecieverMoney.bank = (RecieverMoney.bank + amount)
                    exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?',
                        {json.encode(RecieverMoney), result[1].citizenid})
                end

                TriggerClientEvent('qb-banking:openBankScreen', source)
                TriggerEvent('logsystem:log', src, "Bank Tranfer ("..tostring(amount)..") from ("..tostring(Player.PlayerData.citizenid)..") to ("..tostring(result[1].citizenid)..")")
                TriggerClientEvent('qb-banking:successAlert', source, 'Transfered successfully.')
            elseif exports.oxmysql:executeSync("SELECT * FROM bank_accounts WHERE accountnumber = ?", {iban})[1] ~= nil then
                local result = exports.oxmysql:executeSync("SELECT * FROM bank_accounts WHERE accountnumber = ?", {iban})[1]
                Player.Functions.RemoveMoney('bank', amount)
                --exports.oxmysql:execute("UPDATE players SET money = ? WHERE citizenid = ?'",{json.encode(RecieverMoney), result["citizenid"]})

                local RecieverMoney = result["amount"]
                RecieverMoney = RecieverMoney + amount
                exports.oxmysql:execute("UPDATE bank_accounts SET amount = ? WHERE accountnumber = ?",{RecieverMoney, iban})

                TriggerClientEvent('qb-banking:openBankScreen', source)
                TriggerEvent('logsystem:log', src, "Bank Tranfer ("..tostring(amount)..") from ("..tostring(Player.PlayerData.citizenid)..") to ("..tostring(iban)..")")
                TriggerClientEvent('qb-banking:successAlert', source, 'Transfered successfully.')
            else
                TriggerClientEvent('qb-banking:openBankScreen', source)
                TriggerClientEvent('qb-banking:successAlert', source, 'This Account does not exist.')
            end
        end
    else
        if (bizacc.bizamount - amount) >= 0 then
            local query = '%' .. iban .. '%'
            local result = exports.oxmysql:executeSync('SELECT * FROM players WHERE charinfo LIKE ?', {query})
            if result[1] ~= nil then
                local Reciever = QBCore.Functions.GetPlayerByCitizenId(result[1].citizenid)
                sendertotal = bizacc.bizamount - amount
                exports.oxmysql:execute("UPDATE bank_accounts SET amount = ? WHERE accountnumber = ?",{sendertotal, bizacc.bizid})

                if Reciever ~= nil then
                    Reciever.Functions.AddMoney('bank', amount)
                else
                    local RecieverMoney = json.decode(result[1].money)
                    RecieverMoney.bank = (RecieverMoney.bank + amount)
                    exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?', {json.encode(RecieverMoney), result[1].citizenid})
                end

                TriggerClientEvent('qb-banking:bizrefresh', source)
                TriggerClientEvent('qb-banking:openBankScreen', source)
                TriggerEvent('logsystem:log', src, "Bank Tranfer ("..tostring(amount)..") from ("..tostring(bizacc.bizid)..") to ("..tostring(result[1].citizenid)..")")
                TriggerClientEvent('qb-banking:successAlert', source, 'Transfered successfully.')
            elseif exports.oxmysql:executeSync("SELECT * FROM bank_accounts WHERE accountnumber = ?", {iban})[1] ~= nil then
                local result = exports.oxmysql:executeSync("SELECT * FROM bank_accounts WHERE accountnumber = ?", {iban})[1]
                sendertotal = bizacc.bizamount - amount
                exports.oxmysql:execute("UPDATE bank_accounts SET amount = ? WHERE buisnessid = ?",{sendertotal, bizacc.bizid})

                local RecieverMoney = result["amount"]
                RecieverMoney = RecieverMoney + amount
                exports.oxmysql:execute("UPDATE bank_accounts SET amount = ? WHERE accountnumber = ?",{RecieverMoney, iban})

                TriggerClientEvent('qb-banking:bizrefresh', source)
                TriggerClientEvent('qb-banking:openBankScreen', source)
                TriggerEvent('logsystem:log', src, "Bank Tranfer ("..tostring(amount)..") from ("..tostring(bizacc.bizid)..") to ("..tostring(iban)..")")
                TriggerClientEvent('qb-banking:successAlert', source, 'Transfered successfully.')
            else
                TriggerClientEvent('qb-banking:openBankScreen', source)
                TriggerClientEvent('qb-banking:successAlert', source, 'This Account does not exist.')
            end
        end
    end
end)

local function format_int(number)
    local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
    int = int:reverse():gsub("(%d%d%d)", "%1,")
    return minus .. int:reverse():gsub("^,", "") .. fraction
end
RegisterServerEvent('qb-banking:createbusinessaccount')
AddEventHandler('qb-banking:createbusinessaccount', function(data)
    local src = source
    exports.oxmysql:insert("INSERT INTO `bank_accounts` (`buisness`, `buisnessid`, `amount`, `account_type`, `accountnumber`, `password`) VALUES (:bizname, :bizid, '5000', 'Buisness', :accn, :pass);", {
        bizname = data.bname,
        bizid = data.bid,
        accn = 'US0' .. math.random(1, 9) .. 'QBCore' .. math.random(1111, 9999) .. math.random(1111, 9999) .. math.random(11, 99),
        pass = data.bpass
    })
    TriggerClientEvent('qb-banking:openBankScreen', src)
    TriggerClientEvent('qb-banking:successAlert', src, 'You made a business successfully.')
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")** made a business account successfully.")
end)


RegisterServerEvent('qb-banking:createbusinessloanaccount')
AddEventHandler('qb-banking:createbusinessloanaccount', function(loanee, amount, paybackamount, timetopayback)
    local src = QBCore.Functions.GetSource(loanee)
    local xPlayer = QBCore.Functions.GetPlayer(src)
    print(src)
    local name = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
    local cid = xPlayer.PlayerData.citizenid

    accn = 'US0' .. math.random(1, 9) .. 'QBCore' .. math.random(1111, 9999) .. math.random(1111, 9999) .. math.random(11, 99)
    exports.oxmysql:insert("INSERT INTO `bank_accounts` (`buisness`, `buisnessid`, `amount`, `account_type`, `accountnumber`, `password`) VALUES (:bizname, :bizid, :amount, 'Buisness', :accn, :pass);", {
        bizname = "loan for " .. name,
        bizid = "loan" .. cid,
        accn = accn,
        pass = "qbloan",
        amount = amount * -1,
    })
    exports.oxmysql:insert("INSERT INTO `loans` (`cid`, `amount`, `bizaccountnumber`, `bizid`, `bizpass`, `pbamount`, `ttp`) VALUES (:cid, :amount, :accn, :bizid, :bizpass, pbamount, ttp);", {
        cid = xPlayer.cid,
        bizid = "loan" + xPlayer.cid,
        accn = accn,
        pass = "qbloan",
        amount = amount,
        pbamount = paybackamount,
        ttp = timetopayback,
    })
    TriggerClientEvent('qb-banking:openBankScreen', src)
    TriggerClientEvent('qb-banking:successAlert', src, 'Loan Created.')
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")** made a business account successfully.")
end)

QBCore.Functions.CreateCallback('qb-banking:getBankingInformation', function(source, cb)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    while xPlayer == nil do Wait(0) end
        if (xPlayer) then
            isbanklocked(xPlayer, function(result)
                if (result == "true") then
                    notlocked = false
                else
                    notlocked = true
                end
                if (notlocked) then 
                    local banking = {
                        ['name'] = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname,
                        ['bankbalance'] = '$'.. format_int(xPlayer.PlayerData.money['bank']),
                        ['cash'] = '$'.. format_int(xPlayer.PlayerData.money['cash']),
                        ['accountinfo'] = xPlayer.PlayerData.charinfo.account,
                        ['card'] = xPlayer.PlayerData.charinfo.card
                    }
                    
                    if savingsAccounts[xPlayer.PlayerData.citizenid] then
                        local cid = xPlayer.PlayerData.citizenid
                        banking['savings'] = {
                            ['amount'] = savingsAccounts[cid].GetBalance(),
                            ['details'] = savingsAccounts[cid].getAccount(),
                            ['statement'] = savingsAccounts[cid].getStatement(),
                        }
                    end
                    cb(banking)
                else 
                    banking = {
                        ['name'] = "Account Locked",
                        ['bankbalance'] = '$'.. format_int(0),
                        ['cash'] = '$'.. format_int(xPlayer.PlayerData.money['cash']),
                        ['accountinfo'] = "00000000000000000000000000000000000",
                        ['card'] = xPlayer.PlayerData.charinfo.card,
                    }
                    if (xPlayer.PlayerData.charinfo.card) then
                        xPlayer.PlayerData.charinfo.card.cardLocked = true
                    end
                    cb(banking)
                end
            end)
        else
            cb(nil)
        end
end)

RegisterServerEvent('qb-banking:createBankCard')
AddEventHandler('qb-banking:createBankCard', function(pin, bizacc)
    newbankcard(pin, bizacc)
end)

function newbankcard(pin, bizacc)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local cid = xPlayer.PlayerData.citizenid
    local cardNumber = math.random(1000000000000000,9999999999999999)
    local info = {}
    local selectedCard = Config.cardTypes[math.random(1,#Config.cardTypes)]
    if bizacc == nil then
        info.name = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
        info.citizenid = cid
        info.bizacc = false
    else
        info.name = bizacc.bizname
        info.citizenid = bizacc.bizid
        info.bizacc = true
    end
    info.cardNumber = cardNumber
    info.cardPin = tonumber(pin)
    info.cardActive = true
    info.cardType = selectedCard
    info.cardLocked = false
    
    if selectedCard == "visa" then
        xPlayer.Functions.AddItem('visa', 1, nil, info)
    elseif selectedCard == "mastercard" then
        xPlayer.Functions.AddItem('mastercard', 1, nil, info)
    end
    if bizacc == nil then
        xPlayer.Functions.SetCreditCard(cardNumber)
    else
        setcardbiz(info, bizacc)
    end
    --TriggerClientEvent('QBCore:Player:UpdatePlayerData', src)
    TriggerClientEvent('qb-banking:openBankScreen', src)
    TriggerClientEvent('QBCore:Notify', src, Lang:t('success.debit_card'), 'success')

    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")** successfully ordered a debit card")
end

RegisterNetEvent('qb-banking:doQuickDeposit', function(amount)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    while xPlayer == nil do Wait(0) end
    local currentCash = xPlayer.Functions.GetMoney('cash')

    if tonumber(amount) <= currentCash then
        xPlayer.Functions.RemoveMoney('cash', tonumber(amount), 'banking-quick-depo')
        local bank = xPlayer.Functions.AddMoney('bank', tonumber(amount), 'banking-quick-depo')
        if bank then
            TriggerClientEvent('qb-banking:openBankScreen', src)
            TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.cash_deposit', {value = amount}))
            TriggerEvent('logsystem:log', src, "Bank Deposit ("..tostring(amount)..")")
            TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")** made a cash deposit of $"..amount.." successfully.")
        end
    end
end)


-- biz deposit
RegisterServerEvent('qb-banking:doBizQuickDeposit')
AddEventHandler('qb-banking:doBizQuickDeposit', function(amount, bizacc)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    while xPlayer == nil do Wait(0) end
    local currentCash = xPlayer.Functions.GetMoney('cash')

    if tonumber(amount) <= currentCash then
        local cash = xPlayer.Functions.RemoveMoney('cash', tonumber(amount), 'banking-quick-depo')
        setmoneybiz(bizacc.bizamount + amount, bizacc)
        bizrefresh(bizacc, src)
        TriggerEvent('logsystem:log', src, "Biz Deposit ("..tostring(amount)..") to ("..tostring(bizacc.bizid)..")")
        TriggerClientEvent('qb-banking:successAlert', src, 'You made a cash deposit of $'..amount..' successfully.')
        TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")** made a cash deposit of $"..amount.." successfully.")
    end
end)

RegisterServerEvent('qb-banking:biznpdeposit')
AddEventHandler('qb-banking:biznpdeposit', function(amount, bizacc)
    setmoneybiz(bizacc.bizamount + amount, bizacc)
    TriggerEvent('logsystem:log', src, "Biz Deposit ("..tostring(amount)..") to ("..tostring(bizacc.bizid)..")")
end)
--biz deposit



RegisterServerEvent('qb-banking:toggleCard')
AddEventHandler('qb-banking:toggleCard', function(toggle, bizacc)
    if bizacc == nil then
        local src = source
        local xPlayer = QBCore.Functions.GetPlayer(src)
        cardinfo = xPlayer.PlayerData.charinfo.card
        cardinfo.cardLocked = toggle
        xPlayer.Functions.SetCreditCard(cardinfo)
    else
        carddata = bizacc.card
        carddata["cardLocked"] = toggle
    end
end)

RegisterNetEvent('qb-banking:doQuickWithdraw', function(amount, _)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    while xPlayer == nil do Wait(0) end
    local currentCash = xPlayer.Functions.GetMoney('bank')

    if tonumber(amount) <= currentCash then
        local cash = xPlayer.Functions.RemoveMoney('bank', tonumber(amount), 'banking-quick-withdraw')
        bank = xPlayer.Functions.AddMoney('cash', tonumber(amount), 'banking-quick-withdraw')
        if cash then
            TriggerClientEvent('qb-banking:openBankScreen', src)
            TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.cash_withdrawal', {value = amount}))
            TriggerEvent('logsystem:log', src, "Bank Withdraw ("..tostring(amount)..")")
            TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'red', "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")** made a cash withdrawal of $"..amount.." successfully.")
        end
    end
end)

--biz withdraw
RegisterServerEvent('qb-banking:doBizQuickWithdraw')
AddEventHandler('qb-banking:doBizQuickWithdraw', function(amount, bizacc)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    while xPlayer == nil do Wait(0) end
    local currentCash = bizacc.bizamount
    
    if tonumber(amount) <= currentCash then
        setmoneybiz(bizacc.bizamount - amount, bizacc)
        local bank = xPlayer.Functions.AddMoney('cash', tonumber(amount), 'banking-quick-withdraw')
        bizrefresh(bizacc, src)
        TriggerEvent('logsystem:log', src, "Biz Withdraw ("..tostring(amount)..") from ("..tostring(bizacc)..")")
        TriggerClientEvent('qb-banking:successAlert', src, 'You made a cash withdrawal of $'..amount..' successfully.')
        TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'red', "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")** made a cash withdrawal of $"..amount.." successfully.")
    end
end)
--biz withdraw



RegisterNetEvent('qb-banking:updatePin', function(pin)
    if pin ~= nil then 
        local src = source
        local xPlayer = QBCore.Functions.GetPlayer(src)

        cardinfo = xPlayer.PlayerData.charinfo.card
        cardinfo.cardPin = pin
        xPlayer.Functions.SetCreditCard(cardinfo)
        TriggerClientEvent('qb-banking:openBankScreen', src)
        TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.updated_pin'))
    end
end)

RegisterNetEvent('qb-banking:savingsDeposit', function(amount)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    while xPlayer == nil do Wait(0) end
    local currentBank = xPlayer.Functions.GetMoney('bank')

    if tonumber(amount) <= currentBank then
        local bank = xPlayer.Functions.RemoveMoney('bank', tonumber(amount))
        local savings = savingsAccounts[xPlayer.PlayerData.citizenid].AddMoney(tonumber(amount), Lang:t('info.current_to_savings'))
        while bank == nil do Wait(0) end
        while savings == nil do Wait(0) end
        TriggerClientEvent('qb-banking:openBankScreen', src)
        TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.savings_deposit', {value = tostring(amount)}))
        TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")** made a savings deposit of $"..tostring(amount).." successfully..")
    end
end)


function setmoneybiz(amount, bizacc)
    exports.oxmysql:executeSync("UPDATE `bank_accounts` SET `amount` = :amount WHERE `bank_accounts`.`buisnessid` = :bid;",{
        bid = bizacc.bizid,
        amount = amount
    })
end

function setcardbiz(card, bizacc)
    exports.oxmysql:executeSync("UPDATE `bank_accounts` SET card = :card WHERE buisnessid = :bid;",{
        bid = bizacc.bizid,
        card = json.encode(card)
    })
end


RegisterNetEvent("qb-banking:businesssignin")
AddEventHandler("qb-banking:businesssignin", function(data)
    local src = source
    dbdata = exports.oxmysql:executeSync('SELECT * FROM bank_accounts WHERE buisnessid = ?', { data.bizid })
    bizacc = {}
    bizacc.password = dbdata[1]["password"]
    bizacc.bizname = dbdata[1]["buisness"]
    bizacc.bizid = dbdata[1]["buisnessid"]
    bizacc.bizamount = dbdata[1]["amount"]
    bizacc.bizaccn = dbdata[1]["accountnumber"]
    if bizacc.password == data.bpass then
        if dbdata[1]["banklocked"] == "true" then
            TriggerClientEvent('qb-banking:successAlert', src, 'Account Locked')
        else 
            TriggerClientEvent('qb-banking:loginsucess', src, bizacc)
        end
    else
        TriggerClientEvent('qb-banking:successAlert', src, 'Invalid login')
        TriggerClientEvent('qb-banking:openBankScreen', src)
    end
end)

function bizrefresh(data, src)
    dbdata = exports.oxmysql:executeSync('SELECT * FROM bank_accounts WHERE buisnessid = ?', { data.bizid })
    bizacc = {}
    bizacc.password = dbdata[1]["password"]
    bizacc.bizname = dbdata[1]["buisness"]
    bizacc.bizid = dbdata[1]["buisnessid"]
    bizacc.bizamount = dbdata[1]["amount"]
    bizacc.bizaccn = dbdata[1]["accountnumber"]
    TriggerClientEvent('qb-banking:bizrefresh', src, bizacc)
end

RegisterNetEvent('qb-banking:savingsWithdraw', function(amount)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    while xPlayer == nil do Wait(0) end
    local currentSavings = savingsAccounts[xPlayer.PlayerData.citizenid].GetBalance()

    if tonumber(amount) <= currentSavings then
        local savings = savingsAccounts[xPlayer.PlayerData.citizenid].RemoveMoney(tonumber(amount), Lang:t('info.savings_to_current'))
        local bank = xPlayer.Functions.AddMoney('bank', tonumber(amount), 'banking-quick-withdraw')
        while bank == nil do Wait(0) end
        while savings == nil do Wait(0) end
        TriggerClientEvent('qb-banking:openBankScreen', src)
        TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.savings_withdrawal', {value = tostring(amount)}))
        TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'red', "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")** made a savings withdrawal of $"..tostring(amount).." successfully.")
    end
end)

RegisterNetEvent('qb-banking:createSavingsAccount', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local success = createSavingsAccount(xPlayer.PlayerData.citizenid)
    repeat Wait(0) until success ~= nil
    TriggerClientEvent('qb-banking:openBankScreen', src)
    TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.opened_savings'))
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', "lightgreen", "**"..GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: "..xPlayer.PlayerData.citizenid.." | id: "..xPlayer.PlayerData.source..")** opened a savings account")
end)


QBCore.Commands.Add('givecash', Lang:t('command.givecash'), {{name = 'id', help = 'Player ID'}, {name = 'amount', help = 'Amount'}}, true, function(source, args)
    local src = source
	local id = tonumber(args[1])
	local amount = math.ceil(tonumber(args[2]))

	if id and amount then
		local xPlayer = QBCore.Functions.GetPlayer(src)
		local xReciv = QBCore.Functions.GetPlayer(id)
        TriggerEvent('logsystem:log', source, "Cash Transfer ("..tostring(amount)..") from ("..tostring(xPlayer.PlayerData.citizenid)..") to ("..tostring(xReciv.PlayerData.citizenid)..")")
		if xReciv and xPlayer then
			if not xPlayer.PlayerData.metadata["isdead"] then
				local distance = xPlayer.PlayerData.metadata["inlaststand"] and 3.0 or 10.0
				if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(id))) < distance then
                    if amount > 0 then
                        if xPlayer.Functions.RemoveMoney('cash', amount) then
                            if xReciv.Functions.AddMoney('cash', amount) then
                                TriggerClientEvent('QBCore:Notify', src, Lang:t('success.give_cash',{id = tostring(id), cash = tostring(amount)}), "success")
                                TriggerClientEvent('QBCore:Notify', id, Lang:t('success.received_cash',{id = tostring(src), cash = tostring(amount)}), "success")
                                TriggerClientEvent("payanimation", src)
                            else
                                -- Return player cash
                                xPlayer.Functions.AddMoney('cash', amount)
                                TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_give'), "error")
                            end
                        else
                            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_enough'), "error")
                        end
                    else
                        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.invalid_amount'), "error")
                    end
				else
					TriggerClientEvent('QBCore:Notify', src, Lang:t('error.too_far_away'), "error")
				end
			else
				TriggerClientEvent('QBCore:Notify', src, Lang:t('error.dead'), "error")
			end
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.wrong_id'), "error")
		end
	else
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.givecash'), "error")
	end
end)

RegisterNetEvent("payanimation", function()
    TriggerEvent('animations:client:EmoteCommandStart', {"id"})
end)
QBCore.Commands.Add('banktest', 'bank test (GOD ONLY)', {}, false, function(source, args)
    TriggerClientEvent('qb-banking:openBankScreen', source)
end)

QBCore.Commands.Add('createloan', 'Creates a loan (BANKER ONLY)', {{name = 'id', help = 'Player ID'}, {name = 'amount', help = 'Amount'}}, true, function(source, args)
    TriggerEvent('qb-banking:createbusinessloanaccount', args[1], args[2])
end)
