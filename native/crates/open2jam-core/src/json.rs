use serde::{Deserialize, Serialize, de::DeserializeOwned};

use crate::error::{CoreError, ErrorCode, ProtocolError};

pub trait Contract: Serialize + DeserializeOwned {
    const SCHEMA_VERSION: u16;
    fn validate(&self) -> Result<(), ProtocolError>;
}

pub fn decode_contract<T: Contract>(bytes: &[u8]) -> Result<T, ProtocolError> {
    // Invariant-bearing DTOs reject incompatible schemas during Deserialize. Inspect
    // the header first so serde cannot erase the stable unsupported-schema error code.
    #[derive(Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct Header {
        schema_version: u16,
    }
    let header: Header = serde_json::from_slice(bytes).map_err(|source| ProtocolError::Json {
        code: ErrorCode::InvalidRequest,
        source,
    })?;
    if header.schema_version != T::SCHEMA_VERSION {
        return Err(
            CoreError::new(ErrorCode::UnsupportedSchema, "unsupported schema version").into(),
        );
    }
    // Deserialize directly into the DTO so duplicate fields cannot be lost in a Value map.
    let value: T = serde_json::from_slice(bytes).map_err(|source| ProtocolError::Json {
        code: ErrorCode::InvalidRequest,
        source,
    })?;
    value.validate()?;
    Ok(value)
}

pub fn encode_contract<T: Contract>(value: &T) -> Result<Vec<u8>, ProtocolError> {
    value.validate()?;
    let mut bytes = serde_json::to_vec(value).map_err(|source| ProtocolError::Json {
        code: ErrorCode::InvalidRequest,
        source,
    })?;
    bytes.push(b'\n');
    Ok(bytes)
}
