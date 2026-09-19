use sha2::{Digest as _, Sha256};

use crate::digest::Digest;

pub struct CanonicalHasher(Sha256);

impl CanonicalHasher {
    pub fn new(domain: &[u8]) -> Self {
        let mut hash = Sha256::new();
        hash.update(domain);
        Self(hash)
    }
    pub fn write_u16(&mut self, value: u16) {
        self.0.update(value.to_be_bytes());
    }
    pub fn write_u32(&mut self, value: u32) {
        self.0.update(value.to_be_bytes());
    }
    pub fn write_u64(&mut self, value: u64) {
        self.0.update(value.to_be_bytes());
    }
    pub fn write_bytes(&mut self, value: &[u8]) {
        self.write_u64(value.len() as u64);
        self.0.update(value);
    }
    pub fn write_str(&mut self, value: &str) {
        self.write_bytes(value.as_bytes());
    }
    pub fn finish(self) -> Digest {
        Digest::from_bytes(self.0.finalize().into())
    }
}
