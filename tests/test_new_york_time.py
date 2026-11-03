"""Check the actual MQL DST helper against Python's independent IANA timezone.

Run: python3 -m unittest discover -s tests -v
Requires g++ and Python's America/New_York zoneinfo data. The C++ adapter supplies
MT5 calendar primitives; these checks do not compile or run the MT5 indicator.
"""

import datetime as dt
from pathlib import Path
import subprocess
import tempfile
import unittest
from zoneinfo import ZoneInfo


UTC = dt.timezone.utc
NEW_YORK = ZoneInfo("America/New_York")
UTC_PLUS_TWO = dt.timezone(dt.timedelta(hours=2))
SESSION_ENDPOINTS = ((2, 0), (5, 0), (7, 0), (10, 0), (13, 30), (16, 0))


def wall_stamp(value):
    """Encode a wall-clock datetime as MT5's timezone-free date/time value."""
    return int(value.replace(tzinfo=UTC).timestamp())


class NewYorkTimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="mt5-ny-time-tests-")
        cls.addClassCleanup(cls.build.cleanup)
        cls.adapter = Path(cls.build.name) / "ny_time_adapter"
        source = Path(__file__).with_name("ny_time_adapter.cpp")
        subprocess.run(
            ["g++", "-std=c++17", "-O2", "-Wall", "-Wextra",
             "-Wno-missing-field-initializers", str(source), "-o", str(cls.adapter)],
            check=True,
            capture_output=True,
            text=True,
        )

    def query(self, commands):
        result = subprocess.run(
            [str(self.adapter)],
            input="".join(f"{operation} {timestamp}\n" for operation, timestamp in commands),
            text=True,
            capture_output=True,
            check=True,
        )
        rows = [tuple(map(int, line.split())) for line in result.stdout.splitlines()]
        self.assertEqual(len(rows), len(commands), "Every requested case must execute")
        return rows

    def test_offset_every_day_2007_through_2035(self):
        day = dt.datetime(2007, 1, 1, 12, tzinfo=UTC)
        cases = []
        while day.year < 2036:
            cases.append(day)
            day += dt.timedelta(days=1)
        actual = self.query([("O", int(value.timestamp())) for value in cases])
        for value, row in zip(cases, actual):
            expected = int(value.astimezone(NEW_YORK).utcoffset().total_seconds() / 60)
            self.assertEqual(row, (1, expected), value.isoformat())

    def test_utc_transition_seconds(self):
        transitions = (
            dt.datetime(2024, 3, 10, 7, tzinfo=UTC),
            dt.datetime(2024, 11, 3, 6, tzinfo=UTC),
            dt.datetime(2026, 3, 8, 7, tzinfo=UTC),
            dt.datetime(2026, 11, 1, 6, tzinfo=UTC),
        )
        cases = [transition + dt.timedelta(seconds=delta)
                 for transition in transitions
                 for delta in (-3601, -1, 0, 1, 3599, 3600)]
        actual = self.query([("O", int(value.timestamp())) for value in cases])
        for value, row in zip(cases, actual):
            expected = int(value.astimezone(NEW_YORK).utcoffset().total_seconds() / 60)
            self.assertEqual(row, (1, expected), value.isoformat())

    def test_session_endpoints_every_weekday_2024_and_2026(self):
        cases = []
        for year in (2024, 2026):
            day = dt.datetime(year, 1, 1)
            while day.year == year:
                if day.weekday() < 5:
                    cases.extend(day.replace(hour=hour, minute=minute)
                                 for hour, minute in SESSION_ENDPOINTS)
                day += dt.timedelta(days=1)
        actual = self.query([("W", wall_stamp(value)) for value in cases])
        for value, row in zip(cases, actual):
            expected = int(value.replace(tzinfo=NEW_YORK).timestamp())
            self.assertEqual(row, (1, expected), value.isoformat())

    def test_utc_plus_two_session_hours(self):
        for day, expected in (
            (dt.datetime(2026, 11, 2), ("09:00", "12:00", "14:00", "17:00", "20:30", "23:00")),
            (dt.datetime(2026, 7, 1), ("08:00", "11:00", "13:00", "16:00", "19:30", "22:00")),
        ):
            cases = [day.replace(hour=hour, minute=minute) for hour, minute in SESSION_ENDPOINTS]
            rows = self.query([("W", wall_stamp(value)) for value in cases])
            self.assertTrue(all(valid for valid, _ in rows))
            actual = tuple(dt.datetime.fromtimestamp(timestamp, UTC_PLUS_TWO).strftime("%H:%M")
                           for _, timestamp in rows)
            self.assertEqual(actual, expected, day.date().isoformat())

    def test_tehran_session_hours_and_midnight_rollover(self):
        tehran_zone = ZoneInfo("Asia/Tehran")
        fixed_tehran = dt.timezone(dt.timedelta(minutes=210))
        for day, expected in (
            (dt.datetime(2026, 11, 2), (
                "2026-11-02 10:30", "2026-11-02 13:30",
                "2026-11-02 15:30", "2026-11-02 18:30",
                "2026-11-02 22:00", "2026-11-03 00:30",
            )),
            (dt.datetime(2026, 7, 1), (
                "2026-07-01 09:30", "2026-07-01 12:30",
                "2026-07-01 14:30", "2026-07-01 17:30",
                "2026-07-01 21:00", "2026-07-01 23:30",
            )),
        ):
            cases = [day.replace(hour=hour, minute=minute)
                     for hour, minute in SESSION_ENDPOINTS]
            rows = self.query([("W", wall_stamp(value)) for value in cases])
            for wall_time, (valid, timestamp), expected_local in zip(cases, rows, expected):
                with self.subTest(new_york=wall_time.isoformat()):
                    self.assertEqual(valid, 1)
                    actual = dt.datetime.fromtimestamp(timestamp, fixed_tehran)
                    independent = wall_time.replace(tzinfo=NEW_YORK).astimezone(tehran_zone)
                    self.assertEqual(actual.utcoffset(), dt.timedelta(minutes=210))
                    self.assertEqual(independent.utcoffset(), dt.timedelta(minutes=210))
                    self.assertEqual(actual.strftime("%Y-%m-%d %H:%M"), expected_local)
                    self.assertEqual(actual.isoformat(), independent.isoformat())

    def test_spring_gap_is_rejected_and_neighbors_convert(self):
        for year, month, day in ((2024, 3, 10), (2026, 3, 8)):
            gap = [dt.datetime(year, month, day, 2, 0),
                   dt.datetime(year, month, day, 2, 30),
                   dt.datetime(year, month, day, 2, 59, 59)]
            self.assertEqual(self.query([("W", wall_stamp(value)) for value in gap]),
                             [(0, 0)] * len(gap))
            valid = [dt.datetime(year, month, day, 1, 59, 59),
                     dt.datetime(year, month, day, 3, 0)]
            actual = self.query([("W", wall_stamp(value)) for value in valid])
            expected = [(1, int(value.replace(tzinfo=NEW_YORK).timestamp())) for value in valid]
            self.assertEqual(actual, expected)

    def test_autumn_repeated_hour_uses_first_occurrence(self):
        cases = [dt.datetime(year, 11, day, hour, minute, second)
                 for year, day in ((2024, 3), (2026, 1))
                 for hour, minute, second in ((1, 0, 0), (1, 30, 0), (1, 59, 59), (2, 0, 0))]
        actual = self.query([("W", wall_stamp(value)) for value in cases])
        expected = [(1, int(value.replace(tzinfo=NEW_YORK, fold=0).timestamp())) for value in cases]
        self.assertEqual(actual, expected)

    def test_pre_2007_is_explicitly_unsupported(self):
        cases = [dt.datetime(1999, 6, 1), dt.datetime(2006, 12, 31, 23, 59, 59)]
        commands = [(operation, wall_stamp(value))
                    for value in cases for operation in ("O", "W")]
        self.assertEqual(self.query(commands), [(0, 0)] * len(commands))


if __name__ == "__main__":
    unittest.main()
