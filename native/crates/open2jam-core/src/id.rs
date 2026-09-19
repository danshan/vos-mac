use std::fmt;

use serde::{Deserialize, Serialize};

use crate::{
    digest::Digest,
    error::{CoreError, ErrorCode},
};

macro_rules! digest_id {
    ($name:ident, $prefix:literal) => {
        #[derive(
            Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize,
        )]
        #[serde(try_from = "String", into = "String")]
        pub struct $name(Digest);
        impl $name {
            pub const fn from_digest(digest: Digest) -> Self {
                Self(digest)
            }
            pub const fn digest(&self) -> &Digest {
                &self.0
            }
        }
        impl fmt::Display for $name {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                write!(f, "{}{}", $prefix, self.0)
            }
        }
        impl TryFrom<String> for $name {
            type Error = CoreError;
            fn try_from(value: String) -> Result<Self, Self::Error> {
                let digest = value.strip_prefix($prefix).ok_or_else(|| {
                    CoreError::new(ErrorCode::InvalidRequest, "invalid identity prefix")
                })?;
                Ok(Self(Digest::parse(digest)?))
            }
        }
        impl From<$name> for String {
            fn from(value: $name) -> Self {
                value.to_string()
            }
        }
    };
}

digest_id!(SourceId, "source:");
digest_id!(SongId, "song:");
digest_id!(ChartId, "chart:");
digest_id!(SampleId, "sample:");
digest_id!(SourceFingerprint, "");
digest_id!(BundleKey, "");

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct JobId(String);

impl JobId {
    pub fn parse(value: &str) -> Result<Self, CoreError> {
        let base = value.split('.').next().unwrap_or("").to_ascii_uppercase();
        let reserved = matches!(base.as_str(), "CON" | "PRN" | "AUX" | "NUL")
            || (base.len() == 4
                && (base.starts_with("COM") || base.starts_with("LPT"))
                && (b'1'..=b'9').contains(&base.as_bytes()[3]));
        if value.len() > 128
            || value.ends_with('.')
            || reserved
            || !value
                .as_bytes()
                .first()
                .is_some_and(u8::is_ascii_alphanumeric)
            || !value
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b))
        {
            return Err(CoreError::new(ErrorCode::InvalidRequest, "invalid job ID"));
        }
        Ok(Self(value.to_owned()))
    }
    pub fn as_str(&self) -> &str {
        &self.0
    }
}
impl TryFrom<String> for JobId {
    type Error = CoreError;
    fn try_from(value: String) -> Result<Self, Self::Error> {
        Self::parse(&value)
    }
}
impl From<JobId> for String {
    fn from(value: JobId) -> Self {
        value.0
    }
}
