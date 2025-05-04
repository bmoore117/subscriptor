use aiken/primitive/string

// algorithms lifted from https://howardhinnant.github.io/date_algorithms.html

type DateTime {
  // -1 if unset, otherwise known time_from_epoch offset
  posix_time: Int,
  year: Int,
  month: Int,
  day_of_month: Int,
}

fn determine_date(p_time: Int) -> DateTime {
  let z = p_time / 86400 + 719468
  let era =
    if z >= 0 {
      z
    } else {
      z - 146096
    } / 146097
  let doe = z - era * 146097
  // [0, 146096]
  let yoe = ( doe - doe / 1460 + doe / 36524 - doe / 146096 ) / 365
  // [0, 399]
  let y = yoe + era * 400
  let doy = doe - ( 365 * yoe + yoe / 4 - yoe / 100 )
  // [0, 365]
  let mp = ( 5 * doy + 2 ) / 153
  // [0, 11]
  let d = doy - ( 153 * mp + 2 ) / 5 + 1
  // [1, 31]
  let m =
    if mp < 10 {
      mp + 3
    } else {
      mp - 9
    }
  // [1, 12]
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

fn determine_first_of_next_month(p_time: Int) -> Int {
  let datetime = determine_date(p_time)
  let last_day = last_day_of_month(datetime.year, datetime.month)
  let remainder = last_day - datetime.day_of_month + 1
  datetime.posix_time + remainder * 86400
}

pub fn determine_first_of_next_month_testing(p_time: Int) -> Int {
  let datetime = determine_date(p_time)
  let last_day = last_day_of_month(datetime.year, datetime.month)
  let remainder = last_day - datetime.day_of_month + 1
  let time = datetime.posix_time + remainder * 86400
  trace time
  p_time + 300000 + time - time
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

test determine_date_0() {
  determine_first_of_next_month(1708185253) == 1709308453
}

test determine_date_1() {
  determine_date(1704067200) == DateTime {
    posix_time: 1704067200,
    year: 2024,
    month: 1,
    day_of_month: 1,
  }
}

test determine_date_2() {
  determine_date(1716508800) == DateTime {
    posix_time: 1716508800,
    year: 2024,
    month: 5,
    day_of_month: 24,
  }
}

test determine_date_3() {
  determine_date(1735084800) == DateTime {
    posix_time: 1735084800,
    year: 2024,
    month: 12,
    day_of_month: 25,
  }
}

test determine_date_3_to_string() {
  // current year is 2024
  to_string(determine_date(1735084800)) == @"2024-12-25"
}

test determine_date_4() {
  determine_date(1747440000) == DateTime {
    posix_time: 1747440000,
    year: 2025,
    month: 5,
    day_of_month: 17,
  }
}

test determine_date_5() {
  determine_date(1756425600) == DateTime {
    posix_time: 1756425600,
    year: 2025,
    month: 8,
    day_of_month: 29,
  }
}

test determine_date_6() {
  determine_date(1788480000) == DateTime {
    posix_time: 1788480000,
    year: 2026,
    month: 9,
    day_of_month: 4,
  }
}
