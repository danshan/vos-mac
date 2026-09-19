use std::ffi::OsString;
use std::io::Write;

use open2jam_core::error::{CoreError, ErrorCode, ProtocolError};
use open2jam_core::id::JobId;
use open2jam_core::progress::JsonlProgressWriter;
use open2jam_core::protocol::{
    BundleRequestV1, CatalogOutputV1, CatalogRequestV1, Command, CommandResultV1,
};
use open2jam_core::version::VersionInfo;

use crate::args::{ParsedCommand, parse_args};
use crate::io::{AtomicResultWriter, ResultTempScope, read_request_document, validate_job_files};

pub fn run(
    args: impl IntoIterator<Item = OsString>,
    stdout: &mut dyn Write,
    stderr: &mut dyn Write,
) -> u8 {
    let parsed = match parse_args(args) {
        Ok(value) => value,
        Err(error) => {
            let _ = writeln!(stderr, "{}", error.message());
            return error.exit_code();
        }
    };
    let (command, files) = match parsed {
        ParsedCommand::Version => {
            return match serde_json::to_writer(&mut *stdout, &VersionInfo::current())
                .and_then(|()| stdout.write_all(b"\n").map_err(serde_json::Error::io))
            {
                Ok(()) => 0,
                Err(error) => {
                    let _ = writeln!(stderr, "version output failed: {error}");
                    4
                }
            };
        }
        ParsedCommand::Catalog(files) => (Command::Catalog, files),
        ParsedCommand::Bundle(files) => (Command::Bundle, files),
    };
    let files = match validate_job_files(&files) {
        Ok(files) => files,
        Err(error) => {
            let _ = writeln!(stderr, "{error}");
            return 2;
        }
    };
    let decoded: Result<(JobId, Command, std::path::PathBuf), ProtocolError> = match command {
        Command::Catalog => {
            read_request_document::<CatalogRequestV1>(&files.request).and_then(|mut r| {
                let requested_command = r.command;
                r.command = Command::Catalog;
                r.validate()?;
                Ok((
                    r.job_id,
                    requested_command,
                    r.cancel_marker_path.into_path_buf(),
                ))
            })
        }
        Command::Bundle => {
            read_request_document::<BundleRequestV1>(&files.request).and_then(|mut r| {
                let requested_command = r.command;
                r.command = Command::Bundle;
                r.validate()?;
                Ok((
                    r.job_id,
                    requested_command,
                    r.cancel_marker_path.into_path_buf(),
                ))
            })
        }
    };
    let (scope, result, exit_code) = match decoded {
        Err(error) => {
            let result = CommandResultV1::<CatalogOutputV1>::protocol_failure(
                command,
                CoreError::new(error.code(), "Invalid request document").into(),
            );
            (ResultTempScope::Protocol(command), result, 2)
        }
        Ok((job, requested_command, cancel))
            if requested_command != command || cancel_aliases_transport(&cancel, &files) =>
        {
            let result = CommandResultV1::failed(
                job.clone(),
                command,
                CoreError::new(
                    ErrorCode::InvalidRequest,
                    "Request command or cancellation path conflicts with CLI transport",
                )
                .into(),
            );
            (ResultTempScope::Job(job), result, 2)
        }
        Ok((job, _, _)) => {
            let result = CommandResultV1::failed(
                job.clone(),
                command,
                CoreError::new(
                    ErrorCode::UnsupportedFormat,
                    "No source importer is enabled in protocol phase 1.",
                )
                .into(),
            );
            (ResultTempScope::Job(job), result, 1)
        }
    };
    let writer = match AtomicResultWriter::reserve(&files.result, &scope) {
        Ok(writer) => writer,
        Err(error) => {
            let _ = writeln!(stderr, "{error}");
            return 2;
        }
    };
    if exit_code == 1
        && let Err(error) = JsonlProgressWriter::create(&files.progress)
    {
        let _ = writeln!(stderr, "{error}");
        return 4;
    }
    match writer.publish(&result) {
        Ok(()) => exit_code,
        Err(error) => {
            let _ = writeln!(stderr, "{error}");
            4
        }
    }
}

fn cancel_aliases_transport(cancel: &std::path::Path, files: &crate::args::JobFiles) -> bool {
    let resolved = cancel
        .parent()
        .and_then(|p| p.canonicalize().ok())
        .zip(cancel.file_name())
        .map(|(parent, name)| parent.join(name))
        .unwrap_or_else(|| cancel.to_owned());
    [&files.request, &files.progress, &files.result].contains(&&resolved)
}
