// Portability adapter for exercising the production MQL time helper on Linux.
// This supplies only MT5's calendar primitives; the DST logic is included below.
#include <ctime>
#include <iostream>

using datetime = long long;

struct MqlDateTime
{
    int year, mon, day, hour, min, sec, day_of_week, day_of_year;
};

datetime StructToTime(const MqlDateTime &date)
{
    std::tm utc{};
    utc.tm_year = date.year - 1900;
    utc.tm_mon = date.mon - 1;
    utc.tm_mday = date.day;
    utc.tm_hour = date.hour;
    utc.tm_min = date.min;
    utc.tm_sec = date.sec;
    return static_cast<datetime>(timegm(&utc));
}

bool TimeToStruct(const datetime timestamp, MqlDateTime &date)
{
    const std::time_t value = static_cast<std::time_t>(timestamp);
    std::tm utc{};
    if (gmtime_r(&value, &utc) == nullptr)
        return false;
    date = {utc.tm_year + 1900, utc.tm_mon + 1, utc.tm_mday,
            utc.tm_hour, utc.tm_min, utc.tm_sec, utc.tm_wday, utc.tm_yday};
    return true;
}

#include "../Indicators/NewYorkTime.mqh"

int main()
{
    char operation;
    datetime timestamp;
    while (std::cin >> operation >> timestamp)
    {
        if (operation == 'O')
        {
            int offset = 0;
            const bool valid = NewYorkOffsetAtUTC(timestamp, offset);
            std::cout << valid << ' ' << offset << '\n';
        }
        else if (operation == 'W')
        {
            datetime utc = 0;
            const bool valid = NewYorkWallTimeToUTC(timestamp, utc);
            std::cout << valid << ' ' << utc << '\n';
        }
        else
            return 2;
    }
    return std::cin.eof() ? 0 : 3;
}
