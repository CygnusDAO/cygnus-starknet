use integer::{BoundedInt, u256_wide_mul};
use cygnus::data::signed_integer::{i64::{i64, u64Intoi64, i64TryIntou64, i64_new}, integer_trait::{IntegerTrait}};

// ------------------------------------------------------------------------
//                            DATE TIME LIB
// ------------------------------------------------------------------------
/// From: https://howardhinnant.github.io/date_algorithms.html

/// # Returns
/// * The number of days since 1970-01-01 given (`year`,`month`,`day`)
fn date_to_epoch_day(year: u64, month: u64, day: u64) -> u64 {
    let mut y = year;
    if month <= 2 {
        y -= 1;
    }
    let era = if y >= 0 {
        y / 400
    } else {
        (y - 399) / 400
    };
    let yoe = y - era * 400;
    let multi = if month > 2 {
        month - 3
    } else {
        month + 9
    };
    let doy = (153 * multi + 2) / 5 + day - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe - 719468
}

/// # Returns
/// * The (`year`,`month`,`day`) from the number of days since 1970-01-01
fn epoch_day_to_date(mut epoch_day: u64) -> (u64, u64, u64) {
    epoch_day += 719468;
    let era: i64 = ((if epoch_day >= 0 {
        epoch_day
    } else {
        epoch_day - 146096
    }) / 146097).into();
    let doe: u64 = (epoch_day.into() - era * i64_new(146097, false)).try_into().unwrap();
    let yoe: u64 = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y: i64 = yoe.into() + era * i64_new(400, false);
    let doy: u64 = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp: u64 = (5 * doy + 2) / 153;
    let d: u64 = doy - (153 * mp + 2) / 5 + 1;
    let m: u64 = if mp < 10 {
        mp + 3
    } else {
        mp - 9
    };
    let _y: u64 = 1;
    ((y + if m <= 2 {
        i64_new(1, false)
    } else {
        i64_new(0, false)
    }).try_into().unwrap(), m, d)
}


/// # Returns 
/// * The unix timestamp given year/month/day
fn date_to_timestamp(year: u64, month: u64, day: u64) -> u64 {
    date_to_epoch_day(year, month, day) * 86400
}

/// # Returns 
/// * (`year`,`month`,`day`) from the given unix timestamp.
fn timestamp_to_date(timestamp: u64) -> (u64, u64, u64) {
    epoch_day_to_date(timestamp)
}


/// # Returns 
/// * The unix timestamp from / (`year`,`month`,`day`,`hour`,`minute`,`second`).
fn datetime_to_timestamp(year: u64, month: u64, day: u64, hour: u64, minute: u64, second: u64) -> u64 {
    date_to_epoch_day(year, month, day) * 86400 + hour * 3600 + minute * 60 + second
}

/// Returns the weekday from the unix timestamp.
/// Monday: 1, Tuesday: 2, ....., Sunday: 7.
fn weekday(timestamp: u64) -> u64 {
    ((timestamp / 86400 + 3) % 7) + 1
}

fn diff_days(from_timestamp: u64, to_timestamp: u64) -> u64 {
    (to_timestamp - from_timestamp) / 86400
}

fn diff_hours(from_timestamp: u64, to_timestamp: u64) -> u64 {
    (to_timestamp - from_timestamp) / 3600
}

fn diff_minutes(from_timestamp: u64, to_timestamp: u64) -> u64 {
    (to_timestamp - from_timestamp) / 60
}

fn diff_seconds(from_timestamp: u64, to_timestamp: u64) -> u64 {
    to_timestamp - from_timestamp
}
