use cygnus::libraries::date_time_lib::{date_to_epoch_day, epoch_day_to_date};

#[test]
fn correct_date_to_epoch_day() {
    let day = date_to_epoch_day(2023, 1, 1);
    assert(day == 19358, 'wrong day now');

    let day = date_to_epoch_day(1970, 1, 1);
    assert(day == 0, 'wrong day start');
}

#[test]
fn correct_epoch_day_to_date() {
    let (year, month, day) = epoch_day_to_date(19358);
    assert(year == 2023, 'wrong year');
    assert(month == 1, 'wrong month');
    assert(day == 1, 'wrong day');
}

