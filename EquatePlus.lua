local url="https://www.equateplus.com"
--local url="http://localhost/test"

local baseurl=""
local reportOnce
local Version="1.17"
local CSRF_TOKEN=nil
local csrfpId=nil
local connection
local debugging=false
local anonymous
local anonymousCount
local cummulate=false
local html
local debugfile

function connectWithCSRF(method, url, postContent, postContentType, headers)
  url=baseurl..url
  -- print("baseurl="..baseurl)
  postContentType=postContentType or "application/json"
  local content

  if headers == nil then
    headers={["X-Requested-With"]="XMLHttpRequest" }
  end

  if CSRF_TOKEN ~= nil then
    headers['CSRF_TOKEN']=CSRF_TOKEN
  else
    print("without CSRF_TOKEN")
  end
  if method == 'POST' then
    -- lprint(postContent)
    if csrfpId ~= nil then
      postContent=postContent.."&csrfpId="..csrfpId
    end
  end

  content, charset, mimeType, filename, headers = connection:request(method, url, postContent, postContentType, headers)
  csrfpIdTemp=string.match(content,"\"csrfpId\" *, *\"([^\"]+)\"")
  if csrfpIdTemp ~= '' then
    csrfpId=csrfpIdTemp
  end
  if debugging then
  -- tprint(headers)
  -- lprint(content)
  else
  --print "no debug"
  end
  if headers["CSRF_TOKEN"] then
    CSRF_TOKEN=headers["CSRF_TOKEN"]
    -- print("new CSRF_TOKEN="..CSRF_TOKEN)
    -- if debugging then print("new CSRF_TOKEN") end
  end
  return content
end

WebBanking{version=Version, url=url,services    = {"EquatePlus","EquatePlus (cumulative)","EquatePlus (Debug, don't use!)"},
  description = "Depot von EquatePlus"}


function SupportsBank (protocol, bankCode)
  return  protocol == ProtocolWebBanking and ("EquatePlus" == bankCode:sub(1,#"EquatePlus")) 
end

function lprint(text)
  repeat
    print("  ",string.sub(text,1,60))
    text=string.sub(text,61)
  until text == ''
end

function twritetext(text)
  if debugging then
    i=40-string.len(text)
    if i<0 then i=0 end
    debugfile:write("\n")
    debugfile:write(string.rep("#",i).." "..text.." "..string.rep("#",i), "\n")
    debugfile:write("\n")
  end 
end

function makeAnonymous(v,prefix)
  if anonymous[tostring(v)] ~= nil then
    return anonymous[tostring(v)]
  end
  anonymousCount=anonymousCount+1
  if prefix == nil then
    prefix="_V"
  end 
  s=prefix..tostring(anonymousCount)
  anonymous[tostring(v)]=s
  -- debugfile:write("'",v,"' = ",s,"\n")
  return s
end

function writeSecrets()
  if debug then
    secretFile=io.open("debug_EquatePlus_secrets.txt","w")
    for k,v in pairs(anonymous) do
      if k ~= v then 
        secretFile:write("'",k,"' = ",v,"\n")
      end
    end
    secretFile:close()
    anonymous=nil
  end 
end


-- whitelist node names 
function twritedebugNodes (tbl)
    for k, v in pairs(tbl) do
      anonymous[k]=k
      if type(v) == 'table'  then 
        twritedebugNodes(v)
      end
    end
end

function twritedebugWorker (tbl, prefix)
    for k, v in pairs(tbl) do
      formatting = prefix .."." .. k .. ": "
      if (type(v) == 'string') then
        -- debugfile:write(formatting, type(v), "='", v, "'", "\n")
        if k ~= "id" then
          debugfile:write(formatting, type(v), "='", makeAnonymous(v), "'", "\n")
        else
          debugfile:write(formatting, type(v), "='", makeAnonymous(v,"_I"), "'", "\n")
        end
      elseif type(v) == 'table'  then 
        twritedebugWorker(v,prefix.."."..k)
      elseif type(v) == 'boolean'  then
        debugfile:write(formatting,type(v),"=",tostring(v), "\n")
      elseif type(v) == 'number'  then
        -- debugfile:write(formatting,type(v).."="..v, "\n")
        debugfile:write(formatting,type(v),"=",makeAnonymous(v), "\n")
      else
        debugfile:write(formatting,type(v), "\n")
      end
    end
end

function twritedebug (tbl, prefix)
  if debugging then
    if not prefix then prefix = "" end
    twritedebugNodes(tbl,prefix)
    -- remove numbers
    for v,k in ipairs(anonymous) do
      anonymous[k]=nil
    end
    --for v,k in pairs(anonymous) do
      --debugfile:write("'",k,"' = ",v,"\n")
    --end
    
    twritedebugWorker(tbl,prefix)
  end 
end

function tprint (tbl, indent)
  if debugging then
    if not indent then indent = 0 end
    formatting = string.rep(" ", indent) 
    for k, v in pairs(tbl) do
      print(formatting .. k .. ": " .. type(v))
      if type(v) == 'table' and indent < 15 then 
        tprint(v,indent+3) 
      end
    end
  end 
end

function InitializeSession2 (protocol, bankCode, step, credentials, interactive)

  if step==1 then
    -- Login.
    baseurl=""
    debugging=false
    cummulate=false
    CSRF_TOKEN=nil
    csrfpId=nil
    connection = Connection()
    anonymous={}
    anonymousCount=0
    
    username=credentials[1]
    password=credentials[2]
      
    if string.match(bankCode,"cumulative") then
      cummulate=true
    end
    
    if string.match(bankCode,"Debug") then
      debugging=true
      debugfile=io.open("debug_EquatePlus.txt","w")
      twritetext("Start")
    end


    -- get login page
    html = HTML(connectWithCSRF("GET",url))
    if html:xpath("//*[@id='loginForm']"):text() == '' then return "EquatePlus plugin error: No login mask found!" end

    -- first login stage
    -- print("login first stage")
    html:xpath("//*[@id='eqUserId']"):attr("value", username)
    html:xpath("//*[@id='submitField']"):attr("value","Continue Login")
    html= HTML(connectWithCSRF(html:xpath("//*[@id='loginForm']"):submit()))
    if html:xpath("//*[@id='loginForm']"):text() == '' then return "EquatePlus plugin error: No login mask found!" end

    -- second login stage
    -- print("login second stage")
    html:xpath("//*[@id='eqUserId']"):attr("value", username)
    html:xpath("//*[@id='eqPwdId']"):attr("value", password)
    html:xpath("//*[@id='submitField']"):attr("value","Continue")
    
    content, charset, mimeType, filename, headers = connectWithCSRF(html:xpath("//*[@id='loginForm']"):submit())
    html= HTML(content)
    
    -- 2.FA cuiMessages
    if html:xpath("//*[@class='cuiMessageConfirmBorder']"):text() ~= "" then
      print(html:xpath("//*[@class='cuiMessageConfirmBorder']"):text()) 
      return {
        title='Two-factor authentication',
        challenge=html:xpath("//*[@class='cuiMessageConfirmBorder']"):text(),
        label='Code'
      } 
    else
      -- base url
      baseurl=connection:getBaseURL():match('^(.*/)')
      print("baseurl="..baseurl)
      -- no code = success
      return nil
    end

  else
    -- enter code
    html:xpath("//*[@id='otpCodeId']"):attr("value", credentials[1])
    html:xpath("//*[@id='submitField']"):attr("value","verify")
    content, charset, mimeType, filename, headers = connectWithCSRF(html:xpath("//*[@id='loginForm']"):submit())

    -- base url
    baseurl=connection:getBaseURL():match('^(.*/)')
    print("baseurl="..baseurl)

    if CSRF_TOKEN ~= nil  then
      return nil
    else
      return "Wrong 2FA code!"
    end
    
  end    
  
  return LoginFailed  
end

function ListAccounts (knownAccounts)
  local user=JSON(connectWithCSRF("GET","services/user/get")):dictionary()
  twritetext("List accounts")
  twritedebug(user,"ListAccounts:")
  -- Return array of accounts.
  reportOnce=true
  postfix=""
  if debug then postfix=" Debug" end
  local account
  local status,err = pcall( function()
    account = {
      name = "Equateplus "..user["companyId"]..postfix,
      --owner = user["participant"]["firstName"]["displayValue"].." "..user["participant"]["lastName"]["displayValue"],
      accountNumber = user["participant"]["userId"],
      bankCode = "equatePlus",
      currency = user["reportingCurrency"]["code"],
      portfolio = true,
      type = AccountTypePortfolio
    }
  end)--pcall
  bugReport(status,err,user,1)
  return {account}
end

function RefreshAccount (account, since)
  local summary=JSON(connectWithCSRF("GET","services/planSummary/get")):dictionary()
  twritetext("Summary")
  twritedebug (summary,"Summary:")
  local securities = {}
  reportOnce=true
  local status,err = pcall( function()
    for k,v in pairs(summary["entries"]) do
      local details=JSON(connectWithCSRF("POST","services/planDetails/get","{\"$type\":\"EntityIdentifier\",\"id\":\""..v["id"].."\"}")):dictionary()
      twritetext("Details:"..makeAnonymous(v["id"]))
      twritedebug (details,"Details "..makeAnonymous(v["id"])..":")
      local status,err = pcall( function()
        for k,v in pairs(details["entries"]) do
          -- Required for Allianz Employee Shares
          local contribType = {}
          local status,err = pcall( function()
            for k,v in pairs(v["entries"]) do
              local status,err = pcall( function()
                local marketName=v["marketName"]
                local marketPrice=0
                if v["marketPrice"] ~= nil then
                  marketPrice=v["marketPrice"]["amount"]
                end
                for k,v in pairs(v["entries"]) do
                  local status,err = pcall( function()
                    if(v["ELECTION_CONTRIBUTION_TYPE"])then
                      contribType[k]=v["ELECTION_CONTRIBUTION_TYPE"]
                      --twritetext("ELECTION_CONTRIBUTION_TYPE exists")
                    end
                    if(v["COST_BASIS"])then
                    
                      -- "date": "2016-02-12T00:00:00.000",
                      local year,month,day=v["ALLOC_DATE"]["date"]:match ( "^(%d%d%d%d)%-(%d%d)%-(%d%d)")
                      --print (year.."-"..month.."-"..day)
                      if(year)then
                        tradeTimestamp=os.time({year=year,month=month,day=day})
                      end
                      
                      local qty=0
                      if v["AVAIL_QTY"] and v["AVAIL_QTY"]["amount"] then
                        qty=v["AVAIL_QTY"]["amount"]
                      end
                      if v["LOCKED_QTY"] and v["LOCKED_QTY"]["amount"] then
                        qty=qty+v["LOCKED_QTY"]["amount"]
                      end
           
                      local secName=""
                      if v["VEHICLE_DESCRIPTION"] ~= nil then
                        secName=v["VEHICLE_DESCRIPTION"]
                      elseif v["PLAN_DESCRIPTION"] ~= nil then
                        secName=v["PLAN_DESCRIPTION"] --..": "..v["ELECTION_CONTRIBUTION_TYPE"]
                      end
                        
                      if contribType[k] ~= nil then
                        secName=secName.." ("..contribType[k]..")"
                      end
           
                      local security={
                        -- String name: Bezeichnung des Wertpapiers
                        name=secName,

                        -- String isin: ISIN
                        -- String securityNumber: WKN
                        -- String market: Börse
                        market=marketName,

                        -- String currency: Währung bei Nominalbetrag oder nil bei Stückzahl
                        -- Number quantity: Nominalbetrag oder Stückzahl
                        quantity=qty,

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
                      if cummulate then
                        name='_'..v["VEHICLE_DESCRIPTION"]
                        if securities[name] == nil then
                          security['sumPrice']=security['purchasePrice']*qty
                          securities[name]=security
                          table.insert(securities,security)
                        else
                          securities[name]['sumPrice']=securities[name]['sumPrice']+security['purchasePrice']*qty
                          securities[name]['quantity']=securities[name]['quantity']+qty
                          securities[name]['purchasePrice']=securities[name]['sumPrice']/securities[name]['quantity']
                        end
                      else
                        table.insert(securities,security)
                      end
                    end
                  end) --pcall
                  bugReport(status,err,v,2)
                end
              end)--pcall
              bugReport(status,err,v,3)
            end
          end) --pcall
          bugReport(status,err,v,4)
        end
      end) --pcall
      bugReport(status,err,v,5)
    end
  end) --pcall
  bugReport(status,err,v,6)
  twritetext("Results")
  twritedebug(securities,"Result:")
  if debugging then
    debugfile:close()
    writeSecrets()
  end  
  return {securities=securities}
end

function bugReport(status,err,v,identifier)
  if not status and reportOnce then
    reportOnce=false
    print (string.rep('#',25).." 8< please report this bug = '"..err.."' >8 "..string.rep('#',25))
    tprint(v)
    print (string.rep('#',25).." 8< please report this bug version="..Version.." identifier="..identifier.." >8 "..string.rep('#',25))
  end
end

function EndSession ()
  -- Logout.
  connectWithCSRF("GET","services/participant/logout")
end



