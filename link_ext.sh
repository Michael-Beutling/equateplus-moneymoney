#!/bin/sh
ls -li ~/Library/Containers/com.moneymoney-app.retail/Data/Library/Application\ Support/MoneyMoney/Extensions/EquatePlus.lua EquatePlus.lua

rm ~/Library/Containers/com.moneymoney-app.retail/Data/Library/Application\ Support/MoneyMoney/Extensions/EquatePlus.lua 
ln EquatePlus.lua ~/Library/Containers/com.moneymoney-app.retail/Data/Library/Application\ Support/MoneyMoney/Extensions/EquatePlus.lua 

ls -li ~/Library/Containers/com.moneymoney-app.retail/Data/Library/Application\ Support/MoneyMoney/Extensions/EquatePlus.lua EquatePlus.lua

