#property strict
#property version   "1.15"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property description "ICT KillZone with New York DST and Tehran-time session legend."

#ifndef SESSION_BOXES_NEW_YORK_TIME_MQH
#define SESSION_BOXES_NEW_YORK_TIME_MQH

// Modern US daylight-saving rules (2007 onward). Values are expressed as UTC
// timestamps or timezone-free New York wall-clock timestamps, as named below.
datetime SessionShiftTime(const datetime value, const long seconds)
{
   // Do signed arithmetic before explicitly converting back to MT5 datetime.
   return((datetime)((long)value + seconds));
}

datetime NewYorkMarchSunday(const int year)
{
   MqlDateTime date = {0};
   date.year = year;
   date.mon = 3;
   date.day = 1;
   const datetime first = StructToTime(date);
   TimeToStruct(first, date);
   return(SessionShiftTime(first, (long)((7 - date.day_of_week) % 7 + 7) * 86400));
}

datetime NewYorkNovemberSunday(const int year)
{
   MqlDateTime date = {0};
   date.year = year;
   date.mon = 11;
   date.day = 1;
   const datetime first = StructToTime(date);
   TimeToStruct(first, date);
   return(SessionShiftTime(first, (long)((7 - date.day_of_week) % 7) * 86400));
}

bool NewYorkOffsetAtUTC(const datetime utcTime, int &offsetMinutes)
{
   MqlDateTime date;
   if(!TimeToStruct(utcTime, date) || date.year < 2007)
      return(false);

   // Clocks advance at 02:00 EST (07:00 UTC) and fall back at 02:00 EDT
   // (06:00 UTC). London/European clock changes do not govern ICT windows.
   const datetime daylightStart = SessionShiftTime(NewYorkMarchSunday(date.year), 7 * 3600);
   const datetime daylightEnd = SessionShiftTime(NewYorkNovemberSunday(date.year), 6 * 3600);
   offsetMinutes = (utcTime >= daylightStart && utcTime < daylightEnd) ? -240 : -300;
   return(true);
}

bool NewYorkWallTimeToUTC(const datetime newYorkWallTime, datetime &utcTime)
{
   MqlDateTime date;
   if(!TimeToStruct(newYorkWallTime, date) || date.year < 2007)
      return(false);

   const datetime springDay = NewYorkMarchSunday(date.year);
   // 02:00-02:59 on the spring transition does not exist. No session starting
   // or ending in that gap is drawn (the default windows fall on a Sunday).
   if(newYorkWallTime >= SessionShiftTime(springDay, 2 * 3600) &&
      newYorkWallTime < SessionShiftTime(springDay, 3 * 3600))
      return(false);

   const datetime daylightStart = SessionShiftTime(springDay, 3 * 3600);
   const datetime daylightEnd = SessionShiftTime(NewYorkNovemberSunday(date.year), 2 * 3600);
   // For a custom time in the repeated autumn 01:00 hour, choose its first
   // occurrence (EDT). None of the default session endpoints is ambiguous.
   const int offsetMinutes = (newYorkWallTime >= daylightStart &&
                              newYorkWallTime < daylightEnd) ? -240 : -300;
   utcTime = SessionShiftTime(newYorkWallTime, -(long)offsetMinutes * 60);
   return(true);
}

#endif

// ICT forex windows are defined in New York local time, including US DST.
// The legend uses fixed Tehran UTC+3:30. Broker chart time is separate.
input group "London (New York time; Tehran winter 10:30-13:30)"
input int   London_StartHour = 2;
input int   London_StartMinute = 0;
input int   London_EndHour   = 5;
input int   London_EndMinute = 0;
input color London_Color     = clrMediumSeaGreen;
input bool  ShowLondon       = true;

input group "New York AM (New York time; Tehran winter 15:30-18:30)"
input int   NewYorkAM_StartHour = 7;
input int   NewYorkAM_StartMinute = 0;
input int   NewYorkAM_EndHour   = 10;
input int   NewYorkAM_EndMinute = 0;
input color NewYorkAM_Color     = clrDarkRed;
input bool  ShowNewYorkAM       = true;

input group "New York PM (New York time; Tehran winter 22:00-00:30)"
input int   NewYorkPM_StartHour = 13;
input int   NewYorkPM_StartMinute = 30;
input int   NewYorkPM_EndHour   = 16;
input int   NewYorkPM_EndMinute = 0;
input color NewYorkPM_Color     = clrDarkOrange;
input bool  ShowNewYorkPM       = true;

input group "Display and broker time"
input int DaysToShow             = 15; // New York calendar days, including today
input int FillOpacityPercent     = 15; // 0 = invisible fill; 100 = solid fill
input int LocalUTCOffsetMinutes  = 210; // Tooltip clock; Tehran is UTC+3:30
input int BrokerUTCOffsetMinutes = 120; // Broker chart clock; UTC+2 assumed

string g_prefix = "";
bool g_boxesVisible = true;
int g_panelY = 20;
const int TEHRAN_UTC_OFFSET_MINUTES = 210;

void UpdateToggleButton()
{
   const string name = g_prefix + "Toggle";
   ObjectSetString(0, name, OBJPROP_TEXT,
                   g_boxesVisible ? "Hide ICT KillZone" : "Show ICT KillZone");
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, g_boxesVisible ? clrDarkGreen : clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

bool CreateToggleButton(const int yDistance)
{
   const string name = g_prefix + "Toggle";
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
   {
      Print("SessionBoxes: could not create toggle button; error ", GetLastError());
      return(false);
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 180);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 24);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1000);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "Show or hide this indicator's session boxes");
   UpdateToggleButton();
   ChartRedraw(0);
   return(true);
}

bool SetLegendRow(const string key, const string label, const color sessionColor,
                  const bool enabled, const int row)
{
   const string swatch = g_prefix + "Legend_" + key + "_Swatch";
   const string text = g_prefix + "Legend_" + key + "_Text";
   const int y = g_panelY + 34 + row * 20;
   if(ObjectFind(0, swatch) < 0 &&
      !ObjectCreate(0, swatch, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      return(false);
   if(ObjectFind(0, text) < 0 &&
      !ObjectCreate(0, text, OBJ_LABEL, 0, 0, 0))
      return(false);

   ObjectSetInteger(0, swatch, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, swatch, OBJPROP_XDISTANCE, 12);
   ObjectSetInteger(0, swatch, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, swatch, OBJPROP_XSIZE, 12);
   ObjectSetInteger(0, swatch, OBJPROP_YSIZE, 12);
   ObjectSetInteger(0, swatch, OBJPROP_BGCOLOR, sessionColor);
   ObjectSetInteger(0, swatch, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, swatch, OBJPROP_COLOR, sessionColor);
   ObjectSetInteger(0, swatch, OBJPROP_BACK, false);
   ObjectSetInteger(0, swatch, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, swatch, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, swatch, OBJPROP_TIMEFRAMES,
                    g_boxesVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);

   ObjectSetInteger(0, text, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, text, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, text, OBJPROP_XDISTANCE, 32);
   ObjectSetInteger(0, text, OBJPROP_YDISTANCE, y - 2);
   ObjectSetInteger(0, text, OBJPROP_COLOR, ChartGetInteger(0, CHART_COLOR_FOREGROUND));
   ObjectSetInteger(0, text, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, text, OBJPROP_BACK, false);
   ObjectSetInteger(0, text, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, text, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, text, OBJPROP_TIMEFRAMES,
                    g_boxesVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
   ObjectSetString(0, text, OBJPROP_TEXT, label + (enabled ? "" : " (off)"));
   return(true);
}

bool NewYorkDayForLegend(datetime &dayStart)
{
   // Use the live UTC clock so the legend updates through weekends and while
   // boxes are hidden. In the tester, follow the simulated broker timestamp.
   datetime utcNow = TimeGMT();
   if(MQLInfoInteger(MQL_TESTER) != 0)
      utcNow = SessionShiftTime(TimeCurrent(), -(long)BrokerUTCOffsetMinutes * 60);
   int newYorkOffset;
   if(utcNow <= 0 || !NewYorkOffsetAtUTC(utcNow, newYorkOffset))
      return(false);
   MqlDateTime date;
   if(!TimeToStruct(SessionShiftTime(utcNow, newYorkOffset * 60), date))
      return(false);
   date.hour = 0;
   date.min = 0;
   date.sec = 0;
   dayStart = StructToTime(date);
   return(true);
}

string TehranLegendText(const string label, const datetime newYorkDay,
                        const int startHour, const int startMinute,
                        const int endHour, const int endMinute)
{
   const int startMinutes = startHour * 60 + startMinute;
   const int endMinutes = endHour * 60 + endMinute;
   datetime utcStart, utcEnd;
   const datetime wallStart = SessionShiftTime(newYorkDay, startMinutes * 60);
   datetime wallEnd = SessionShiftTime(newYorkDay, endMinutes * 60);
   if(endMinutes < startMinutes)
      wallEnd = SessionShiftTime(wallEnd, 86400);
   if(!NewYorkWallTimeToUTC(wallStart, utcStart) ||
      !NewYorkWallTimeToUTC(wallEnd, utcEnd) || utcEnd <= utcStart)
      return(label + " --:-----:-- in Tehran Times");

   const datetime localStart = SessionShiftTime(utcStart, TEHRAN_UTC_OFFSET_MINUTES * 60);
   const datetime localEnd = SessionShiftTime(utcEnd, TEHRAN_UTC_OFFSET_MINUTES * 60);
   const datetime startDate = StringToTime(TimeToString(localStart, TIME_DATE));
   const datetime endDate = StringToTime(TimeToString(localEnd, TIME_DATE));
   const int extraDays = (int)(((long)endDate - (long)startDate) / 86400);
   string rollover = "";
   if(extraDays > 0)
      rollover = StringFormat(" (+%d day%s)", extraDays, extraDays == 1 ? "" : "s");
   return(label + " " + TimeToString(localStart, TIME_MINUTES) + "-" +
          TimeToString(localEnd, TIME_MINUTES) + rollover + " in Tehran Times");
}

bool UpdateLegend()
{
   if(g_prefix == "")
      return(false);
   datetime dayStart = 0;
   NewYorkDayForLegend(dayStart);
   return(SetLegendRow("London", TehranLegendText("LONDON", dayStart,
                          London_StartHour, London_StartMinute,
                          London_EndHour, London_EndMinute), London_Color, ShowLondon, 0) &&
          SetLegendRow("NewYorkAM", TehranLegendText("NEW YORK AM", dayStart,
                          NewYorkAM_StartHour, NewYorkAM_StartMinute,
                          NewYorkAM_EndHour, NewYorkAM_EndMinute), NewYorkAM_Color, ShowNewYorkAM, 1) &&
          SetLegendRow("NewYorkPM", TehranLegendText("NEW YORK PM", dayStart,
                          NewYorkPM_StartHour, NewYorkPM_StartMinute,
                          NewYorkPM_EndHour, NewYorkPM_EndMinute), NewYorkPM_Color, ShowNewYorkPM, 2));
}

void SetBoxesVisible(const bool visible)
{
   if(g_prefix == "")
      return;
   g_boxesVisible = visible;
   for(int i = ObjectsTotal(0, 0, OBJ_RECTANGLE) - 1; i >= 0; --i)
   {
      const string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(name, g_prefix) == 0)
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES,
                          visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
   }
   UpdateLegend(); // Apply the same visibility to every legend swatch and label.
   UpdateToggleButton();
   ChartRedraw(0);
}

bool ValidHours(const int startHour, const int startMinute,
                const int endHour, const int endMinute)
{
   return(startHour >= 0 && startHour <= 23 &&
          endHour >= 0 && endHour <= 23 &&
          startMinute >= 0 && startMinute <= 59 &&
          endMinute >= 0 && endMinute <= 59 &&
          startHour * 60 + startMinute != endHour * 60 + endMinute);
}

string UTCOffsetLabel(const int offsetMinutes)
{
   const int absoluteMinutes = (int)MathAbs(offsetMinutes);
   return(StringFormat("UTC%s%02d:%02d", offsetMinutes < 0 ? "-" : "+",
                       absoluteMinutes / 60, absoluteMinutes % 60));
}

// OBJ_RECTANGLE does not provide alpha transparency. Blend its fill with the
// chart background. The native one-pixel edge uses this same subtle fill color;
// no separate contrasting frame is drawn.
color FillColor(const color sessionColor)
{
   const long background = ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   const double opacity = FillOpacityPercent / 100.0;
   const long foreground = (long)sessionColor;
   const int red = (int)MathRound((foreground & 255) * opacity +
                                  (background & 255) * (1.0 - opacity));
   const int green = (int)MathRound(((foreground >> 8) & 255) * opacity +
                                    ((background >> 8) & 255) * (1.0 - opacity));
   const int blue = (int)MathRound(((foreground >> 16) & 255) * opacity +
                                   ((background >> 16) & 255) * (1.0 - opacity));
   return((color)(red | (green << 8) | (blue << 16)));
}

bool SetRectangle(const string name, const datetime startTime,
                  const datetime endTime, const double highest,
                  const double lowest, const color boxColor)
{
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                       startTime, highest, endTime, lowest))
      {
         Print("SessionBoxes: could not create ", name, "; error ", GetLastError());
         return(false);
      }
   }
   else
   {
      if(!ObjectMove(0, name, 0, startTime, highest) ||
         !ObjectMove(0, name, 1, endTime, lowest))
         return(false);
   }

   ObjectSetInteger(0, name, OBJPROP_COLOR, boxColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES,
                    g_boxesVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
   return(true);
}

void DrawSessionBox(const datetime newYorkDayStart, const int startHour,
                    const int startMinute, const int endHour,
                    const int endMinute, const color sessionColor,
                    const string sessionName, const datetime serverNow)
{
   if(FillOpacityPercent == 0)
      return;
   const int startMinutes = startHour * 60 + startMinute;
   const int endMinutes = endHour * 60 + endMinute;
   const datetime startWallTime = SessionShiftTime(newYorkDayStart, startMinutes * 60);
   datetime endWallTime = SessionShiftTime(newYorkDayStart, endMinutes * 60);
   if(endMinutes < startMinutes)
      endWallTime = SessionShiftTime(endWallTime, 86400);

   // Convert each endpoint separately so overnight sessions can cross a DST
   // boundary. MT5 object anchors and M1 history always use broker chart time.
   datetime utcStart, utcEnd;
   if(!NewYorkWallTimeToUTC(startWallTime, utcStart) ||
      !NewYorkWallTimeToUTC(endWallTime, utcEnd) || utcEnd <= utcStart)
      return;
   const datetime startTime = SessionShiftTime(utcStart, BrokerUTCOffsetMinutes * 60);
   const datetime endTime = SessionShiftTime(utcEnd, BrokerUTCOffsetMinutes * 60);
   if(startTime > serverNow)
      return;

   // Use M1 bars regardless of chart timeframe. The end time is exclusive:
   // the candle opening exactly at the session end belongs to the next period.
   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_M1, startTime, SessionShiftTime(endTime, -1), rates);
   if(copied <= 0)
      return; // History may still be downloading; the timer will retry.

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int i = 0; i < copied; ++i)
   {
      if(rates[i].time < startTime || rates[i].time >= endTime)
         continue;
      highest = MathMax(highest, rates[i].high);
      lowest = MathMin(lowest, rates[i].low);
   }
   if(highest == -DBL_MAX || lowest == DBL_MAX)
      return;

   const string name = g_prefix + sessionName + "_" +
                       TimeToString(newYorkDayStart, TIME_DATE);
   SetRectangle(name + "_Fill", startTime, endTime, highest, lowest,
                FillColor(sessionColor));

   const string tooltip = sessionName + " | " + UTCOffsetLabel(LocalUTCOffsetMinutes) +
      "\n" + TimeToString(SessionShiftTime(utcStart, LocalUTCOffsetMinutes * 60), TIME_DATE | TIME_MINUTES) +
      " - " + TimeToString(SessionShiftTime(utcEnd, LocalUTCOffsetMinutes * 60), TIME_DATE | TIME_MINUTES) +
      "\nHigh: " + DoubleToString(highest, _Digits) +
      "  Low: " + DoubleToString(lowest, _Digits);
   ObjectSetString(0, name + "_Fill", OBJPROP_TOOLTIP, tooltip);
}

void RemoveExpiredBoxes(const datetime oldestServerDay)
{
   for(int i = ObjectsTotal(0, 0, OBJ_RECTANGLE) - 1; i >= 0; --i)
   {
      const string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(name, g_prefix) != 0)
         continue;
      const datetime startTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
      if(startTime < oldestServerDay)
         ObjectDelete(0, name);
   }
}

void RefreshBoxes()
{
   if(g_prefix == "" || !g_boxesVisible)
      return;
   const datetime serverNow = TimeCurrent();
   if(serverNow <= 0)
      return;

   const datetime utcNow = SessionShiftTime(serverNow, -(long)BrokerUTCOffsetMinutes * 60);
   int newYorkOffset;
   if(!NewYorkOffsetAtUTC(utcNow, newYorkOffset))
      return;
   MqlDateTime newYorkDate;
   if(!TimeToStruct(SessionShiftTime(utcNow, newYorkOffset * 60), newYorkDate))
      return;
   newYorkDate.hour = 0;
   newYorkDate.min = 0;
   newYorkDate.sec = 0;
   const datetime todayNewYork = StructToTime(newYorkDate);
   const datetime oldestNewYork = SessionShiftTime(todayNewYork, -(long)(DaysToShow - 1) * 86400);
   datetime oldestUTC;
   if(NewYorkWallTimeToUTC(oldestNewYork, oldestUTC))
      RemoveExpiredBoxes(SessionShiftTime(oldestUTC, BrokerUTCOffsetMinutes * 60));

   for(int day = 0; day < DaysToShow; ++day)
   {
      const datetime newYorkDayStart = SessionShiftTime(todayNewYork, -(long)day * 86400);
      if(ShowLondon)
         DrawSessionBox(newYorkDayStart, London_StartHour, London_StartMinute,
                        London_EndHour, London_EndMinute,
                        London_Color, "London", serverNow);
      if(ShowNewYorkAM)
         DrawSessionBox(newYorkDayStart, NewYorkAM_StartHour, NewYorkAM_StartMinute,
                        NewYorkAM_EndHour, NewYorkAM_EndMinute,
                        NewYorkAM_Color, "NewYorkAM", serverNow);
      if(ShowNewYorkPM)
         DrawSessionBox(newYorkDayStart, NewYorkPM_StartHour, NewYorkPM_StartMinute,
                        NewYorkPM_EndHour, NewYorkPM_EndMinute,
                        NewYorkPM_Color, "NewYorkPM", serverNow);
   }
   ChartRedraw(0);
}

int OnInit()
{
   if(DaysToShow < 1 ||
      FillOpacityPercent < 0 || FillOpacityPercent > 100 ||
      LocalUTCOffsetMinutes < -14 * 60 || LocalUTCOffsetMinutes > 14 * 60 ||
      BrokerUTCOffsetMinutes < -14 * 60 || BrokerUTCOffsetMinutes > 14 * 60 ||
      !ValidHours(London_StartHour, London_StartMinute, London_EndHour, London_EndMinute) ||
      !ValidHours(NewYorkAM_StartHour, NewYorkAM_StartMinute, NewYorkAM_EndHour, NewYorkAM_EndMinute) ||
      !ValidHours(NewYorkPM_StartHour, NewYorkPM_StartMinute, NewYorkPM_EndHour, NewYorkPM_EndMinute))
   {
      Print("SessionBoxes: invalid inputs. Check session hours, days, fill and UTC offset.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   // Reserve an invisible marker so multiple copies on a chart have independent
   // object names, even before any session history has become available.
   int instance = 1;
   string prefix;
   do
   {
      prefix = "SessionBoxes_" + IntegerToString(instance++) + "_";
   }
   while(ObjectFind(0, prefix + "Owner") >= 0);
   if(!ObjectCreate(0, prefix + "Owner", OBJ_LABEL, 0, 0, 0))
      return(INIT_FAILED);
   g_prefix = prefix;
   ObjectSetString(0, g_prefix + "Owner", OBJPROP_TEXT, "");
   ObjectSetInteger(0, g_prefix + "Owner", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, g_prefix + "Owner", OBJPROP_SELECTABLE, false);

   g_boxesVisible = true;
   g_panelY = 20 + (instance - 2) * 100;
   if(!CreateToggleButton(g_panelY) || !UpdateLegend())
   {
      Print("SessionBoxes: could not create control panel; error ", GetLastError());
      ObjectsDeleteAll(0, g_prefix);
      g_prefix = "";
      return(INIT_FAILED);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "ICT Session Boxes (" +
                      UTCOffsetLabel(LocalUTCOffsetMinutes) + ")");
   if(!EventSetTimer(5))
   {
      ObjectsDeleteAll(0, g_prefix);
      g_prefix = "";
      return(INIT_FAILED);
   }
   RefreshBoxes();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_prefix != "")
      ObjectsDeleteAll(0, g_prefix);
   ChartRedraw(0);
}

void OnTimer()
{
   UpdateLegend(); // Refresh Tehran times even while session shading is hidden.
   RefreshBoxes();
   ChartRedraw(0);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == g_prefix + "Toggle")
   {
      SetBoxesVisible(!g_boxesVisible);
      if(g_boxesVisible)
         RefreshBoxes();
   }
   else if(id == CHARTEVENT_CHART_CHANGE)
   {
      UpdateLegend(); // Keep legend text readable even while zones are hidden.
      RefreshBoxes(); // Reblend the fill if the chart background changes.
      ChartRedraw(0);
   }
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   RefreshBoxes();
   return(rates_total);
}

// End of SessionBoxes v1.15 - complete indicator source.
