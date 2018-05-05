local url="https://www.equateplus.com"
--local url="http://localhost/test"

local baseurl
local reportOnce
local Version=1.1

WebBanking{version=Version, url=url,services    = {"EquatePlus"},
  description = "Depot von EquatePlus"}


function SupportsBank (protocol, bankCode)
  return  protocol == ProtocolWebBanking and bankCode == "EquatePlus"  -- .
end

local html

function tprint (tbl, indent)
  if not indent then indent = 3 end
  for k, v in pairs(tbl) do
    formatting = string.rep(" ", indent) .. k .. ": "
    print(formatting .. type(v))
    if type(v) == 'table' and indent < 9 then tprint(v,indent+3) end
  end
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)

  -- Login.
  connection = Connection()
  -- get login page
  html = HTML(connection:get(url))
  -- first login stage
  html:xpath("//*[@id='eqUserId']"):attr("value", username)
  html:xpath("//*[@id='submitField']"):attr("value","Continue Login")
  html= HTML(connection:request(html:xpath("//*[@id='loginForm']"):submit()))
  -- second login stage
  html:xpath("//*[@id='eqUserId']"):attr("value", username)
  html:xpath("//*[@id='eqPwdId']"):attr("value", password)
  html:xpath("//*[@id='submitField']"):attr("value","Continue")
  if html:xpath("//*[@id='loginForm']"):text() == '' then return "EquatePlus plugin error: No login mask found!" end
  html= HTML(connection:request(html:xpath("//*[@id='loginForm']"):submit()))
  -- //*[@id="pagefooter"]/div[1]/div[2]/ul/li[2]/ul/li[2]/select
  -- base url
  baseurl=connection:getBaseURL():match('^(.*/)')
  print("baseurl="..baseurl)
  local boot=JSON(connection:get(baseurl.."services/boot/get")):dictionary()
  if(boot["$type"] and boot["user"])then
    return nil
  end

  return LoginFailed
end



function ListAccounts (knownAccounts)
  local user=JSON(connection:get(baseurl.."services/user/get")):dictionary()

  -- tprint (user)
  -- Return array of accounts.
  reportOnce=true
  local account
  local status,err = pcall( function()
    account = {
      name = "Equateplus "..user["companyId"],
      --owner = user["participant"]["firstName"]["displayValue"].." "..user["participant"]["lastName"]["displayValue"],
      accountNumber = user["participant"]["userId"],
      bankCode = "equatePlus",
      currency = user["reportingCurrency"]["code"],
      portfolio = true,
      type = AccountTypePortfolio
    }
  end)--pcall
  bugReport()
  return {account}
end

function RefreshAccount (account, since)
  local summary=JSON(connection:get(baseurl.."services/planSummary/get")):dictionary()
  local securities = {}
  reportOnce=true
  local status,err = pcall( function()
    for k,v in pairs(summary["entries"]) do
      local details=JSON(connection:post(
        baseurl.."services/planDetails/get",
        "{\"$type\":\"EntityIdentifier\",\"id\":\""..v["id"].."\"}",
        "application/json",{["X-Requested-With"]="XMLHttpRequest",["Accept"]="application/json, text/javascript, */*; q=0.01"})
      ):dictionary()
    local status,err = pcall( function()
        for k,v in pairs(details["entries"]) do
          local status,err = pcall( function()
            for k,v in pairs(v["entries"]) do
              local status,err = pcall( function()
                local marketName=v["marketName"]
                local marketPrice=v["marketPrice"]["amount"]
                for k,v in pairs(v["entries"]) do
                  local status,err = pcall( function()
                    if(v["COST_BASIS"])then
                      -- "date": "2016-02-12T00:00:00.000",
                      local year,month,day=v["ALLOC_DATE"]["date"]:match ( "^(%d%d%d%d)%-(%d%d)%-(%d%d)")
                      --print (year.."-"..month.."-"..day)
                      if(year)then
                        tradeTimestamp=os.time({year=year,month=month,day=day})
                      end
                      local security={
                        -- String name: Bezeichnung des Wertpapiers
                        name=v["VEHICLE_DESCRIPTION"],
          
                        -- String isin: ISIN
                        -- String securityNumber: WKN
                        -- String market: Börse
                        market=marketName,
          
                        -- String currency: Währung bei Nominalbetrag oder nil bei Stückzahl
                        -- Number quantity: Nominalbetrag oder Stückzahl
                        quantity=v["AVAIL_QTY"]["amount"],
          
                        -- Number amount: Wert der Depotposition in Kontowährung
                        -- Number originalCurrencyAmount: Wert der Depotposition in Originalwährung
                        -- Number exchangeRate: Wechselkurs
          
                        -- Number tradeTimestamp: Notierungszeitpunkt; Die Angabe erfolgt in Form eines POSIX-Zeitstempels.
                        tradeTimestamp=tradeTimestamp,
          
                        -- Number price: Aktueller Preis oder Kurs
                        price=marketPrice,
          
                        -- String currencyOfPrice: Von der Kontowährung abweichende Währung des Preises.
                        -- Number purchasePrice: Kaufpreis oder Kaufkurs
                        purchasePrice=v["COST_BASIS"]["amount"],
          
                      -- String currencyOfPurchasePrice: Von der Kontowährung abweichende Währung des Kaufpreises.
          
                      }
                      table.insert(securities,security)
                    end
                  end) --pcall
                  bugReport(status,err,v)
                end
              end)--pcall
              bugReport(status,err,v)
            end
           end) --pcall
           bugReport(status,err,v)
        end
      end) --pcall
      bugReport(status,err,v)
    end
  end) --pcall
  bugReport(status,err,v)
  return {securities=securities}
end

function bugReport(status,err,v)
  if not status and reportOnce then
    reportOnce=false
    print (string.rep('#',25).." 8< please report this bug = '"..err.."' >8 "..string.rep('#',25))
    tprint(v)
    print (string.rep('#',25).." 8< please report this bug version="..Version.." >8 "..string.rep('#',25))
  end
end
 
function EndSession ()
  -- Logout.
  connection:get(baseurl.."services/participant/logout")
end



