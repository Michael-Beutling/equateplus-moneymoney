local url="https://www.equateplus.com"
--local url="http://localhost/test"

local baseurl

WebBanking{version=1.0, url=url,services    = {"EquatePlus"},
  description = "Depot von EquatePlus"}


function SupportsBank (protocol, bankCode)
  return  protocol == ProtocolWebBanking and bankCode == "EquatePlus"  -- .
end

local html

function tprint (tbl, indent)
  if not indent then indent = 3 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    append=type(v)
    if type(v) == 'string' then append="'"..v.."'" end
    if type(v) == 'number' then append=v end
    
    print(formatting .. append)
    if type(v) == 'table' then tprint(v,indent+3) end
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
  local account = {
    name = "Equateplus "..user["companyId"],
    --owner = user["participant"]["firstName"]["displayValue"].." "..user["participant"]["lastName"]["displayValue"],
    accountNumber = user["participant"]["userId"],
    bankCode = "equatePlus",
    currency = user["reportingCurrency"]["code"],
    portfolio = true,
    type = AccountTypePortfolio
  }
  return {account}
end

function RefreshAccount (account, since)
  local summary=JSON(connection:get(baseurl.."services/planSummary/get")):dictionary()
  --tprint(summary)
  --table.remove(summary["entries"]) --
  --tprint(summary["entries"][1])
  local securities = {}

  for k,v in pairs(summary["entries"]) do
    --print ("1. "..v["id"])
    --print("{\"$type\":\"EntityIdentifier\",\"id\":\""..v["id"].."\"}")
    local details=JSON(connection:post(
      baseurl.."services/planDetails/get",
      "{\"$type\":\"EntityIdentifier\",\"id\":\""..v["id"].."\"}",
      "application/json",{["X-Requested-With"]="XMLHttpRequest",["Accept"]="application/json, text/javascript, */*; q=0.01"})
    ):dictionary()

    for k,v in pairs(details["entries"]) do
      --print("2. "..v["name"] .. " "..v["totals"][1]["value"]["amount"])
      --tprint(v["totals"][1]["value"])
      for k,v in pairs(v["entries"]) do
        --print("3. "..v["vehicle"])
        local marketName=v["marketName"]
        local marketPrice=v["marketPrice"]["amount"]
        for k,v in pairs(v["entries"]) do
          print ("4. "..v["VEHICLE_DESCRIPTION"]..' '..string.rep('#',50))
          if(v["COST_BASIS"])then
            tprint(v,3)
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
        end
      end
    end
  end
  return {securities=securities}
end

function EndSession ()
  -- Logout.
  connection:get(baseurl.."services/participant/logout")
end



