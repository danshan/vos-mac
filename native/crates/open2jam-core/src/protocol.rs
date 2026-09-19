use serde::{Deserialize, Serialize, de::DeserializeOwned};
use std::collections::{BTreeMap, BTreeSet};

use crate::{
    digest::Digest,
    error::{CoreError, ErrorCode, ErrorInfo, ProtocolError},
    format::SourceKind,
    id::{BundleKey, ChartId, JobId, LibraryRootId},
    json::Contract,
    path::{AbsoluteSourcePath, SourceRelativePath},
    schema::{REQUEST_SCHEMA_VERSION, RESULT_SCHEMA_VERSION, STATIC_ASSETS_VERSION},
};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CatalogRequestV1 {
    pub schema_version: u16,
    pub job_id: JobId,
    pub command: Command,
    pub roots: Vec<AbsoluteSourcePath>,
    #[serde(
        default,
        skip_serializing_if = "BTreeMap::is_empty",
        deserialize_with = "deserialize_root_ids"
    )]
    pub root_ids: BTreeMap<AbsoluteSourcePath, LibraryRootId>,
    pub previous_index_path: Option<AbsoluteSourcePath>,
    pub staging_root: AbsoluteSourcePath,
    pub cancel_marker_path: AbsoluteSourcePath,
}

fn deserialize_root_ids<'de, D: serde::Deserializer<'de>>(
    deserializer: D,
) -> Result<BTreeMap<AbsoluteSourcePath, LibraryRootId>, D::Error> {
    struct RootIdsVisitor;
    impl<'de> serde::de::Visitor<'de> for RootIdsVisitor {
        type Value = BTreeMap<AbsoluteSourcePath, LibraryRootId>;

        fn expecting(&self, formatter: &mut std::fmt::Formatter) -> std::fmt::Result {
            formatter.write_str("unique library root paths mapped to persistent IDs")
        }

        fn visit_map<M: serde::de::MapAccess<'de>>(
            self,
            mut map: M,
        ) -> Result<Self::Value, M::Error> {
            let mut ids = BTreeMap::new();
            while let Some((path, id)) = map.next_entry()? {
                if ids.insert(path, id).is_some() {
                    return Err(serde::de::Error::custom("duplicate library root path"));
                }
            }
            Ok(ids)
        }
    }
    deserializer.deserialize_map(RootIdsVisitor)
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BundleRequestV1 {
    pub schema_version: u16,
    pub job_id: JobId,
    pub command: Command,
    pub chart_id: ChartId,
    pub source_path: AbsoluteSourcePath,
    pub source_kind: SourceKind,
    pub selector: ChartSelector,
    pub staging_root: AbsoluteSourcePath,
    pub cancel_marker_path: AbsoluteSourcePath,
    pub soundfont: SoundFontRequest,
    pub static_assets_version: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Command {
    Catalog,
    Bundle,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "kind",
    rename_all = "SCREAMING_SNAKE_CASE",
    rename_all_fields = "camelCase",
    deny_unknown_fields
)]
pub enum ChartSelector {
    VosChart { index: u8 },
    OjnChart { index: u8 },
    OsuBeatmap { relative_path: SourceRelativePath },
    BundleChart { chart_id: ChartId },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SoundFontRequest {
    pub path: AbsoluteSourcePath,
    pub version: String,
    pub sha256: Digest,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum JobStatus {
    Succeeded,
    Failed,
    Cancelled,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CommandResultV1<T> {
    pub schema_version: u16,
    pub job_id: Option<JobId>,
    pub command: Command,
    pub status: JobStatus,
    pub output: Option<T>,
    pub error: Option<ErrorInfo>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CatalogOutputV1 {
    pub catalog_path: AbsoluteSourcePath,
    pub source_count: u64,
    pub song_count: u64,
    pub chart_count: u64,
    pub rejected_source_count: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BundleOutputV1 {
    pub staging_path: AbsoluteSourcePath,
    pub bundle_key: BundleKey,
    pub manifest_path: AbsoluteSourcePath,
}

fn invalid(message: &str) -> ProtocolError {
    CoreError::new(ErrorCode::InvalidRequest, message).into()
}

fn validate_schema(actual: u16, expected: u16) -> Result<(), ProtocolError> {
    if actual != expected {
        return Err(
            CoreError::new(ErrorCode::UnsupportedSchema, "unsupported schema version").into(),
        );
    }
    Ok(())
}

impl Command {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Catalog => "CATALOG",
            Self::Bundle => "BUNDLE",
        }
    }
}

impl CatalogRequestV1 {
    pub fn validate(&self) -> Result<(), ProtocolError> {
        validate_schema(self.schema_version, REQUEST_SCHEMA_VERSION)?;
        if self.command != Command::Catalog || self.roots.windows(2).any(|pair| pair[0] >= pair[1])
        {
            return Err(invalid(
                "catalog requires sorted unique roots and CATALOG command",
            ));
        }
        if !self.root_ids.is_empty()
            && (self.root_ids.keys().ne(self.roots.iter())
                || self.root_ids.values().collect::<BTreeSet<_>>().len() != self.root_ids.len())
        {
            return Err(invalid(
                "catalog root IDs must cover every root exactly once",
            ));
        }
        Ok(())
    }
}
impl Contract for CatalogRequestV1 {
    const SCHEMA_VERSION: u16 = REQUEST_SCHEMA_VERSION;
    fn validate(&self) -> Result<(), ProtocolError> {
        self.validate()
    }
}

impl BundleRequestV1 {
    pub fn validate(&self) -> Result<(), ProtocolError> {
        validate_schema(self.schema_version, REQUEST_SCHEMA_VERSION)?;
        let compatible = match (&self.source_kind, &self.selector) {
            (SourceKind::Vos, ChartSelector::VosChart { index }) => *index == 0,
            (SourceKind::Ojn, ChartSelector::OjnChart { index }) => *index <= 2,
            (SourceKind::Osu | SourceKind::Osz, ChartSelector::OsuBeatmap { .. }) => true,
            (SourceKind::BundleV2, ChartSelector::BundleChart { chart_id }) => {
                *chart_id == self.chart_id
            }
            _ => false,
        };
        if self.command != Command::Bundle || !compatible {
            return Err(invalid(
                "bundle command, source kind, and selector must agree",
            ));
        }
        if self.static_assets_version != STATIC_ASSETS_VERSION
            || self.soundfont.version.is_empty()
            || self.soundfont.version.contains('\0')
        {
            return Err(invalid("invalid asset version"));
        }
        Ok(())
    }
}
impl Contract for BundleRequestV1 {
    const SCHEMA_VERSION: u16 = REQUEST_SCHEMA_VERSION;
    fn validate(&self) -> Result<(), ProtocolError> {
        self.validate()
    }
}

impl<T> CommandResultV1<T> {
    pub fn succeeded(job_id: JobId, command: Command, output: T) -> Self {
        Self {
            schema_version: RESULT_SCHEMA_VERSION,
            job_id: Some(job_id),
            command,
            status: JobStatus::Succeeded,
            output: Some(output),
            error: None,
        }
    }
    pub fn failed(job_id: JobId, command: Command, error: ErrorInfo) -> Self {
        Self {
            schema_version: RESULT_SCHEMA_VERSION,
            job_id: Some(job_id),
            command,
            status: JobStatus::Failed,
            output: None,
            error: Some(error),
        }
    }
    pub fn cancelled(job_id: JobId, command: Command, error: ErrorInfo) -> Self {
        Self {
            schema_version: RESULT_SCHEMA_VERSION,
            job_id: Some(job_id),
            command,
            status: JobStatus::Cancelled,
            output: None,
            error: Some(error),
        }
    }
    pub fn protocol_failure(command: Command, error: ErrorInfo) -> Self {
        Self {
            schema_version: RESULT_SCHEMA_VERSION,
            job_id: None,
            command,
            status: JobStatus::Failed,
            output: None,
            error: Some(error),
        }
    }
    pub fn validate(&self) -> Result<(), ProtocolError> {
        validate_schema(self.schema_version, RESULT_SCHEMA_VERSION)?;
        let valid = match self.status {
            JobStatus::Succeeded => {
                self.job_id.is_some() && self.output.is_some() && self.error.is_none()
            }
            JobStatus::Failed => {
                self.output.is_none()
                    && self.error.as_ref().is_some_and(|e| {
                        self.job_id.is_some()
                            || matches!(
                                e.code(),
                                ErrorCode::InvalidRequest | ErrorCode::UnsupportedSchema
                            )
                    })
            }
            JobStatus::Cancelled => {
                self.job_id.is_some()
                    && self.output.is_none()
                    && self
                        .error
                        .as_ref()
                        .is_some_and(|e| e.code() == ErrorCode::Cancelled)
            }
        };
        if !valid {
            return Err(invalid("inconsistent command result envelope"));
        }
        Ok(())
    }
}
impl<T: Serialize + DeserializeOwned> Contract for CommandResultV1<T> {
    const SCHEMA_VERSION: u16 = RESULT_SCHEMA_VERSION;
    fn validate(&self) -> Result<(), ProtocolError> {
        self.validate()
    }
}
