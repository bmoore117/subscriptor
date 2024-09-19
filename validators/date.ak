use aiken/primitive/string

type DateTime {
  // -1 if unset, otherwise known time_from_epoch offset
  posix_time: Int,
  year: Int,
  month: Int,
  day_of_month: Int,
}

fn determine_date(p_time: Int) -> DateTime {
  // 1704067200 == 2024-01-01, the idea being that we can save recursive 
  // loops by just checking if we are talking about any recent time
  let year =
    if p_time >= 1704067200 {
      2024
    } else {
      1970
    }

  let posix_time_adjusted =
    if year == 2024 {
      p_time - 1704067200
    } else {
      p_time
    }

  let date = determine_date_inner(posix_time_adjusted, year)
  DateTime {
    posix_time: p_time,
    year: date.year,
    month: date.month,
    day_of_month: date.day_of_month,
  }
}

fn determine_date_inner(posix_time: Int, year: Int) -> DateTime {
  let yins = 31536000
  let lyins = 31622400

  let is_leap_year =
    if year % 4 == 0 {
      if year % 100 == 0 {
        if year % 400 == 0 {
          True
        } else {
          False
        }
      } else {
        True
      }
    } else {
      False
    }

  let t =
    if is_leap_year {
      lyins
    } else {
      yins
    }

  if posix_time / t > 0 {
    determine_date_inner(posix_time - t, year + 1)
  } else {
    day_of_the_year_to_date(year, posix_time, is_leap_year)
  }
}

fn day_of_the_year_to_date(
  year: Int,
  p_time: Int,
  is_leap_year: Bool,
) -> DateTime {
  let dins = 86400
  let day_of_the_year =
    if p_time % dins == 0 {
      p_time / dins + 1
    } else {
      p_time / dins + 1
    }
  if is_leap_year {
    if day_of_the_year <= 31 {
      // we are in jan
      DateTime {
        posix_time: p_time,
        year,
        month: 1,
        day_of_month: day_of_the_year,
      }
    } else if day_of_the_year > 31 && day_of_the_year <= 60 {
      // we are in feb
      DateTime {
        posix_time: p_time,
        year,
        month: 2,
        day_of_month: day_of_the_year - 31,
      }
    } else if day_of_the_year > 60 && day_of_the_year <= 91 {
      // we are in march
      DateTime {
        posix_time: p_time,
        year,
        month: 3,
        day_of_month: day_of_the_year - 60,
      }
    } else if day_of_the_year > 91 && day_of_the_year <= 121 {
      // we are in april
      DateTime {
        posix_time: p_time,
        year,
        month: 4,
        day_of_month: day_of_the_year - 91,
      }
    } else if day_of_the_year > 121 && day_of_the_year <= 152 {
      // we are in may
      DateTime {
        posix_time: p_time,
        year,
        month: 5,
        day_of_month: day_of_the_year - 121,
      }
    } else if day_of_the_year > 152 && day_of_the_year <= 182 {
      // we are in june
      DateTime {
        posix_time: p_time,
        year,
        month: 6,
        day_of_month: day_of_the_year - 152,
      }
    } else if day_of_the_year > 182 && day_of_the_year <= 213 {
      // we are in july
      DateTime {
        posix_time: p_time,
        year,
        month: 7,
        day_of_month: day_of_the_year - 182,
      }
    } else if day_of_the_year > 213 && day_of_the_year <= 244 {
      // we are in august
      DateTime {
        posix_time: p_time,
        year,
        month: 8,
        day_of_month: day_of_the_year - 213,
      }
    } else if day_of_the_year > 244 && day_of_the_year <= 274 {
      // we are in september
      DateTime {
        posix_time: p_time,
        year,
        month: 9,
        day_of_month: day_of_the_year - 244,
      }
    } else if day_of_the_year > 274 && day_of_the_year <= 305 {
      // we are in october
      DateTime {
        posix_time: p_time,
        year,
        month: 10,
        day_of_month: day_of_the_year - 274,
      }
    } else if day_of_the_year > 305 && day_of_the_year <= 335 {
      // we are in november
      DateTime {
        posix_time: p_time,
        year,
        month: 11,
        day_of_month: day_of_the_year - 305,
      }
    } else {
      // we are in december
      DateTime {
        posix_time: p_time,
        year,
        month: 12,
        day_of_month: day_of_the_year - 335,
      }
    }
  } else {
    if day_of_the_year <= 31 {
      // we are in jan
      DateTime {
        posix_time: p_time,
        year,
        month: 1,
        day_of_month: day_of_the_year,
      }
    } else if day_of_the_year > 31 && day_of_the_year <= 59 {
      // we are in feb
      DateTime {
        posix_time: p_time,
        year,
        month: 2,
        day_of_month: day_of_the_year - 31,
      }
    } else if day_of_the_year > 59 && day_of_the_year <= 90 {
      // we are in march
      DateTime {
        posix_time: p_time,
        year,
        month: 3,
        day_of_month: day_of_the_year - 59,
      }
    } else if day_of_the_year > 90 && day_of_the_year <= 120 {
      // we are in april
      DateTime {
        posix_time: p_time,
        year,
        month: 4,
        day_of_month: day_of_the_year - 90,
      }
    } else if day_of_the_year > 120 && day_of_the_year <= 151 {
      // we are in may
      DateTime {
        posix_time: p_time,
        year,
        month: 5,
        day_of_month: day_of_the_year - 120,
      }
    } else if day_of_the_year > 151 && day_of_the_year <= 181 {
      // we are in june
      DateTime {
        posix_time: p_time,
        year,
        month: 6,
        day_of_month: day_of_the_year - 151,
      }
    } else if day_of_the_year > 181 && day_of_the_year <= 212 {
      // we are in july
      DateTime {
        posix_time: p_time,
        year,
        month: 7,
        day_of_month: day_of_the_year - 181,
      }
    } else if day_of_the_year > 212 && day_of_the_year <= 243 {
      // we are in august
      DateTime {
        posix_time: p_time,
        year,
        month: 8,
        day_of_month: day_of_the_year - 212,
      }
    } else if day_of_the_year > 243 && day_of_the_year <= 273 {
      // we are in september
      DateTime {
        posix_time: p_time,
        year,
        month: 9,
        day_of_month: day_of_the_year - 243,
      }
    } else if day_of_the_year > 273 && day_of_the_year <= 304 {
      // we are in october
      DateTime {
        posix_time: p_time,
        year,
        month: 10,
        day_of_month: day_of_the_year - 273,
      }
    } else if day_of_the_year > 304 && day_of_the_year <= 334 {
      // we are in november
      DateTime {
        posix_time: p_time,
        year,
        month: 11,
        day_of_month: day_of_the_year - 304,
      }
    } else {
      // we are in december
      DateTime {
        posix_time: p_time,
        year,
        month: 12,
        day_of_month: day_of_the_year - 334,
      }
    }
  }
}

fn to_string(date: DateTime) {
  string.concat(string.concat(string.concat(string.concat(string.from_int(date.year), @"-"), format_month(date.month)), @"-"), format_day(date.day_of_month))
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
  determine_date(1708185253) == DateTime {
    posix_time: 1708185253,
    year: 2024,
    month: 2,
    day_of_month: 17,
  }
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