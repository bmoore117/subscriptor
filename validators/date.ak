use aiken/primitive/string

// algorithms lifted from https://howardhinnant.github.io/date_algorithms.html

const millis_per_day = 86400000

pub type BillingSchedule {
  EveryNMilliseconds(Int)
  Daily
  Weekly
  BiWeekly
  Monthly
}

type DateTime {
  posix_time: Int,
  year: Int,
  month: Int,
  day_of_month: Int,
}

fn determine_date(p_time: Int) -> DateTime {
  let z = p_time / millis_per_day + 719468
  let era =
    if z >= 0 {
      z
    } else {
      z - 146096
    } / 146097
  let doe = z - era * 146097
  let yoe = ( doe - doe / 1460 + doe / 36524 - doe / 146096 ) / 365
  let y = yoe + era * 400
  let doy = doe - ( 365 * yoe + yoe / 4 - yoe / 100 )
  let mp = ( 5 * doy + 2 ) / 153
  let d = doy - ( 153 * mp + 2 ) / 5 + 1
  let m =
    if mp < 10 {
      mp + 3
    } else {
      mp - 9
    }
  let final_y =
    if m <= 2 {
      y + 1
    } else {
      y
    }
  DateTime { posix_time: p_time, year: final_y, month: m, day_of_month: d }
}

fn last_day_of_month_common_year(month: Int) -> Int {
  if month == 1 {
    31
  } else if month == 2 {
    28
  } else if month == 3 {
    31
  } else if month == 4 {
    30
  } else if month == 5 {
    31
  } else if month == 6 {
    30
  } else if month == 7 {
    31
  } else if month == 8 {
    31
  } else if month == 9 {
    30
  } else if month == 10 {
    31
  } else if month == 11 {
    30
  } else {
    31
  }
}

fn is_leap(y: Int) -> Bool {
  y % 4 == 0 && ( y % 100 != 0 || y % 400 == 0 )
}

fn last_day_of_month(y: Int, m: Int) -> Int {
  if m != 2 || !is_leap(y) {
    last_day_of_month_common_year(m)
  } else {
    29
  }
}

pub fn start_of_day(p_time: Int) -> Int {
  p_time / millis_per_day * millis_per_day
}

pub fn determine_first_of_next_month(p_time: Int) -> Int {
  let datetime = determine_date(p_time)
  let last_day = last_day_of_month(datetime.year, datetime.month)
  let remainder = last_day - datetime.day_of_month + 1
  start_of_day(datetime.posix_time) + remainder * millis_per_day
}

pub fn next_billing_date(
  lock_until: Int,
  schedule: BillingSchedule,
) -> Int {
  when schedule is {
    EveryNMilliseconds(n) -> lock_until + n
    Daily -> start_of_day(lock_until) + millis_per_day
    Weekly -> start_of_day(lock_until) + 7 * millis_per_day
    BiWeekly -> start_of_day(lock_until) + 14 * millis_per_day
    Monthly -> determine_first_of_next_month(lock_until)
  }
}

fn to_string(date: DateTime) {
  string.concat(
    string.concat(
      string.concat(
        string.concat(string.from_int(date.year), @"-"),
        format_month(date.month),
      ),
      @"-",
    ),
    format_day(date.day_of_month),
  )
}

fn format_month(month: Int) -> String {
  if month < 10 {
    string.concat(@"0", string.from_int(month))
  } else {
    string.from_int(month)
  }
}

fn format_day(day_of_month: Int) -> String {
  if day_of_month < 10 {
    string.concat(@"0", string.from_int(day_of_month))
  } else {
    string.from_int(day_of_month)
  }
}

// -- Tests (all inputs/outputs in milliseconds) --

test determine_first_of_next_month_feb_leap() {
  // Feb 17, 2024 09:14:13 UTC → Mar 1, 2024 00:00:00 UTC
  determine_first_of_next_month(1708185253000) == 1709251200000
}

test determine_date_jan_1_2024() {
  determine_date(1704067200000) == DateTime {
    posix_time: 1704067200000,
    year: 2024,
    month: 1,
    day_of_month: 1,
  }
}

test determine_date_may_24_2024() {
  determine_date(1716508800000) == DateTime {
    posix_time: 1716508800000,
    year: 2024,
    month: 5,
    day_of_month: 24,
  }
}

test determine_date_dec_25_2024() {
  determine_date(1735084800000) == DateTime {
    posix_time: 1735084800000,
    year: 2024,
    month: 12,
    day_of_month: 25,
  }
}

test determine_date_dec_25_to_string() {
  to_string(determine_date(1735084800000)) == @"2024-12-25"
}

test determine_date_may_17_2025() {
  determine_date(1747440000000) == DateTime {
    posix_time: 1747440000000,
    year: 2025,
    month: 5,
    day_of_month: 17,
  }
}

test determine_date_aug_29_2025() {
  determine_date(1756425600000) == DateTime {
    posix_time: 1756425600000,
    year: 2025,
    month: 8,
    day_of_month: 29,
  }
}

test determine_date_sep_4_2026() {
  determine_date(1788480000000) == DateTime {
    posix_time: 1788480000000,
    year: 2026,
    month: 9,
    day_of_month: 4,
  }
}

test start_of_day_strips_time() {
  // Jan 1, 2024 09:06:40 UTC → Jan 1, 2024 00:00:00 UTC
  start_of_day(1704100000000) == 1704067200000
}

test start_of_day_at_midnight_is_identity() {
  start_of_day(1704067200000) == 1704067200000
}

test next_billing_every_n_millis() {
  next_billing_date(1704067200000, EveryNMilliseconds(300000)) == 1704067500000
}

test next_billing_daily() {
  // Jan 1, 2024 09:06:40 UTC → Jan 2, 2024 00:00:00 UTC
  next_billing_date(1704100000000, Daily) == 1704153600000
}

test next_billing_weekly() {
  // Jan 1, 2024 00:00:00 UTC → Jan 8, 2024 00:00:00 UTC
  next_billing_date(1704067200000, Weekly) == 1704672000000
}

test next_billing_biweekly() {
  // Jan 1, 2024 00:00:00 UTC → Jan 15, 2024 00:00:00 UTC
  next_billing_date(1704067200000, BiWeekly) == 1705276800000
}

test next_billing_monthly() {
  // Feb 17, 2024 09:14:13 UTC → Mar 1, 2024 00:00:00 UTC
  next_billing_date(1708185253000, Monthly) == 1709251200000
}

test next_billing_monthly_dec_to_jan() {
  // Dec 25, 2024 00:00:00 UTC → Jan 1, 2025 00:00:00 UTC
  next_billing_date(1735084800000, Monthly) == 1735689600000
}
