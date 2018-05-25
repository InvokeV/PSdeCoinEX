Function Get-Price($SiteName){
    Switch ($SiteName)
    {
        "bitFlyer" {$Url = "https://api.bitflyer.jp/v1/getboard?product_code=BTC_JPY"}
        "bitFlyerFX" {$Url = "https://api.bitflyer.jp/v1/getboard?product_code=FX_BTC_JPY"}
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
    }
}

#取引所 (bitFlyer, bitFlyerFX)
    $SiteName = "bitFlyer"
#資産 (jpy, btc)
    $AssetName = "jpy"
#売買 (sell, buy)
    $Side = "buy"
#指値・成行 (limit, market)
    $Type = "limit"
#価格
    $Price = 700000
#注文量 (>0.001)
    $Amount = 0.001

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