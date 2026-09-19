use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::error::{CoreError, ErrorCode};

fn invalid_path() -> CoreError {
    CoreError::new(ErrorCode::InvalidRequest, "invalid contract path")
}

fn valid_relative(value: &str) -> bool {
    let drive_prefixed = value
        .as_bytes()
        .first()
        .is_some_and(u8::is_ascii_alphabetic)
        && value.as_bytes().get(1) == Some(&b':');
    !(value.contains(['\\', '\0']) || drive_prefixed)
        && value
            .split('/')
            .all(|part| !matches!(part, "" | "." | ".."))
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct SourceRelativePath(String);

impl SourceRelativePath {
    pub fn parse(value: &str) -> Result<Self, CoreError> {
        if !valid_relative(value) {
            return Err(invalid_path());
        }
        Ok(Self(value.to_owned()))
    }
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct BundleRelativePath(String);

impl BundleRelativePath {
    pub fn parse(value: &str) -> Result<Self, CoreError> {
        if !valid_relative(value)
            || !value
                .as_bytes()
                .first()
                .is_some_and(u8::is_ascii_alphanumeric)
            || !value
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b"._/-".contains(&b))
        {
            return Err(invalid_path());
        }
        Ok(Self(value.to_owned()))
    }
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct AbsoluteSourcePath(String);

impl AbsoluteSourcePath {
    pub fn parse(value: &str) -> Result<Self, CoreError> {
        if !Path::new(value).is_absolute()
            || value.contains('\0')
            || value
                .split(std::path::MAIN_SEPARATOR)
                .any(|part| matches!(part, "." | ".."))
        {
            return Err(invalid_path());
        }
        Ok(Self(value.to_owned()))
    }
    pub fn as_path(&self) -> &Path {
        Path::new(&self.0)
    }
    pub fn into_path_buf(self) -> PathBuf {
        self.0.into()
    }
}

macro_rules! string_conversion {
    ($name:ident) => {
        impl TryFrom<String> for $name {
            type Error = CoreError;
            fn try_from(value: String) -> Result<Self, Self::Error> {
                Self::parse(&value)
            }
        }
        impl From<$name> for String {
            fn from(value: $name) -> Self {
                value.0
            }
        }
    };
}
string_conversion!(SourceRelativePath);
string_conversion!(BundleRelativePath);
string_conversion!(AbsoluteSourcePath);
