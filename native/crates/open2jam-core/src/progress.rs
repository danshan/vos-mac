use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::error::{CoreError, ErrorCode, ProtocolError};
use crate::id::JobId;
use crate::json::{Contract, encode_contract};
use crate::protocol::Command;
use crate::schema::PROGRESS_SCHEMA_VERSION;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ProgressPhase {
    DiscoverSources,
    FingerprintSources,
    ParseSources,
    WriteCatalog,
    CatalogReady,
    CheckCache,
    HashSources,
    ParseChart,
    CompileTiming,
    PrepareAudio,
    WriteBundle,
    VerifyBundle,
    PreloadStartupAudio,
    CreateGameplay,
    Ready,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProgressOwner {
    CatalogCli,
    BundleCli,
    GodotGameplay,
}

impl ProgressPhase {
    pub fn is_allowed_for(self, owner: ProgressOwner) -> bool {
        use ProgressPhase::*;
        match owner {
            ProgressOwner::CatalogCli => matches!(
                self,
                DiscoverSources | FingerprintSources | ParseSources | WriteCatalog | CatalogReady
            ),
            ProgressOwner::BundleCli => matches!(
                self,
                HashSources
                    | ParseChart
                    | CompileTiming
                    | PrepareAudio
                    | WriteBundle
                    | VerifyBundle
            ),
            ProgressOwner::GodotGameplay => matches!(
                self,
                CheckCache
                    | HashSources
                    | ParseChart
                    | CompileTiming
                    | PrepareAudio
                    | WriteBundle
                    | VerifyBundle
                    | PreloadStartupAudio
                    | CreateGameplay
                    | Ready
            ),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", try_from = "ProgressEventWire")]
pub struct ProgressEventV1 {
    schema_version: u16,
    job_id: JobId,
    sequence: u64,
    command: Command,
    phase: ProgressPhase,
    completed_units: u64,
    total_units: u64,
    unit: String,
    current_item: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ProgressEventWire {
    schema_version: u16,
    job_id: JobId,
    sequence: u64,
    command: Command,
    phase: ProgressPhase,
    completed_units: u64,
    total_units: u64,
    unit: String,
    current_item: Option<String>,
}

impl TryFrom<ProgressEventWire> for ProgressEventV1 {
    type Error = CoreError;
    fn try_from(wire: ProgressEventWire) -> Result<Self, Self::Error> {
        let event = Self {
            schema_version: wire.schema_version,
            job_id: wire.job_id,
            sequence: wire.sequence,
            command: wire.command,
            phase: wire.phase,
            completed_units: wire.completed_units,
            total_units: wire.total_units,
            unit: wire.unit,
            current_item: wire.current_item,
        };
        event.validate_fields()?;
        Ok(event)
    }
}

impl ProgressEventV1 {
    fn validate_fields(&self) -> Result<(), CoreError> {
        if self.schema_version != PROGRESS_SCHEMA_VERSION {
            return Err(CoreError::new(
                ErrorCode::UnsupportedSchema,
                "unsupported progress schema",
            ));
        }
        if self.sequence == 0
            || self.completed_units > self.total_units
            || self.unit.is_empty()
            || self.unit.contains('\0')
            || self
                .current_item
                .as_ref()
                .is_some_and(|item| item.contains('\0'))
        {
            return Err(CoreError::new(
                ErrorCode::InvalidRequest,
                "invalid progress event",
            ));
        }
        Ok(())
    }
    pub fn schema_version(&self) -> u16 {
        self.schema_version
    }
    pub fn job_id(&self) -> &JobId {
        &self.job_id
    }
    pub fn sequence(&self) -> u64 {
        self.sequence
    }
    pub fn command(&self) -> Command {
        self.command
    }
    pub fn phase(&self) -> ProgressPhase {
        self.phase
    }
    pub fn completed_units(&self) -> u64 {
        self.completed_units
    }
    pub fn total_units(&self) -> u64 {
        self.total_units
    }
    pub fn unit(&self) -> &str {
        &self.unit
    }
    pub fn current_item(&self) -> Option<&str> {
        self.current_item.as_deref()
    }
}

impl Contract for ProgressEventV1 {
    fn validate(&self) -> Result<(), ProtocolError> {
        self.validate_fields().map_err(Into::into)
    }
}

pub trait ProgressSink {
    fn write(&mut self, event: &ProgressEventV1) -> Result<(), CoreError>;
}

pub struct ProgressTracker<'a> {
    job_id: JobId,
    command: Command,
    owner: ProgressOwner,
    next_sequence: u64,
    write_failed: bool,
    sink: &'a mut dyn ProgressSink,
}

impl<'a> ProgressTracker<'a> {
    pub fn new(
        job_id: JobId,
        command: Command,
        owner: ProgressOwner,
        sink: &'a mut dyn ProgressSink,
    ) -> Result<Self, CoreError> {
        let expected_command = if owner == ProgressOwner::CatalogCli {
            Command::Catalog
        } else {
            Command::Bundle
        };
        if command != expected_command {
            return Err(CoreError::new(
                ErrorCode::InvalidRequest,
                "progress owner does not match command",
            ));
        }
        Ok(Self {
            job_id,
            command,
            owner,
            next_sequence: 1,
            write_failed: false,
            sink,
        })
    }

    pub fn emit(
        &mut self,
        phase: ProgressPhase,
        completed_units: u64,
        total_units: u64,
        unit: String,
        current_item: Option<String>,
    ) -> Result<(), CoreError> {
        if self.write_failed {
            return Err(CoreError::new(
                ErrorCode::InternalError,
                "progress stream failed; use fresh transport paths",
            ));
        }
        if !phase.is_allowed_for(self.owner) {
            return Err(CoreError::new(
                ErrorCode::InvalidRequest,
                "progress phase belongs to another owner",
            ));
        }
        let next_sequence = self.next_sequence.checked_add(1).ok_or_else(|| {
            CoreError::new(ErrorCode::InternalError, "progress sequence exhausted")
        })?;
        let event = ProgressEventV1 {
            schema_version: PROGRESS_SCHEMA_VERSION,
            job_id: self.job_id.clone(),
            sequence: self.next_sequence,
            command: self.command,
            phase,
            completed_units,
            total_units,
            unit,
            current_item,
        };
        event.validate_fields()?;
        if let Err(error) = self.sink.write(&event) {
            self.write_failed = true;
            return Err(error);
        }
        self.next_sequence = next_sequence;
        Ok(())
    }
}

pub struct JsonlProgressWriter {
    file: File,
}

impl JsonlProgressWriter {
    pub fn create(path: &Path) -> Result<Self, CoreError> {
        let file = OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(path)
            .map_err(progress_io_error)?;
        Ok(Self { file })
    }
}

impl ProgressSink for JsonlProgressWriter {
    fn write(&mut self, event: &ProgressEventV1) -> Result<(), CoreError> {
        let bytes = encode_contract(event)
            .map_err(|error| CoreError::new(error.code(), error.to_string()))?;
        self.file
            .write_all(&bytes)
            .and_then(|()| self.file.flush())
            .map_err(progress_io_error)
    }
}

fn progress_io_error(error: std::io::Error) -> CoreError {
    let code = if error.kind() == std::io::ErrorKind::StorageFull {
        ErrorCode::OutOfSpace
    } else {
        ErrorCode::InternalError
    };
    CoreError::new(code, format!("progress file I/O failed: {error}"))
}
