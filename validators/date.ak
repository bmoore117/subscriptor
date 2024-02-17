use aiken/string

fn determine_date(posix_time: Int) -> String {
  let year = 1970

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

fn determine_date_inner(posix_time: Int, year: Int) -> String {
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
  posix_time: Int,
  is_leap_year: Bool,
) -> String {
  let dins = 86400
  let day_of_the_year =
    if posix_time % dins == 0 {
      posix_time / dins
    } else {
      posix_time / dins + 1
    }
  if is_leap_year {
    if day_of_the_year <= 31 {
      // we are in jan
      string.concat(
        string.concat(string.from_int(year), @"-01-"),
        string.from_int(day_of_the_year),
      )
    } else if day_of_the_year > 31 && day_of_the_year <= 60 {
      // we are in feb
      string.concat(
        string.concat(string.from_int(year), @"-02-"),
        string.from_int(day_of_the_year - 31),
      )
    } else if day_of_the_year > 60 && day_of_the_year <= 91 {
      // we are in march
      string.concat(
        string.concat(string.from_int(year), @"-03-"),
        string.from_int(day_of_the_year - 60),
      )
    } else if day_of_the_year > 91 && day_of_the_year <= 121 {
      // we are in april
      string.concat(
        string.concat(string.from_int(year), @"-04-"),
        string.from_int(day_of_the_year - 91),
      )
    } else if day_of_the_year > 121 && day_of_the_year <= 152 {
      // we are in may
      string.concat(
        string.concat(string.from_int(year), @"-05-"),
        string.from_int(day_of_the_year - 121),
      )
    } else if day_of_the_year > 152 && day_of_the_year <= 182 {
      // we are in june
      string.concat(
        string.concat(string.from_int(year), @"-06-"),
        string.from_int(day_of_the_year - 152),
      )
    } else if day_of_the_year > 182 && day_of_the_year <= 213 {
      // we are in july
      string.concat(
        string.concat(string.from_int(year), @"-07-"),
        string.from_int(day_of_the_year - 182),
      )
    } else if day_of_the_year > 213 && day_of_the_year <= 244 {
      // we are in august
      string.concat(
        string.concat(string.from_int(year), @"-08-"),
        string.from_int(day_of_the_year - 213),
      )
    } else if day_of_the_year > 244 && day_of_the_year <= 274 {
      // we are in september
      string.concat(
        string.concat(string.from_int(year), @"-09-"),
        string.from_int(day_of_the_year - 244),
      )
    } else if day_of_the_year > 274 && day_of_the_year <= 305 {
      // we are in october
      string.concat(
        string.concat(string.from_int(year), @"-10-"),
        string.from_int(day_of_the_year - 274),
      )
    } else if day_of_the_year > 305 && day_of_the_year <= 335 {
      // we are in november
      string.concat(
        string.concat(string.from_int(year), @"-11-"),
        string.from_int(day_of_the_year - 305),
      )
    } else {
      // we are in december
      string.concat(
        string.concat(string.from_int(year), @"-12-"),
        string.from_int(day_of_the_year - 335),
      )
    }
  } else {
    if day_of_the_year <= 31 {
      // we are in jan
      string.concat(
        string.concat(string.from_int(year), @"-01-"),
        string.from_int(day_of_the_year),
      )
    } else if day_of_the_year > 31 && day_of_the_year <= 59 {
      // we are in feb
      string.concat(
        string.concat(string.from_int(year), @"-02-"),
        string.from_int(day_of_the_year - 31),
      )
    } else if day_of_the_year > 59 && day_of_the_year <= 90 {
      // we are in march
      string.concat(
        string.concat(string.from_int(year), @"-03-"),
        string.from_int(day_of_the_year - 59),
      )
    } else if day_of_the_year > 90 && day_of_the_year <= 120 {
      // we are in april
      string.concat(
        string.concat(string.from_int(year), @"-04-"),
        string.from_int(day_of_the_year - 90),
      )
    } else if day_of_the_year > 120 && day_of_the_year <= 151 {
      // we are in may
      string.concat(
        string.concat(string.from_int(year), @"-05-"),
        string.from_int(day_of_the_year - 120),
      )
    } else if day_of_the_year > 151 && day_of_the_year <= 181 {
      // we are in june
      string.concat(
        string.concat(string.from_int(year), @"-06-"),
        string.from_int(day_of_the_year - 151),
      )
    } else if day_of_the_year > 181 && day_of_the_year <= 212 {
      // we are in july
      string.concat(
        string.concat(string.from_int(year), @"-07-"),
        string.from_int(day_of_the_year - 181),
      )
    } else if day_of_the_year > 212 && day_of_the_year <= 243 {
      // we are in august
      string.concat(
        string.concat(string.from_int(year), @"-08-"),
        string.from_int(day_of_the_year - 212),
      )
    } else if day_of_the_year > 243 && day_of_the_year <= 273 {
      // we are in september
      string.concat(
        string.concat(string.from_int(year), @"-09-"),
        string.from_int(day_of_the_year - 243),
      )
    } else if day_of_the_year > 273 && day_of_the_year <= 304 {
      // we are in october
      string.concat(
        string.concat(string.from_int(year), @"-10-"),
        string.from_int(day_of_the_year - 273),
      )
    } else if day_of_the_year > 304 && day_of_the_year <= 334 {
      // we are in november
      string.concat(
        string.concat(string.from_int(year), @"-11-"),
        string.from_int(day_of_the_year - 304),
      )
    } else {
      // we are in december
      string.concat(
        string.concat(string.from_int(year), @"-12-"),
        string.from_int(day_of_the_year - 334),
      )
    }
  }
}

test determine_date_3() {
  // current year is 2024
  determine_date(1708185253) == @"2024-02-17"
}
