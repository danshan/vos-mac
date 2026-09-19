use std::{collections::BTreeMap, fmt};

use serde::{Deserialize, Serialize};

use crate::path::AbsoluteSourcePath;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ErrorCode {
    UnsupportedFormat,
    CorruptChart,
    MissingCompanion,
    MissingAsset,
    AudioDecodeFailed,
    SoundfontFailed,
    OutOfSpace,
    CacheCorrupt,
    ConverterCrashed,
    Cancelled,
    InternalError,
    InvalidRequest,
    UnsupportedSchema,
    SourceChanged,
}

impl ErrorCode {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::UnsupportedFormat => "UNSUPPORTED_FORMAT",
            Self::CorruptChart => "CORRUPT_CHART",
            Self::MissingCompanion => "MISSING_COMPANION",
            Self::MissingAsset => "MISSING_ASSET",
            Self::AudioDecodeFailed => "AUDIO_DECODE_FAILED",
            Self::SoundfontFailed => "SOUNDFONT_FAILED",
            Self::OutOfSpace => "OUT_OF_SPACE",
            Self::CacheCorrupt => "CACHE_CORRUPT",
            Self::ConverterCrashed => "CONVERTER_CRASHED",
            Self::Cancelled => "CANCELLED",
            Self::InternalError => "INTERNAL_ERROR",
            Self::InvalidRequest => "INVALID_REQUEST",
            Self::UnsupportedSchema => "UNSUPPORTED_SCHEMA",
            Self::SourceChanged => "SOURCE_CHANGED",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "ErrorInfoWire")]
pub struct ErrorInfo {
    code: ErrorCode,
    message: String,
    source_path: Option<AbsoluteSourcePath>,
    context: BTreeMap<String, String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ErrorInfoWire {
    code: ErrorCode,
    message: String,
    source_path: Option<AbsoluteSourcePath>,
    context: BTreeMap<String, String>,
}

impl TryFrom<ErrorInfoWire> for ErrorInfo {
    type Error = CoreError;
    fn try_from(value: ErrorInfoWire) -> Result<Self, Self::Error> {
        if value.message.contains('\0')
            || value
                .context
                .iter()
                .any(|(k, v)| k.contains('\0') || v.contains('\0'))
        {
            return Err(CoreError::new(
                ErrorCode::InvalidRequest,
                "error information contains NUL",
            ));
        }
        Ok(Self {
            code: value.code,
            message: value.message,
            source_path: value.source_path,
            context: value.context,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreError(ErrorInfo);

impl CoreError {
    pub fn new(code: ErrorCode, message: impl Into<String>) -> Self {
        let message = message.into();
        if message.contains('\0') {
            return Self::new(ErrorCode::InternalError, "error message contained NUL");
        }
        Self(ErrorInfo {
            code,
            message,
            source_path: None,
            context: BTreeMap::new(),
        })
    }
    pub fn with_context(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        let (key, value) = (key.into(), value.into());
        if key.contains('\0') || value.contains('\0') {
            return Self::new(ErrorCode::InternalError, "error context contained NUL");
        }
        self.0.context.insert(key, value);
        self
    }
}

impl ErrorInfo {
    pub fn code(&self) -> ErrorCode {
        self.code
    }
    pub fn message(&self) -> &str {
        &self.message
    }
    pub fn source_path(&self) -> Option<&AbsoluteSourcePath> {
        self.source_path.as_ref()
    }
    pub fn context(&self) -> &BTreeMap<String, String> {
        &self.context
    }
}
impl CoreError {
    pub fn code(&self) -> ErrorCode {
        self.0.code()
    }
    pub fn message(&self) -> &str {
        self.0.message()
    }
    pub fn source_path(&self) -> Option<&AbsoluteSourcePath> {
        self.0.source_path()
    }
    pub fn context(&self) -> &BTreeMap<String, String> {
        self.0.context()
    }
}
impl From<CoreError> for ErrorInfo {
    fn from(value: CoreError) -> Self {
        value.0
    }
}
impl fmt::Display for CoreError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.code().as_str(), self.message())
    }
}
impl std::error::Error for CoreError {}

#[derive(Debug)]
pub enum ProtocolError {
    Invalid(CoreError),
    Io {
        code: ErrorCode,
        source: std::io::Error,
    },
    Json {
        code: ErrorCode,
        source: serde_json::Error,
    },
}
impl ProtocolError {
    pub fn code(&self) -> ErrorCode {
        match self {
            Self::Invalid(e) => e.code(),
            Self::Io { code, .. } | Self::Json { code, .. } => *code,
        }
    }
}
impl From<CoreError> for ProtocolError {
    fn from(value: CoreError) -> Self {
        Self::Invalid(value)
    }
}
impl fmt::Display for ProtocolError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Invalid(e) => e.fmt(f),
            Self::Io { code, source } => write!(f, "{}: {source}", code.as_str()),
            Self::Json { code, source } => write!(f, "{}: {source}", code.as_str()),
        }
    }
}
impl std::error::Error for ProtocolError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        Some(match self {
            Self::Invalid(e) => e,
            Self::Io { source, .. } => source,
            Self::Json { source, .. } => source,
        })
    }
}
