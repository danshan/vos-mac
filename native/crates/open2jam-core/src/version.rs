use serde::{Deserialize, Serialize};

pub const PROTOCOL_SCHEMA_VERSION: u16 = 1;
pub const CATALOG_SCHEMA_VERSION: u16 = 2;
pub const BUNDLE_SCHEMA_VERSION: u16 = 2;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct VersionInfo {
    pub schema_version: u16,
    pub converter_version: String,
    pub protocol_schema_version: u16,
    pub catalog_schema_version: u16,
    pub bundle_schema_version: u16,
    pub catalog_formats: Vec<String>,
    pub bundle_formats: Vec<String>,
}

impl VersionInfo {
    pub fn current() -> Self {
        Self {
            schema_version: 1,
            converter_version: env!("CARGO_PKG_VERSION").to_owned(),
            protocol_schema_version: PROTOCOL_SCHEMA_VERSION,
            catalog_schema_version: CATALOG_SCHEMA_VERSION,
            bundle_schema_version: BUNDLE_SCHEMA_VERSION,
            catalog_formats: Vec::new(),
            bundle_formats: Vec::new(),
        }
    }
}
