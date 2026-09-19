mod chart;
mod events;
mod note;
mod value;

pub use note::{HoldTail, Note, SoundSettings};
pub use value::{Ratio, TimeMicros};

fn corrupt(message: &str) -> crate::error::CoreError {
    crate::error::CoreError::new(crate::error::ErrorCode::CorruptChart, message)
}

pub use chart::{GameplayChartInput, GameplayChartV2};
pub use events::{AutoplayEvent, ScrollPoint, TimingPoint};
