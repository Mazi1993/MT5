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
