use crate::{
    error::{CoreError, ErrorCode},
    path::SourceRelativePath,
};
use std::{
    collections::BTreeMap,
    io::{self, Cursor, Read, Seek, SeekFrom},
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
};
use zip::{CompressionMethod, ZipArchive};

pub const MAX_ARCHIVE_BYTES: usize = 512 * 1024 * 1024;
pub const MAX_ENTRY_BYTES: u64 = 64 * 1024 * 1024;
const MAX_ENTRIES: u64 = 8192;
const MAX_DIRECTORY_BYTES: u64 = 16 * 1024 * 1024;
const MAX_EXPANDED_BYTES: u64 = 1024 * 1024 * 1024;
const MAX_COMPRESSION_RATIO: u64 = 1000;

pub struct OszArchive<'a> {
    archive: ZipArchive<PinnedDirectoryReader<'a>>,
    files: BTreeMap<SourceRelativePath, usize>,
    remaining_bytes: u64,
}

impl<'a> OszArchive<'a> {
    pub fn open(
        bytes: &'a [u8],
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<Self, CoreError> {
        checkpoint()?;
        let directory = preflight(bytes)?;
        let metadata_only = Arc::new(AtomicBool::new(true));
        let reader = PinnedDirectoryReader {
            inner: Cursor::new(bytes),
            end: directory.end,
            zip64: directory.zip64,
            metadata_only: metadata_only.clone(),
            rejected: false,
        };
        let mut archive = ZipArchive::with_config(
            zip::read::Config {
                archive_offset: zip::read::ArchiveOffset::Known(0),
            },
            reader,
        )
        .map_err(zip_error)?;
        metadata_only.store(false, Ordering::Relaxed);
        checkpoint()?;
        if archive.len() as u64 != directory.count || archive.offset() != 0 {
            return Err(corrupt(
                "duplicate archive entries or unsupported archive offset",
            ));
        }
        let mut files = BTreeMap::new();
        let mut total = 0_u64;
        for index in 0..archive.len() {
            checkpoint()?;
            let file = archive.by_index_raw(index).map_err(zip_error)?;
            let raw_name = std::str::from_utf8(file.name_raw())
                .map_err(|_| corrupt("archive entry name is not UTF-8"))?;
            let name = raw_name.strip_suffix('/').unwrap_or(raw_name);
            if name.len() > 4096 || file.is_symlink() || file.encrypted() {
                return Err(corrupt("unsafe or encrypted archive entry"));
            }
            let path = SourceRelativePath::parse(name)
                .map_err(|_| corrupt("unsafe archive entry path"))?;
            let mode = file.unix_mode().unwrap_or(0) & 0o170000;
            if !matches!(mode, 0 | 0o100000 | 0o040000) || (mode == 0o040000 && !file.is_dir()) {
                return Err(corrupt("archive entry is not a regular file or directory"));
            }
            if !matches!(
                file.compression(),
                CompressionMethod::Stored | CompressionMethod::Deflated
            ) {
                return Err(CoreError::new(
                    ErrorCode::UnsupportedFormat,
                    "unsupported OSZ compression method",
                ));
            }
            total = total
                .checked_add(file.size())
                .ok_or_else(|| corrupt("archive size overflow"))?;
            if file.size() > MAX_ENTRY_BYTES
                || total > MAX_EXPANDED_BYTES
                || file.size() > file.compressed_size().saturating_mul(MAX_COMPRESSION_RATIO)
                || (file.is_dir() && file.size() != 0)
            {
                return Err(corrupt("archive entry exceeds resource limits"));
            }
            if !file.is_dir() {
                files.insert(path, index);
            }
        }
        Ok(Self {
            archive,
            files,
            remaining_bytes: MAX_EXPANDED_BYTES,
        })
    }

    pub fn chart_paths(&self) -> impl Iterator<Item = &SourceRelativePath> {
        self.files.keys().filter(|path| {
            path.as_str()
                .rsplit_once('.')
                .is_some_and(|(_, extension)| extension.eq_ignore_ascii_case("osu"))
        })
    }

    pub fn resolve_audio(
        &self,
        chart: &SourceRelativePath,
        reference: &SourceRelativePath,
    ) -> Result<SourceRelativePath, CoreError> {
        if self.files.contains_key(reference) {
            return Ok(reference.clone());
        }
        if let Some((parent, _)) = chart.as_str().rsplit_once('/') {
            let relative = SourceRelativePath::parse(&format!("{parent}/{}", reference.as_str()))?;
            if self.files.contains_key(&relative) {
                return Ok(relative);
            }
        }
        let mut matches = self.files.keys().filter(|path| {
            path.as_str()
                .rsplit('/')
                .next()
                .unwrap()
                .eq_ignore_ascii_case(reference.as_str())
        });
        match (matches.next(), matches.next()) {
            (Some(path), None) => Ok(path.clone()),
            (None, _) => Err(CoreError::new(
                ErrorCode::MissingAsset,
                "OSZ audio reference has no matching entry",
            )),
            _ => Err(CoreError::new(
                ErrorCode::MissingAsset,
                "OSZ audio reference is ambiguous",
            )),
        }
    }

    pub fn read(
        &mut self,
        path: &SourceRelativePath,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<Vec<u8>, CoreError> {
        checkpoint()?;
        let index = *self
            .files
            .get(path)
            .ok_or_else(|| CoreError::new(ErrorCode::MissingAsset, "OSZ entry is missing"))?;
        let mut file = self.archive.by_index(index).map_err(zip_error)?;
        let declared = file.size();
        let mut bytes = Vec::new();
        let mut buffer = [0; 65536];
        loop {
            checkpoint()?;
            let length = file.read(&mut buffer).map_err(zip_error)?;
            if length == 0 {
                break;
            }
            if bytes.len() as u64 + length as u64 > declared || length as u64 > self.remaining_bytes
            {
                return Err(corrupt("archive read exceeds its resource limits"));
            }
            self.remaining_bytes -= length as u64;
            bytes.extend_from_slice(&buffer[..length]);
        }
        if bytes.len() as u64 != declared {
            return Err(corrupt("archive entry length mismatch"));
        }
        Ok(bytes)
    }
}

fn corrupt(message: &str) -> CoreError {
    CoreError::new(ErrorCode::CorruptChart, message)
}
fn zip_error(error: impl std::fmt::Display) -> CoreError {
    corrupt(&format!("invalid OSZ archive: {error}"))
}

// Bound the central directory before the ZIP library allocates its entry table.
fn preflight(bytes: &[u8]) -> Result<DirectoryBounds, CoreError> {
    if bytes.len() > MAX_ARCHIVE_BYTES || bytes.len() < 22 {
        return Err(corrupt("archive size exceeds bounds"));
    }
    let first = bytes.len().saturating_sub(22 + u16::MAX as usize);
    let end = (first..=bytes.len() - 22)
        .rev()
        .find(|&at| {
            bytes[at..at + 4] == *b"PK\x05\x06"
                && at + 22 + u16_at(bytes, at + 20) as usize == bytes.len()
        })
        .ok_or_else(|| corrupt("archive end record is missing"))?;
    if u16_at(bytes, end + 4) != 0
        || u16_at(bytes, end + 6) != 0
        || u16_at(bytes, end + 8) != u16_at(bytes, end + 10)
    {
        return Err(corrupt("multi-disk archive is unsupported"));
    }
    let mut count = u16_at(bytes, end + 10) as u64;
    let mut size = u32_at(bytes, end + 12) as u64;
    let mut start = u32_at(bytes, end + 16) as u64;
    let mut directory_end = end as u64;
    let mut zip64 = None;
    if count == u16::MAX as u64 || size == u32::MAX as u64 || start == u32::MAX as u64 {
        let locator = end
            .checked_sub(20)
            .ok_or_else(|| corrupt("ZIP64 locator is missing"))?;
        if bytes[locator..locator + 4] != *b"PK\x06\x07"
            || u32_at(bytes, locator + 4) != 0
            || u32_at(bytes, locator + 16) != 1
        {
            return Err(corrupt("invalid ZIP64 locator"));
        }
        let record = usize::try_from(u64_at(bytes, locator + 8)).map_err(zip_error)?;
        if locator < 56
            || record > locator - 56
            || bytes.get(record..record + 4) != Some(b"PK\x06\x06")
        {
            return Err(corrupt("invalid ZIP64 end record"));
        }
        if u64_at(bytes, record + 4) > MAX_DIRECTORY_BYTES
            || u64_at(bytes, record + 4).checked_add(record as u64 + 12) != Some(locator as u64)
            || u32_at(bytes, record + 16) != 0
            || u32_at(bytes, record + 20) != 0
            || u64_at(bytes, record + 24) != u64_at(bytes, record + 32)
        {
            return Err(corrupt("invalid ZIP64 directory bounds"));
        }
        count = u64_at(bytes, record + 32);
        size = u64_at(bytes, record + 40);
        start = u64_at(bytes, record + 48);
        directory_end = record as u64;
        zip64 = Some(record as u64);
    }
    if count > MAX_ENTRIES
        || size > MAX_DIRECTORY_BYTES
        || start.checked_add(size) != Some(directory_end)
    {
        return Err(corrupt("archive directory exceeds bounds"));
    }
    Ok(DirectoryBounds {
        count,
        end: end as u64,
        zip64,
    })
}
fn u16_at(bytes: &[u8], at: usize) -> u16 {
    u16::from_le_bytes(bytes[at..at + 2].try_into().unwrap())
}
fn u32_at(bytes: &[u8], at: usize) -> u32 {
    u32::from_le_bytes(bytes[at..at + 4].try_into().unwrap())
}
fn u64_at(bytes: &[u8], at: usize) -> u64 {
    u64::from_le_bytes(bytes[at..at + 8].try_into().unwrap())
}

struct DirectoryBounds {
    count: u64,
    end: u64,
    zip64: Option<u64>,
}

// zip 8.6 can retry earlier EOCD records after a metadata error. Only the records
// whose allocation bounds were checked above may be parsed during construction.
struct PinnedDirectoryReader<'a> {
    inner: Cursor<&'a [u8]>,
    end: u64,
    zip64: Option<u64>,
    metadata_only: Arc<AtomicBool>,
    rejected: bool,
}

impl Read for PinnedDirectoryReader<'_> {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        if self.rejected {
            return Err(io::Error::other("unapproved archive directory"));
        }
        self.inner.read(buffer)
    }
}

impl Seek for PinnedDirectoryReader<'_> {
    fn seek(&mut self, from: SeekFrom) -> io::Result<u64> {
        if self.rejected {
            return Err(io::Error::other("unapproved archive directory"));
        }
        let position = self.inner.seek(from)?;
        if self.metadata_only.load(Ordering::Relaxed) {
            let signature = usize::try_from(position).ok().and_then(|at| {
                at.checked_add(4)
                    .and_then(|end| self.inner.get_ref().get(at..end))
            });
            if (signature == Some(b"PK\x05\x06") && position != self.end)
                || (signature == Some(b"PK\x06\x06") && Some(position) != self.zip64)
            {
                self.rejected = true;
                return Err(io::Error::other("unapproved archive directory"));
            }
        }
        Ok(position)
    }
}
