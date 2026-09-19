use super::corrupt;
use crate::error::CoreError;
use serde::{Deserialize, Serialize};

// Godot JSON numbers pass through binary64 before conversion to runtime values.
const MAX_EXACT_JSON_INTEGER: u64 = (1 << 53) - 1;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(try_from = "u64", into = "u64")]
pub struct TimeMicros(u64);
impl TimeMicros {
    pub fn new(value: u64) -> Result<Self, CoreError> {
        if value > MAX_EXACT_JSON_INTEGER {
            return Err(corrupt("time exceeds exact JSON integer range"));
        }
        Ok(Self(value))
    }
    pub fn get(self) -> u64 {
        self.0
    }
}
impl TryFrom<u64> for TimeMicros {
    type Error = CoreError;
    fn try_from(value: u64) -> Result<Self, Self::Error> {
        Self::new(value)
    }
}
impl From<TimeMicros> for u64 {
    fn from(value: TimeMicros) -> Self {
        value.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "RatioWire")]
pub struct Ratio {
    numerator: i64,
    denominator: u32,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct RatioWire {
    numerator: i64,
    denominator: u32,
}
impl Ratio {
    pub fn new(numerator: i64, denominator: u32) -> Result<Self, CoreError> {
        if denominator == 0 || numerator.unsigned_abs() > MAX_EXACT_JSON_INTEGER {
            return Err(corrupt("invalid rational value"));
        }
        let (mut a, mut b) = (numerator.unsigned_abs(), u64::from(denominator));
        while b != 0 {
            (a, b) = (b, a % b);
        }
        Ok(Self {
            numerator: numerator / a as i64,
            denominator: denominator / a as u32,
        })
    }
    pub fn numerator(self) -> i64 {
        self.numerator
    }
    pub fn denominator(self) -> u32 {
        self.denominator
    }
    pub fn is_between(self, minimum: i64, maximum: i64) -> bool {
        let n = i128::from(self.numerator);
        let d = i128::from(self.denominator);
        i128::from(minimum) * d <= n && n <= i128::from(maximum) * d
    }
}
impl TryFrom<RatioWire> for Ratio {
    type Error = CoreError;
    fn try_from(value: RatioWire) -> Result<Self, Self::Error> {
        Self::new(value.numerator, value.denominator)
    }
}
