Function Get-Price($SiteName){
    Switch ($SiteName)
    {
        "bitFlyer"{$Url = "https://api.bitflyer.jp/v1/getboard?product_code=BTC_JPY"}
        "bitFlyerFX"{$Url = "https://api.bitflyer.jp/v1/getboard?product_code=FX_BTC_JPY"}
        {($_ -eq "Zaif") -Or ($_ -eq "ZaifFX")}{$Url = "https://api.zaif.jp/api/1/depth/btc_jpy"}
    }
    $res = Invoke-RestMethod $Url -Method GET
    Switch ($SiteName)
    {
        {($_ -eq "bitFlyer") -Or ($_ -eq "bitFlyerFX")}{ 
            $AskPrice = $res.asks[0].price
            $BidPrice = $res.bids[0].price
            $AskSize = $res.asks[0].size
            $BidSize = $res.bids[0].size
        }
        {($_ -eq "Zaif") -Or ($_ -eq "ZaifFX")}{
            $AskPrice = $res.asks[0][0]
            $BidPrice = $res.bids[0][0]
            $AskSize = $res.asks[0][1]
            $BidSize = $res.bids[0][1]
        }
    }
    $objPs = New-Object PSCustomObject
    $objPs | Add-Member -NotePropertyMembers @{Name = $SiteName}
    $objPs | Add-Member -NotePropertyMembers @{AskPrice =  $AskPrice}
    $objPs | Add-Member -NotePropertyMembers @{AskSize = $AskSize.ToString("0.00000")}
    $objPs | Add-Member -NotePropertyMembers @{BidPrice = $BidPrice}
    $objPs | Add-Member -NotePropertyMembers @{BidSize = $BidSize.ToString("0.00000")}
    $objPs | FT
}

Function Get-Keys($SiteName){
    Return (Get-Content  (".\Keys.json")  -Encoding UTF8 -Raw | ConvertFrom-Json) | Where Site -eq $SiteName
}

Function Get-Header($SiteName, $Query){
    $Keys = Get-Keys $SiteName
    $APIKey = $Keys.APIKey
    $SecretKey = $Keys.SecretKey 
    Switch ($SiteName)
    {        
        {($_ -eq "bitFlyer") -Or ($_ -eq "bitFlyerFX")}{           
            $Nonce = ([DateTimeOffset](Get-Date)).ToUnixTimeMilliseconds()
            $Query = $Nonce.ToString() + $Query
            $KeyData = [System.Text.Encoding]::UTF8.GetBytes($SecretKey)
            $QueryData = [System.Text.Encoding]::UTF8.GetBytes($Query)
            Add-Type -AssemblyName System.Security
            $HMAC = New-Object System.Security.Cryptography.HMACSHA256
            $HMAC.Key = $KeyData
            $HMACHash = $HMAC.ComputeHash($QueryData)
            $Sign = [System.BitConverter]::ToString($HMACHash).ToLower().Replace("-", "")
            $Header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Header.Add("ACCESS-KEY", "$APIKey")
            $Header.Add("ACCESS-TIMESTAMP", "$Nonce")
            $Header.Add("ACCESS-SIGN", "$Sign")
            Return $Header
        }
        {($_ -eq "Zaif") -Or ($_ -eq "ZaifFX")}{
            Add-Type -AssemblyName System.Net.Http
            $Content = New-Object System.Net.Http.FormUrlEncodedContent($Query)            
            $Query = $Content.ReadAsStringAsync().Result
            $KeyData = [System.Text.Encoding]::UTF8.GetBytes($SecretKey)
            $QueryData = [System.Text.Encoding]::UTF8.GetBytes($Query)
            Add-Type -AssemblyName System.Security
            $HMAC = New-Object System.Security.Cryptography.HMACSHA512
            $HMAC.Key = $KeyData
            $HMACHash = $HMAC.ComputeHash($QueryData)
            $Sign = [System.BitConverter]::ToString($HMACHash).ToLower().Replace("-", "")
            $Header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Header.Add("key", "$APIKey")
            $Header.Add("Sign", "$Sign")
            Return $Header 
        }
    }
}

Function Get-Asset($SiteName, $AssetName){
    Switch ($SiteName){
        "bitFlyer"{
            $Url ="https://api.bitflyer.jp/v1/me/getbalance"
            $Query = "GET/v1/me/getbalance"
            $Header = Get-Header $SiteName $Query
            $res = Invoke-RestMethod $Url -Method GET -Headers $Header
            $Asset =  ($res | Where currency_code -eq "$AssetName").amount
        }
        "bitFlyerFX"{
            $Url ="https://api.bitflyer.jp/v1/me/getcollateral"
            $Query = "GET/v1/me/getcollateral"
            $Header = Get-Header $SiteName $Query
            $res = Invoke-RestMethod $Url -Method GET -Headers $Header            
            If($AssetName -eq "jpy"){$Asset =  $res.collateral}Else{$Asset = 0}
        }
        {($_ -eq "Zaif") -Or ($_ -eq "ZaifFX")}{
            $Url = "https://api.zaif.jp/tapi"
            $Nonce = ([System.DateTime]::UtcNow - (Get-Date("1970, 1, 1"))).TotalSeconds
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("nonce", "$Nonce")
            $Body.Add("method", "get_info")
            $Header = Get-Header $SiteName $Body
            $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body
            $Asset = $res.return.funds.($AssetName)
        }
    }

    If($AssetName -eq "jpy"){
        Return $Asset.ToString("#,0")
    }Else{
        Return $Asset.ToString("#,0.00000000")
    }
    Return $Asset
}

Function Set-Order($SiteName, $Side, $Type, $Price, $Amount){
    Switch ($SiteName)
    {
        "bitFlyer"{
            $Url ="https://api.bitflyer.jp/v1/me/sendchildorder"
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("product_code", "BTC_JPY")
            $Body.Add("side", $Side.ToUpper())
            $Body.Add("child_order_type",  $Type.ToUpper())
            $Body.Add("price",  "$Price")
            $Body.Add("size", "$Amount")
            $Body = ConvertTo-JSON $Body 
            $Query = "POST/v1/me/sendchildorder" + $Body
            $Header = Get-Header $SiteName $Query
            Try{
                $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body -ContentType "application/json"
            }Catch{
                Write-Host "Oder Error! " $_.ErrorDetails.Message -ForegroundColor Red
                Return 0            
            }
            Return $res.child_order_acceptance_id
        }
        "bitFlyerFX"{
            $Url ="https://api.bitflyer.jp/v1/me/sendchildorder"
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("product_code", "FX_BTC_JPY")
            $Body.Add("side", $Side.ToUpper())
            $Body.Add("child_order_type",  $Type.ToUpper())
            $Body.Add("price",  "$Price")
            $Body.Add("size", "$Amount")
            $Body = ConvertTo-JSON $Body 
            $Query = "POST/v1/me/sendchildorder" + $Body
            $Header = Get-Header $SiteName $Query
            Try{
                $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body -ContentType "application/json"
            }Catch{
                Write-Host "Oder Error! " $_.ErrorDetails.Message -ForegroundColor Red
                Return 0            
            }
            Return $res.child_order_acceptance_id
        }
        "Zaif"{
            $Url = "https://api.zaif.jp/tapi"
            $Nonce = ([System.DateTime]::UtcNow - (Get-Date("1970, 1, 1"))).TotalSeconds
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("nonce", "$Nonce")
            $Body.Add("method", "trade")            
            $Body.Add("currency_pair", "btc_jpy")
            If($Side -eq "sell"){$Side = "ask"}ElseIf($Side -eq "buy"){$Side = "bid"}
            $Body.Add("action", "$Side")
            $Body.Add("price", "$Price")
            $Body.Add("amount", "$Amount")
            $Header = Get-Header $SiteName $Body
            Try{      
                $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body
                If($res.success -eq 0){
                    Write-Host "Oder Error! " $res.error -ForegroundColor Red
                    Return 0
                }Else{
                    Return 1
                }
            }Catch{
                Write-Host "Oder Error! " $_.ErrorDetails.Message -ForegroundColor Red
                Return 0
            }
        }
        "ZaifFX"{
            $Url = "https://api.zaif.jp/tlapi"
            $Nonce = ([System.DateTime]::UtcNow - (Get-Date("1970, 1, 1"))).TotalSeconds
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("nonce", "$Nonce")
            $Body.Add("method", "create_position")
            $Body.Add("type", "margin")
            $Body.Add("currency_pair", "btc_jpy")
            If($Side -eq "sell"){$Side = "ask"}ElseIf($Side -eq "buy"){$Side = "bid"}
            $Body.Add("action", "$Side")
            $Body.Add("price", "$Price")
            $Body.Add("amount", "$Amount")
            $Body.Add("leverage", "2")
            $Header = Get-Header $SiteName $Body
            Try{          
                $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body
                If($res.success -eq 0){
                    Write-Host "Oder Error! " $res.error -ForegroundColor Red
                    Return 0
                 }Else{
                    Return $res.return.leverage_id
                }
            }Catch{
                Write-Host "Oder Error! " $_.ErrorDetails.Message -ForegroundColor Red
                Return 0
            }
        }
    }    
}

Function Get-Order($SiteName){
    Switch ($SiteName)
    {        
        "bitFlyer"{
            $Url ="https://api.bitflyer.jp/v1/me/getchildorders?product_code=BTC_JPY&child_order_state=ACTIVE"
            $Query = "GET/v1/me/getchildorders?product_code=BTC_JPY&child_order_state=ACTIVE"
            $Header = Get-Header $SiteName $Query
            $res = Invoke-RestMethod $Url -Method GET -Headers $Header
        }
        "bitFlyerFX"{
            $Url ="https://api.bitflyer.jp/v1/me/getchildorders?product_code=FX_BTC_JPY&child_order_state=ACTIVE"
            $Query = "GET/v1/me/getchildorders?product_code=FX_BTC_JPY&child_order_state=ACTIVE"
            $Header = Get-Header $SiteName $Query
            $res = Invoke-RestMethod $Url -Method GET -Headers $Header
        }
         "Zaif"{
            $Url = "https://api.zaif.jp/tapi"
            $Nonce = ([System.DateTime]::UtcNow - (Get-Date("1970, 1, 1"))).TotalSeconds
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("nonce", "$Nonce")
            $Body.Add("method", "active_orders")  
            $Header = Get-Header $SiteName $Body    
            $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body
        }
        "ZaifFX"{
            $Url = "https://api.zaif.jp/tlapi"
            $Nonce = ([System.DateTime]::UtcNow - (Get-Date("1970, 1, 1"))).TotalSeconds
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("nonce", "$Nonce")
            $Body.Add("method", "active_positions")
            $Body.Add("type", "margin")
            $Header = Get-Header $SiteName $Body
            $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body
        }
    }
    Return $res
}

Function Cancel-Order($SiteName, $OrderID){
    Switch ($SiteName)
    {
        "bitFlyer"{     
            $Url ="https://api.bitflyer.jp/v1/me/cancelchildorder"
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("product_code", "BTC_JPY")
            $Body.Add("child_order_acceptance_id", "$OrderID")
            $Body = ConvertTo-JSON $Body 
            $Query = "POST/v1/me/cancelchildorder" + $Body
            $Header = Get-Header $SiteName $Query
            $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body -ContentType "application/json"
         }
        "bitFlyerFX"{     
            $Url ="https://api.bitflyer.jp/v1/me/cancelchildorder"
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("product_code", "FX_BTC_JPY")
            $Body.Add("child_order_acceptance_id", "$OrderID")
            $Body = ConvertTo-JSON $Body 
            $Query = "POST/v1/me/cancelchildorder" + $Body
            $Header = Get-Header $SiteName $Query
            $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body -ContentType "application/json"
         }
        "Zaif"{
            $Url = "https://api.zaif.jp/tapi"
            $Nonce = ([System.DateTime]::UtcNow - (Get-Date("1970, 1, 1"))).TotalSeconds
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("nonce", "$Nonce")
            $Body.Add("method", "cancel_order")            
            $Body.Add("order_id", "$OrderID")
            $Header = Get-Header $SiteName $Body       
            $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body 
        }
        "ZaifFX"{
            $Url = "https://api.zaif.jp/tlapi"
            $Nonce = ([System.DateTime]::UtcNow - (Get-Date("1970, 1, 1"))).TotalSeconds
            $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $Body.Add("nonce", "$Nonce")
            $Body.Add("method", "cancel_position")
            $Body.Add("leverage_id", "$OrderID")
            $Header = Get-Header $SiteName $Body
            $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body
        }
    }
    Return $res
}

Function Close-FX($SiteName, $CloseOrderID, $BtcPrice){
    Switch ($SiteName)
    {
        "bitFlyerFX"{
            #反対売買を行うことでポジションをクローズ
        }
        "ZaifFX"{
            $Url = "https://api.zaif.jp/tlapi"
            $res = Get-Order $SiteName
            ForEach($item In $res.return | Get-Member | ? MemberType -eq NoteProperty){
                $OrderID =$item.Name
                If($CloseOrderID -eq $OrderID){
                    $Price = $res.return.$OrderID.price
                    $Amount = $res.return.$OrderID.amount
                    $Nonce = ([System.DateTime]::UtcNow - (Get-Date("1970, 1, 1"))).TotalSeconds
                    $Body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                    $Body.Add("nonce", "$Nonce")
                    $Body.Add("method", "change_position")
                    $Body.Add("type", "margin")
                    $Body.Add("leverage_id", "$OrderID")
                    If($Price -ge $BtcPrice){$Body.Add("limit", "$BtcPrice")}Else{$Body.Add("stop", "$BtcPrice")}    
                    $Header = Get-Header Zaif $Body
                    $res = Invoke-RestMethod $Url -Method POST -Headers $Header -Body $Body
                }
            }
        }
    }
    Return $res
}

#取引所 (bitFlyer, bitFlyerFX, Zaif, ZaifFX)
    $SiteName = "Zaif"
#資産 (jpy, btc)
    $AssetName = "jpy"
#売買 (sell, buy)
    $Side = "buy"
#指値・成行 (limit, market)
    $Type = "limit"
#価格
    $Price = 700000
#注文量 (bitFlyer>0.001, Zaif>0.0001)
    $Amount = 0.001
#ビットコイン価格
    $BtcPrice = 700000

#価格情報
    #Get-Price $SiteName
#資産情報
    #Get-Asset $SiteName $AssetName
#売買注文
    #$OrderID = Set-Order $SiteName $Side $Type $Price $Amount
#注文情報
    #Get-Order $SiteName
#注文取消し
    #Cancel-Order $SiteName $OrderID
#FXポジションクローズ
    #Close-FX $SiteName $OrderID $BtcPrice