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

digest_id!(LibraryRootId, "library:");

use crate::canonical::CanonicalHasher;
use crate::format::SourceKind;
use crate::path::SourceRelativePath;
use crate::protocol::ChartSelector;

pub fn derive_source_id(kind: SourceKind, source: &SourceFingerprint) -> SourceId {
    let mut hash = CanonicalHasher::new(b"open2jam.source-id.v1\0");
    hash.write_u16(match kind {
        SourceKind::Vos => 1,
        SourceKind::Ojn => 2,
        SourceKind::Osu => 3,
        SourceKind::Osz => 4,
        SourceKind::BundleV2 => 5,
    });
    hash.write_bytes(source.digest().as_bytes());
    SourceId::from_digest(hash.finish())
}

pub fn derive_sample_id(content: &Digest) -> SampleId {
    let mut hash = CanonicalHasher::new(b"open2jam.sample-id.v1\0");
    hash.write_bytes(content.as_bytes());
    SampleId::from_digest(hash.finish())
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "SongIdentityWire", into = "SongIdentityWire")]
pub struct SongIdentity(SongIdentityWire);

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "kind",
    rename_all = "SCREAMING_SNAKE_CASE",
    rename_all_fields = "camelCase",
    deny_unknown_fields
)]
enum SongIdentityWire {
    Vos {
        root_id: LibraryRootId,
        package_path: SourceRelativePath,
    },
    OjnFile {
        root_id: LibraryRootId,
        file_path: SourceRelativePath,
    },
    OsuBeatmapSet {
        root_id: LibraryRootId,
        package_path: SourceRelativePath,
    },
    OszPackage {
        root_id: LibraryRootId,
        package_path: SourceRelativePath,
    },
    BundleDeclared {
        song_id: SongId,
    },
}

impl SongIdentity {
    pub fn vos(root_id: LibraryRootId, package_path: SourceRelativePath) -> Self {
        Self(SongIdentityWire::Vos {
            root_id,
            package_path,
        })
    }
    pub fn ojn_file(root_id: LibraryRootId, file_path: SourceRelativePath) -> Self {
        Self(SongIdentityWire::OjnFile { root_id, file_path })
    }
    pub fn osu_beatmap_set(root_id: LibraryRootId, package_path: SourceRelativePath) -> Self {
        Self(SongIdentityWire::OsuBeatmapSet {
            root_id,
            package_path,
        })
    }
    pub fn osz_package(root_id: LibraryRootId, package_path: SourceRelativePath) -> Self {
        Self(SongIdentityWire::OszPackage {
            root_id,
            package_path,
        })
    }
    pub fn bundle_declared(song_id: SongId) -> Self {
        Self(SongIdentityWire::BundleDeclared { song_id })
    }
    pub fn song_id(&self) -> SongId {
        let (tag, root, path) = match &self.0 {
            SongIdentityWire::Vos {
                root_id,
                package_path,
            } => (1, root_id, package_path),
            SongIdentityWire::OjnFile { root_id, file_path } => (2, root_id, file_path),
            SongIdentityWire::OsuBeatmapSet {
                root_id,
                package_path,
            } => (3, root_id, package_path),
            SongIdentityWire::OszPackage {
                root_id,
                package_path,
            } => (4, root_id, package_path),
            SongIdentityWire::BundleDeclared { song_id } => return *song_id,
        };
        let mut hash = CanonicalHasher::new(b"open2jam.song-id.v2\0");
        hash.write_u16(crate::schema::ID_ALGORITHM_VERSION);
        hash.write_bytes(root.digest().as_bytes());
        hash.write_u16(tag);
        hash.write_str(path.as_str());
        SongId::from_digest(hash.finish())
    }
}
impl TryFrom<SongIdentityWire> for SongIdentity {
    type Error = CoreError;
    fn try_from(wire: SongIdentityWire) -> Result<Self, Self::Error> {
        Ok(match wire {
            SongIdentityWire::Vos {
                root_id,
                package_path,
            } => Self::vos(root_id, package_path),
            SongIdentityWire::OjnFile { root_id, file_path } => Self::ojn_file(root_id, file_path),
            SongIdentityWire::OsuBeatmapSet {
                root_id,
                package_path,
            } => Self::osu_beatmap_set(root_id, package_path),
            SongIdentityWire::OszPackage {
                root_id,
                package_path,
            } => Self::osz_package(root_id, package_path),
            SongIdentityWire::BundleDeclared { song_id } => Self::bundle_declared(song_id),
        })
    }
}
impl From<SongIdentity> for SongIdentityWire {
    fn from(value: SongIdentity) -> Self {
        value.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "ChartIdentityWire", into = "ChartIdentityWire")]
pub struct ChartIdentity(ChartIdentityWire);

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "kind",
    rename_all = "SCREAMING_SNAKE_CASE",
    rename_all_fields = "camelCase",
    deny_unknown_fields
)]
enum ChartIdentityWire {
    Vos { index: u8 },
    Ojn { index: u8 },
    Osu { relative_path: SourceRelativePath },
    BundleDeclared { chart_id: ChartId },
}
impl ChartIdentity {
    pub fn vos(index: u8) -> Result<Self, CoreError> {
        if index != 0 {
            return Err(CoreError::new(
                ErrorCode::InvalidRequest,
                "VOS has only chart index zero",
            ));
        }
        Ok(Self(ChartIdentityWire::Vos { index }))
    }
    pub fn ojn(index: u8) -> Result<Self, CoreError> {
        if index > 2 {
            return Err(CoreError::new(
                ErrorCode::InvalidRequest,
                "OJN chart index exceeds two",
            ));
        }
        Ok(Self(ChartIdentityWire::Ojn { index }))
    }
    pub fn osu(relative_path: SourceRelativePath) -> Self {
        Self(ChartIdentityWire::Osu { relative_path })
    }
    pub fn bundle_declared(chart_id: ChartId) -> Self {
        Self(ChartIdentityWire::BundleDeclared { chart_id })
    }
    pub fn from_selector(selector: ChartSelector) -> Result<Self, CoreError> {
        match selector {
            ChartSelector::VosChart { index } => Self::vos(index),
            ChartSelector::OjnChart { index } => Self::ojn(index),
            ChartSelector::OsuBeatmap { relative_path } => Ok(Self::osu(relative_path)),
            ChartSelector::BundleChart { chart_id } => Ok(Self::bundle_declared(chart_id)),
        }
    }
    pub fn selector(&self) -> ChartSelector {
        match &self.0 {
            ChartIdentityWire::Vos { index } => ChartSelector::VosChart { index: *index },
            ChartIdentityWire::Ojn { index } => ChartSelector::OjnChart { index: *index },
            ChartIdentityWire::Osu { relative_path } => ChartSelector::OsuBeatmap {
                relative_path: relative_path.clone(),
            },
            ChartIdentityWire::BundleDeclared { chart_id } => ChartSelector::BundleChart {
                chart_id: *chart_id,
            },
        }
    }
    pub fn chart_id(&self, song: &SongId) -> ChartId {
        let mut hash = CanonicalHasher::new(b"open2jam.chart-id.v2\0");
        hash.write_u16(crate::schema::ID_ALGORITHM_VERSION);
        hash.write_bytes(song.digest().as_bytes());
        match &self.0 {
            ChartIdentityWire::Vos { index } => {
                hash.write_u16(1);
                hash.write_u16(u16::from(*index));
            }
            ChartIdentityWire::Ojn { index } => {
                hash.write_u16(2);
                hash.write_u16(u16::from(*index));
            }
            ChartIdentityWire::Osu { relative_path } => {
                hash.write_u16(3);
                hash.write_str(relative_path.as_str());
            }
            ChartIdentityWire::BundleDeclared { chart_id } => return *chart_id,
        }
        ChartId::from_digest(hash.finish())
    }
}
impl TryFrom<ChartIdentityWire> for ChartIdentity {
    type Error = CoreError;
    fn try_from(wire: ChartIdentityWire) -> Result<Self, Self::Error> {
        match wire {
            ChartIdentityWire::Vos { index } => Self::vos(index),
            ChartIdentityWire::Ojn { index } => Self::ojn(index),
            ChartIdentityWire::Osu { relative_path } => Ok(Self::osu(relative_path)),
            ChartIdentityWire::BundleDeclared { chart_id } => Ok(Self::bundle_declared(chart_id)),
        }
    }
}
impl From<ChartIdentity> for ChartIdentityWire {
    fn from(value: ChartIdentity) -> Self {
        value.0
    }
}
