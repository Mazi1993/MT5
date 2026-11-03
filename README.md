# ICT KillZone for MetaTrader 5

[SessionBoxes.mq5](SessionBoxes.mq5) is a complete, standalone MT5 indicator.
It draws lightly shaded London, New York AM and New York PM killzones using each
session's highest high and lowest low. Tokyo is excluded. Version: **1.15**.

## Install

1. Download `SessionBoxes.mq5` from this repository using GitHub's **Download raw
   file** action.
2. In MetaTrader 5, choose **File → Open Data Folder** and copy the file into
   `MQL5/Indicators`.
3. Open `SessionBoxes.mq5` in MetaEditor and press **F7** to compile.
4. In MT5, refresh **Navigator → Indicators** and attach **SessionBoxes** to a
   chart. Compilation alone does not attach the indicator.

No separate `.mqh` file is required. If replacing an older version, replace the
whole file and recompile. The source ends with:

```cpp
// End of SessionBoxes v1.15 - complete indicator source.
```

## Chart controls

- **Hide ICT KillZone** hides both the zones and their legend.
- **Show ICT KillZone** restores both, with current legend times.
- The button remains visible. It affects only this indicator's objects.
- The color legend shows each configured session's range **in Tehran Times**
  (fixed UTC+3:30). An end after midnight is marked `(+1 day)`.
- Zones have a subtle fill without a separate solid outline. The native
  rectangle edge uses the same blended color as the interior.

Visibility resets to shown when the indicator reinitializes, including after
changing timeframe or inputs. Removing the indicator removes its own objects.

## Session times

Inputs use **New York local time**. Modern US daylight-saving rules (2007 onward)
are applied separately to each historical date. The defaults follow common ICT
forex London and New York AM windows, plus the New York afternoon window.

| Session | New York inputs | Tehran during NY winter | Tehran during NY summer |
| --- | --- | --- | --- |
| London | 02:00–05:00 | 10:30–13:30 | 09:30–12:30 |
| New York AM | 07:00–10:00 | 15:30–18:30 | 14:30–17:30 |
| New York PM | 13:30–16:00 | 22:00–00:30 (+1 day) | 21:00–23:30 |

The legend shows today's New York schedule and updates automatically. Inputs
allow custom hours and minutes, including overnight windows. Index-futures AM
models may use 08:30–11:00 New York time; adjust the AM inputs if desired.

## Important settings

- `BrokerUTCOffsetMinutes` defaults to **120**, assuming the broker's chart clock
  is UTC+2. Set it to the actual broker offset; your personal timezone does not
  determine the broker clock. This places the zones on the chart.
- The broker offset is fixed for all displayed dates. If the broker changes its
  offset, update the setting; inspect dates on either side of that change with
  the appropriate offset. New York DST is handled separately and automatically.
- `LocalUTCOffsetMinutes` defaults to **210** for box tooltips. The legend always
  uses Tehran UTC+3:30. These settings do not change MT5's chart time axis.
- `DaysToShow` defaults to **15 New York calendar days**, including today.
- `FillOpacityPercent` defaults to **15**. Zero disables zone shading.
- Individual session visibility and colors are configurable.

## Price data and verification

The indicator uses the symbol's **M1 history**, independent of chart timeframe.
The candle opening exactly at a session's end is excluded. Active sessions
update as prices arrive, while their right edge shows the scheduled end.
History requests are retried every five seconds; allow time for MT5 to load it.

Timezone logic passed eight regression tests against independent timezone data,
including New York DST boundaries and Tehran midnight rollover. Native MT5
compilation and chart rendering were not verified in the development workspace.

After compiling, compare a completed zone with its M1 candles and check the
show/hide button, legend and cleanup. If nothing is visible, confirm attachment
with **Ctrl+I**, use a recent **H1** view, and inspect **Toolbox → Experts** for
runtime messages.
