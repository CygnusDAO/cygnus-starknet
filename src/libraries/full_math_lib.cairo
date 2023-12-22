/// Quick library
mod FullMathLib {
    /// ------------------------------------------------------------------------------------
    ///                                    IMPORTS
    /// ------------------------------------------------------------------------------------

    /// Core
    use integer::{u256_wide_mul, u256_safe_divmod, u512_safe_div_rem_by_u256, u256_try_as_non_zero, u256_sqrt};

    /// Errors
    use cygnus::libraries::errors::FullMathLibErrors;

    /// Constants
    const WAD: u128 = 1_000000000_000000000;

    /// Trait
    trait FixedPointMathLibTrait<T> {
        /// @dev Calculates `floor(a * b / d)` with full precision.
        /// Throws if result overflows a uint256 or when `d` is zero.
        fn full_mul_div(self: @T, y: T, d: T) -> T;

        /// @dev Calculates `floor(x * y / d)` with full precision, rounded up.
        /// Throws if result overflows a uint256 or when `d` is zero.
        fn full_mul_div_up(self: @T, y: T, d: T) -> T;

        /// @dev Equivalent to `(x * y) / WAD` rounded down.
        fn mul_wad(self: @T, y: T) -> T;

        /// @dev Equivalent to `(x * y) / WAD` rounded up.
        fn mul_wad_up(self: @T, y: T) -> T;

        /// @dev Equivalent to `(x * WAD) / y` rounded down.
        fn div_wad(self: @T, y: T) -> T;

        /// @dev Equivalent to `(x * WAD) / y` rounded up.
        fn div_wad_up(self: @T, y: T) -> T;

        fn gm(self: @T, y: T) -> T;

        fn pow(self: @T, n: T) -> T;
    }

    /// ------------------------------------------------------------------------------------
    ///                                 IMPLEMENTATION
    /// ------------------------------------------------------------------------------------

    impl FixedPointMathLibImpl of FixedPointMathLibTrait<u128> {
        /// @inheritdoc FixedPointMathLibTrait
        fn full_mul_div(self: @u128, y: u128, d: u128) -> u128 {
            mul_div(*self, y, d, false)
        }

        /// @inheritdoc FixedPointMathLibTrait
        fn full_mul_div_up(self: @u128, y: u128, d: u128) -> u128 {
            mul_div(*self, y, d, true)
        }

        /// @inheritdoc FixedPointMathLibTrait
        fn div_wad(self: @u128, y: u128) -> u128 {
            mul_div(*self, WAD, y, false)
        }

        /// @inheritdoc FixedPointMathLibTrait
        fn div_wad_up(self: @u128, y: u128) -> u128 {
            mul_div(*self, WAD, y, true)
        }

        /// @inheritdoc FixedPointMathLibTrait
        fn mul_wad(self: @u128, y: u128) -> u128 {
            mul_div(*self, y, WAD, false)
        }

        /// @inheritdoc FixedPointMathLibTrait
        fn mul_wad_up(self: @u128, y: u128) -> u128 {
            mul_div(*self, y, WAD, true)
        }

        fn gm(self: @u128, y: u128) -> u128 {
            let _x = u256 { low: *self, high: 0 };
            let _y = u256 { low: y, high: 0 };
            gm(_x, _y)
        }

        /// Raise a number to a power, computes x^n.
        /// * `x` - The number to raise.
        /// * `n` - The exponent.
        /// # Returns
        /// * `u256` - The result of x raised to the power of n.
        fn pow(self: @u128, n: u128) -> u128 {
            if n == 0 {
                1
            } else if n == 1 {
                *self
            } else if (n & 1) == 1 {
                *self * pow(*self * *self, n / 2)
            } else {
                pow(*self * *self, n / 2)
            }
        }
    }

    /// ------------------------------------------------------------------------------------
    ///                                 LOGIC
    /// ------------------------------------------------------------------------------------

    fn gm(x: u256, y: u256) -> u128 {
        u256_sqrt(x * y)
    }

    /// Raise a number to a power, computes x^n.
    /// * `x` - The number to raise.
    /// * `n` - The exponent.
    /// # Returns
    /// * `u256` - The result of x raised to the power of n.
    fn pow(x: u128, n: u128) -> u128 {
        if n == 0 {
            1
        } else if n == 1 {
            x
        } else if (n & 1) == 1 {
            x * pow(x * x, n / 2)
        } else {
            pow(x * x, n / 2)
        }
    }

    /// From Satoru: https://github.com/keep-starknet-strange/satoru/blob/main/src/utils/precision.cairo
    ///
    /// Apply multiplication then division to value with a roundup.
    /// # Arguments
    /// * `value` - The value muldiv is applied to.
    /// * `numerator` - The numerator that multiplies value.
    /// * `divisor` - The denominator that divides value.
    fn mul_div(value: u128, numerator: u128, denominator: u128, roundup_magnitude: bool) -> u128 {
        let value = u256 { low: value, high: 0 };
        let numerator = u256 { low: numerator, high: 0 };
        let denominator = u256 { low: denominator, high: 0 };
        let product = u256_wide_mul(value, numerator);
        let (q, r) = u512_safe_div_rem_by_u256(product, u256_try_as_non_zero(denominator).expect('MulDivByZero'));
        if roundup_magnitude && r > 0 {
            let result = u256 { low: q.limb0, high: q.limb1 };
            assert(
                result != integer::BoundedU256::max() && q.limb1 == 0 && q.limb2 == 0 && q.limb3 == 0, 'MulDivOverflow'
            );
            q.limb0 + 1
        } else {
            assert(q.limb1 == 0 && q.limb2 == 0 && q.limb3 == 0, 'MulDivOverflow');
            q.limb0
        }
    }
}
