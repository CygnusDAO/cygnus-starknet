/// Errors
mod MathLibErrors {
    /// Mul div up overflwo
    const MUL_DIV_UP_OVERFLOW: felt252 = 'mul_div_up_overflow';
    const MUL_MOD_ZERO: felt252 = 'mul_mod_zero';
    const MUL_DIV_ZERO: felt252 = 'mul_div_by_zero';
    const MUL_DIV_OVERFLOW: felt252 = 'mul_div_overflow';
}

/// Quick library
mod FixedPointMathLib {
    /// ------------------------------------------------------------------------------------
    ///                                    IMPORTS
    /// ------------------------------------------------------------------------------------

    /// Core
    use integer::{u256_wide_mul, u256_safe_divmod, u512_safe_div_rem_by_u256, u256_try_as_non_zero};

    /// Constants
    const WAD: u256 = 1_000000000_000000000;
    use super::MathLibErrors;

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
    }

    /// ------------------------------------------------------------------------------------
    ///                                 IMPLEMENTATION
    /// ------------------------------------------------------------------------------------

    impl FixedPointMathLibImpl of FixedPointMathLibTrait<u256> {
        /// @inheritdoc FixedPointMathLibTrait
        fn full_mul_div(self: @u256, y: u256, d: u256) -> u256 {
            mul_div(*self, y, d, false)
        }

        /// @inheritdoc FixedPointMathLibTrait
        fn full_mul_div_up(self: @u256, y: u256, d: u256) -> u256 {
            mul_div(*self, y, d, true)
        }

        /// @inheritdoc FixedPointMathLibTrait
        fn div_wad(self: @u256, y: u256) -> u256 {
            mul_div(*self, WAD, y, false)
        }

        /// @inheritdoc FixedPointMathLibTrait
        fn div_wad_up(self: @u256, y: u256) -> u256 {
            mul_div(*self, WAD, y, true)
        }

        /// @inheritdoc FixedPointMathLibTrait
        fn mul_wad(self: @u256, y: u256) -> u256 {
            mul_div(*self, y, WAD, false)
        }

        /// @inheritdoc FixedPointMathLibTrait
        fn mul_wad_up(self: @u256, y: u256) -> u256 {
            mul_div(*self, y, WAD, true)
        }
    }

    /// ------------------------------------------------------------------------------------
    ///                                 LOGIC
    /// ------------------------------------------------------------------------------------

    /// From Satoru: https://github.com/keep-starknet-strange/satoru/blob/main/src/utils/precision.cairo
    ///
    /// Apply multiplication then division to value.
    /// # Arguments
    /// * `value` - The value muldiv is applied to.
    /// * `numerator` - The numerator that multiplies value.
    /// * `divisor` - The denominator that divides value.
    fn mul_div(a: u256, b: u256, denominator: u256, round_up: bool) -> u256 {
        let product = u256_wide_mul(a, b);
        let (q, r) = u512_safe_div_rem_by_u256(
            product, u256_try_as_non_zero(denominator).expect(MathLibErrors::MUL_DIV_ZERO)
        );
        assert(q.limb2 == 0 && q.limb3 == 0, MathLibErrors::MUL_DIV_OVERFLOW);
        let result = u256 { low: q.limb0, high: q.limb1 };
        if round_up && r > 0 {
            assert(result < integer::BoundedInt::max(), MathLibErrors::MUL_DIV_UP_OVERFLOW);
            result + 1
        } else {
            result
        }
    }
}
