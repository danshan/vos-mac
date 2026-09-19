use serde::{Serialize, de::DeserializeOwned};

use crate::error::{ErrorCode, ProtocolError};

pub trait Contract: Serialize + DeserializeOwned {
    fn validate(&self) -> Result<(), ProtocolError>;
}

pub fn decode_contract<T: Contract>(bytes: &[u8]) -> Result<T, ProtocolError> {
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
