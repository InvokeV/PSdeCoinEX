Function Get-Prices(){
    $Sites = @()

    $objPs = New-Object PSCustomObject
    $objPs | Add-Member -NotePropertyMembers @{Name = "BTCBOX"}
    $objPs | Add-Member -NotePropertyMembers @{TickerUrl = "https://www.btcbox.co.jp/api/v1/depth/"}
    $Sites += $objPs

    $objPs = New-Object PSCustomObject
    $objPs | Add-Member -NotePropertyMembers @{Name = "bitbank"}
    $objPs | Add-Member -NotePropertyMembers @{TickerUrl = "https://public.bitbank.cc/btc_jpy/depth"}
    $Sites += $objPs

    $objPs = New-Object PSCustomObject
    $objPs | Add-Member -NotePropertyMembers @{Name = "bitFlyer"}
    $objPs | Add-Member -NotePropertyMembers @{TickerUrl = "https://api.bitflyer.jp/v1/ticker"}
    $Sites += $objPs

    $objPs = New-Object PSCustomObject
    $objPs | Add-Member -NotePropertyMembers @{Name = "FISCO"}
    $objPs | Add-Member -NotePropertyMembers @{TickerUrl = "https://api.fcce.jp/api/1/depth/btc_jpy"}
    $Sites += $objPs

    $objPs = New-Object PSCustomObject
    $objPs | Add-Member -NotePropertyMembers @{Name = "QUOINE"}
    $objPs | Add-Member -NotePropertyMembers @{TickerUrl = "https://api.quoine.com/products/5/price_levels"}
    $Sites += $objPs

    $objPs = New-Object PSCustomObject
    $objPs | Add-Member -NotePropertyMembers @{Name = "Zaif"}
    $objPs | Add-Member -NotePropertyMembers @{TickerUrl = "https://api.zaif.jp/api/1/depth/btc_jpy"}
    $Sites += $objPs


    $Prices = @()

    ForEach($Site In $Sites){

        $SiteName = $Site.Name

        $res = Invoke-RestMethod $Site.TickerUrl -Method GET

        [int]$AskPrice = 0
        [int]$BidPrice = 0
        [double]$AskSize = 0
        [double]$BidSize = 0

        Switch ($SiteName)
        {
            "BTCBOX" {
                $AskPrice = $res.asks[$res.asks.Count-1][0]
                $BidPrice = $res.bids[0][0]
                $AskSize = $res.asks[$res.asks.Count-1][1]
                $BidSize = $res.bids[0][1]
            }
            "bitbank" {
                $AskPrice = $res.data.asks[0][0]
                $BidPrice = $res.data.bids[0][0]
                $AskSize = $res.data.asks[0][1]
                $BidSize = $res.data.bids[0][1]
            }
            "bitFlyer" {
                $AskPrice = $res.best_ask
                $BidPrice = $res.best_bid
                $AskSize = $res.best_ask_size
                $BidSize = $res.best_bid_size
            }
            "FISCO" {
                $AskPrice = $res.asks[0][0]
                $BidPrice = $res.bids[0][0]
                $AskSize = $res.asks[0][1]
                $BidSize = $res.bids[0][1]
            }
            "QUOINE" {
                $AskPrice = $res.sell_price_levels[0][0]
                $BidPrice = $res.buy_price_levels[0][0]
                $AskSize = $res.sell_price_levels[0][1]
                $BidSize = $res.buy_price_levels[0][1]
            }
            "Zaif" {                
                $AskPrice = $res.asks[0][0]
                $BidPrice = $res.bids[0][0]
                $AskSize = $res.asks[0][1]
                $BidSize = $res.bids[0][1]
            }
        }

        $objPs = New-Object PSCustomObject
        $objPs | Add-Member -NotePropertyMembers @{Name = $Site.Name}
        $objPs | Add-Member -NotePropertyMembers @{AskPrice =  $AskPrice}
        $objPs | Add-Member -NotePropertyMembers @{AskSize = $AskSize.ToString("0.00000")}
        $objPs | Add-Member -NotePropertyMembers @{BidPrice = $BidPrice}
        $objPs | Add-Member -NotePropertyMembers @{BidSize = $BidSize.ToString("0.00000")}
        $Prices += $objPs
    }　

    $Prices | FT   
}


Get-Prices
