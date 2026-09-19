use crate::error::{CoreError, ErrorCode};
use symphonia::core::{
    packet::Packet,
    units::{Duration, Timestamp},
};

// Feed every MPEG frame to the decoder. JavaSound includes Xing/Info/VBRI frames;
// the normal Symphonia demuxer removes them and would shift the legacy timeline.
pub(super) struct Mp3Frames<'a> {
    bytes: &'a [u8],
}

impl<'a> Mp3Frames<'a> {
    pub fn new(
        mut bytes: &'a [u8],
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<Self, CoreError> {
        while bytes.starts_with(b"ID3") {
            checkpoint()?;
            if bytes.len() < 10
                || !(2..=4).contains(&bytes[3])
                || bytes[6..10].iter().any(|b| b & 128 != 0)
            {
                return Err(invalid("invalid MP3 ID3 header"));
            }
            let size = bytes[6..10]
                .iter()
                .fold(0_usize, |size, b| (size << 7) | usize::from(*b));
            let footer = if bytes[3] == 4 && bytes[5] & 16 != 0 {
                10
            } else {
                0
            };
            let end = 10 + size + footer;
            if end > bytes.len() || (footer != 0 && &bytes[end - 10..end - 7] != b"3DI") {
                return Err(invalid("truncated MP3 ID3 tag"));
            }
            bytes = &bytes[end..];
        }
        if bytes.len() >= 128 && &bytes[bytes.len() - 128..bytes.len() - 125] == b"TAG" {
            bytes = &bytes[..bytes.len() - 128];
        }
        Ok(Self { bytes })
    }

    pub fn next(&mut self, track_id: u32) -> Result<Option<Packet>, CoreError> {
        if self.bytes.is_empty() {
            return Ok(None);
        }
        let header: [u8; 4] = self
            .bytes
            .get(..4)
            .ok_or_else(|| invalid("truncated MP3 frame header"))?
            .try_into()
            .unwrap();
        let header = u32::from_be_bytes(header);
        let version = (header >> 19) & 3;
        let bitrate = ((header >> 12) & 15) as usize;
        let rate = ((header >> 10) & 3) as usize;
        if header & 0xffe0_0000 != 0xffe0_0000
            || version == 1
            || (header >> 17) & 3 != 1
            || bitrate == 0
            || bitrate == 15
            || rate == 3
        {
            return Err(invalid("invalid or unsupported MP3 frame header"));
        }
        let rates = if version == 3 {
            [
                0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320,
            ]
        } else {
            [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
        };
        let sample_rate = [44100, 48000, 32000][rate]
            / match version {
                3 => 1,
                2 => 2,
                _ => 4,
            };
        let size = ((if version == 3 { 144000 } else { 72000 }) * rates[bitrate] / sample_rate
            + ((header >> 9) & 1)) as usize;
        let frame = self
            .bytes
            .get(..size)
            .ok_or_else(|| invalid("truncated MP3 frame payload"))?;
        self.bytes = &self.bytes[size..];
        Ok(Some(Packet::new(
            track_id,
            Timestamp::ZERO,
            Duration::from(if version == 3 { 1152_u32 } else { 576 }),
            frame,
        )))
    }
}

fn invalid(message: &str) -> CoreError {
    CoreError::new(ErrorCode::AudioDecodeFailed, message)
}
