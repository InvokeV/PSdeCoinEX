# PSdeCoinEX

PowerShellで仮想通貨のシステムトレードにチャレンジ！  


## .NET Framework で TLS1.1 および 1.2 を有効化する：
* Invoke-WebRequestコマンドでTLS 1.2を利用できるようにするため、以下のコマンドを実行しておく必要があります。


　　Set-ItemProperty -Path HKLM:\\SOFTWARE\Microsoft\.NETFramework\v4.0.30319 -Name SchUseStrongCrypto -Value 1


## サンプルの紹介：
* Sample_01.ps1　取引所別のBit/Ask値一覧
* Sample_02.ps1　bitFlyer bitFlyerFX


## API対応取引所：
* BTCBOX (https://www.btcbox.co.jp/)

　　APIリファレンス（https://www.btcbox.co.jp/help/asm）

　　手数料（https://www.btcbox.co.jp/trade/us）

* bitbank (https://bitbank.cc/)

　　APIリファレンス（https://docs.bitbank.cc/）

　　手数料（https://bitbank.cc/docs/fees/）

* bitFlyer （https://bitflyer.jp/）

　　APIリファレンス（https://lightning.bitflyer.jp/docs?lang=ja）

　　手数料（https://bitflyer.jp/ja-jp/commission#bitcoin-fees）

* QUOINEX (https://ja.quoinex.com/）

　　APIリファレンス（https://developers.quoine.com/）

　　手数料（https://fcce.jp/doc#Commission）

* Zaif (https://zaif.jp/)

　　APIリファレンス（https://corp.zaif.jp/api-docs/）

　　手数料（https://zaif.jp/fee）


