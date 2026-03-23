# Configuration

All input parameters for `Horizon.mq5` and asset-level configuration files.

## General Settings

| Parameter          | Type                      | Default             | Description                                                                    |
| ------------------ | ------------------------- | ------------------- | ------------------------------------------------------------------------------ |
| `TickIntervalTime` | `int`                     | `60`                | Tick interval in seconds. Controls how often `OnTick` fires for each strategy. |
| `FillingMode`      | `ENUM_ORDER_TYPE_FILLING` | `ORDER_FILLING_IOC` | Order filling mode sent to the broker.                                         |
| `DebugLevel`       | `ENUM_DEBUG_LEVEL`        | `DEBUG_LEVEL_ALL`   | Controls log verbosity and persistence.                                        |

### Debug levels

| Value                        | Description                               |
| ---------------------------- | ----------------------------------------- |
| `DEBUG_LEVEL_NONE`           | No logs                                   |
| `DEBUG_LEVEL_ERRORS`         | Errors and warnings only                  |
| `DEBUG_LEVEL_ERRORS_PERSIST` | Errors and warnings with file persistence |
| `DEBUG_LEVEL_ALL`            | All logs                                  |
| `DEBUG_LEVEL_ALL_PERSIST`    | All logs with file persistence            |

## Reporting

These inputs control CSV report generation during strategy tester runs.

| Parameter                     | Type   | Default | Description                                    |
| ----------------------------- | ------ | ------- | ---------------------------------------------- |
| `EnableOrderHistoryReport`    | `bool` | `false` | Export order history to CSV on tester.         |
| `EnableSnapshotHistoryReport` | `bool` | `false` | Export strategy snapshots to CSV on tester.    |
| `EnableMarketHistoryReport`   | `bool` | `false` | Export market data snapshots to CSV on tester. |

## Risk Management

| Parameter                | Type     | Default | Description                                                                 |
| ------------------------ | -------- | ------- | --------------------------------------------------------------------------- |
| `EquityAtRiskCompounded` | `bool`   | `false` | When true, risk is calculated on current equity instead of initial balance. |
| `EquityAtRisk`           | `double` | `1`     | Maximum equity at risk per trade, as a percentage.                          |

## Horizon Monitor

Connection to the Horizon Monitor API for remote logging, account sync, and dashboard reporting.

| Parameter                  | Type     | Default | Description                                                              |
| -------------------------- | -------- | ------- | ------------------------------------------------------------------------ |
| `EnableHorizonIntegration` | `bool`   | `true`  | Master toggle for all Horizon integrations. Only active in live trading. |
| `HorizonMonitorUrl`        | `string` | `""`    | Base URL for the Horizon Monitor API.                                    |
| `HorizonMonitorEmail`      | `string` | `""`    | Authentication email for Horizon Monitor.                                |
| `HorizonMonitorPassword`   | `string` | `""`    | Authentication password for Horizon Monitor.                             |

## Horizon Gateway

Connection to the Horizon Gateway API for remote order management and account status.

| Parameter                | Type     | Default | Description                                  |
| ------------------------ | -------- | ------- | -------------------------------------------- |
| `HorizonGatewayUrl`      | `string` | `""`    | Base URL for the Horizon Gateway API.        |
| `HorizonGatewayEmail`    | `string` | `""`    | Authentication email for Horizon Gateway.    |
| `HorizonGatewayPassword` | `string` | `""`    | Authentication password for Horizon Gateway. |

## Asset-level Strategy Toggles

Each asset file defines boolean inputs to enable or disable individual strategies. The naming pattern is `<Asset><Strategy>Enabled`. All default to `false`.

### Gold (XAUUSD)

Defined in `assets/Commodities/Gold.mqh`.

| Parameter               | Strategy   |
| ----------------------- | ---------- |
| `GoldBallaratEnabled`   | Ballarat   |
| `GoldBendigoEnabled`    | Bendigo    |
| `GoldCairnsEnabled`     | Cairns     |
| `GoldDarwinEnabled`     | Darwin     |
| `GoldGeelongEnabled`    | Geelong    |
| `GoldHobartEnabled`     | Hobart     |
| `GoldMackayEnabled`     | Mackay     |
| `GoldTamworthEnabled`   | Tamworth   |
| `GoldToowoombaEnabled`  | Toowoomba  |
| `GoldWollongongEnabled` | Wollongong |
| `GoldTestEnabled`       | Test       |

### Nikkei225

Defined in `assets/Indices/Nikkei225.mqh`.

| Parameter                  | Strategy |
| -------------------------- | -------- |
| `Nikkei225SapporoEnabled`  | Sapporo  |
| `Nikkei225NaraEnabled`     | Nara     |
| `Nikkei225KobeEnabled`     | Kobe     |
| `Nikkei225NagoyaEnabled`   | Nagoya   |
| `Nikkei225OsakaEnabled`    | Osaka    |
| `Nikkei225KyotoEnabled`    | Kyoto    |
| `Nikkei225NikkoEnabled`    | Nikko    |
| `Nikkei225NiigataEnabled`  | Niigata  |
| `Nikkei225FukuokaEnabled`  | Fukuoka  |
| `Nikkei225YokohamaEnabled` | Yokohama |
| `Nikkei225TestEnabled`     | Test     |

### SP500

Defined in `assets/Indices/SP500.mqh`.

| Parameter               | Strategy  |
| ----------------------- | --------- |
| `SP500DenverEnabled`    | Denver    |
| `SP500RaleighEnabled`   | Raleigh   |
| `SP500PortlandEnabled`  | Portland  |
| `SP500AustinEnabled`    | Austin    |
| `SP500PhoenixEnabled`   | Phoenix   |
| `SP500TucsonEnabled`    | Tucson    |
| `SP500MemphisEnabled`   | Memphis   |
| `SP500NashvilleEnabled` | Nashville |
| `SP500CharlotteEnabled` | Charlotte |
| `SP500TampaEnabled`     | Tampa     |
| `SP500TestEnabled`      | Test      |
