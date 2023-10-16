use cygnus::utils::datetime::{date_to_epoch_day, epoch_day_to_date};

#[test]
fn correct_date_to_epoch_day() {
    let day = date_to_epoch_day(2023, 1, 1);
    assert(day == 19358, 'wrong day now');

    let day = date_to_epoch_day(1970, 1, 1);
    assert(day == 0, 'wrong day start');
}
/// TODO - Need to redo the function on `date_time.cairo`
///#[test]
///fn correct_epoch_day_to_date() {
///    let (year, month, day) = epoch_day_to_date(19358);
///    assert(year == 2023, 'edtd wrong year now');
///    assert(month == 1, 'edtd wrong month now');
///    assert(day == 1, 'edtd wrong day now');
///
///    let (year, month, day) = epoch_day_to_date(0);
///    assert(year == 1970, 'edtd wrong year start');
///    assert(month == 1, 'edtd wrong month start');
///    assert(day == 1, 'edtd wrong day start');
///}


