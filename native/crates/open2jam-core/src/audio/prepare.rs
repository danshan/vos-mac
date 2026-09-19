use crate::error::{CoreError, ErrorCode};
use std::io::Cursor;
use symphonia::core::{
    codecs::audio::{
        AudioDecoderOptions,
        well_known::{CODEC_ID_MP3, CODEC_ID_VORBIS},
    },
    formats::{TrackType, probe::Hint},
    io::MediaSourceStream,
};

const MAX_PCM_BYTES: usize = 256 * 1024 * 1024;
pub const MAX_AUDIO_FILE_BYTES: usize = 64 * 1024 * 1024;

#[derive(Debug, Clone, Copy)]
pub enum AudioFileFormat {
    Wave,
    Ogg,
    Mp3,
}

pub fn prepare_audio_file(
    encoded: &[u8],
    format: AudioFileFormat,
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<Vec<u8>, CoreError> {
    checkpoint()?;
    if encoded.len() > MAX_AUDIO_FILE_BYTES {
        return Err(decode_error("audio file exceeds preparation bound"));
    }
    match format {
        AudioFileFormat::Mp3 => prepare_compressed(encoded, "mp3", false, checkpoint),
        AudioFileFormat::Ogg => SampleData::Ogg(encoded).prepare_wav(checkpoint),
        AudioFileFormat::Wave => super::wave::parse(encoded, checkpoint)?.prepare_wav(checkpoint),
    }
}

#[derive(Debug, Clone, Copy)]
pub enum SampleData<'a> {
    Wave {
        format: u16,
        channels: u16,
        sample_rate: u32,
        byte_rate: u32,
        block_align: u16,
        bits_per_sample: u16,
        pcm: &'a [u8],
    },
    Ogg(&'a [u8]),
}

impl SampleData<'_> {
    pub fn prepare_wav(
        self,
        checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
    ) -> Result<Vec<u8>, CoreError> {
        checkpoint()?;
        let Self::Wave {
            format,
            channels,
            sample_rate,
            byte_rate,
            block_align,
            bits_per_sample,
            pcm,
        } = self
        else {
            let Self::Ogg(encoded) = self else {
                unreachable!()
            };
            return prepare_compressed(encoded, "ogg", true, checkpoint);
        };
        if !matches!(
            (format, bits_per_sample),
            (1, 8 | 16 | 24 | 32) | (3, 32 | 64) | (6 | 7, 8)
        ) {
            return Err(decode_error("unsupported wave encoding"));
        }
        let width = usize::from(bits_per_sample / 8);
        let output_size = (pcm.len() / width)
            .checked_mul(2)
            .ok_or_else(|| decode_error("PCM output size overflow"))?;
        if !(1..=2).contains(&channels)
            || !(1..=384_000).contains(&sample_rate)
            || block_align != channels * bits_per_sample / 8
            || byte_rate != sample_rate * u32::from(block_align)
            || !pcm.len().is_multiple_of(usize::from(block_align))
            || pcm.is_empty()
            || output_size > MAX_PCM_BYTES
        {
            return Err(decode_error("invalid or oversized PCM payload"));
        }
        let mut wav = Vec::with_capacity(44 + output_size);
        wav.extend(b"RIFF");
        wav.extend((36 + output_size as u32).to_le_bytes());
        wav.extend(b"WAVEfmt ");
        wav.extend(16_u32.to_le_bytes());
        wav.extend(1_u16.to_le_bytes());
        wav.extend(channels.to_le_bytes());
        wav.extend(sample_rate.to_le_bytes());
        wav.extend((sample_rate * u32::from(channels) * 2).to_le_bytes());
        wav.extend((channels * 2).to_le_bytes());
        wav.extend(16_u16.to_le_bytes());
        wav.extend(b"data");
        wav.extend((output_size as u32).to_le_bytes());
        if format == 1 && bits_per_sample == 16 {
            for chunk in pcm.chunks(64 * 1024) {
                checkpoint()?;
                wav.extend(chunk);
            }
        } else {
            for (index, sample) in pcm.chunks_exact(width).enumerate() {
                if index.is_multiple_of(32768) {
                    checkpoint()?;
                }
                let value = match format {
                    1 => integer_sample(sample),
                    3 => float_sample(sample)?,
                    6 => alaw_sample(sample[0]),
                    7 => mulaw_sample(sample[0]),
                    _ => unreachable!("wave format was validated"),
                };
                wav.extend(value.to_le_bytes());
            }
        }
        checkpoint()?;
        Ok(wav)
    }
}

fn integer_sample(bytes: &[u8]) -> i16 {
    // Preserve JavaSound's binary32 normalization and asymmetric signed endpoints.
    let normalized = match bytes {
        [value] => {
            let signed = i16::from(*value) - 128;
            f32::from(signed) / if signed > 0 { 127.0 } else { 128.0 }
        }
        [a, b, c] => {
            let signed = i32::from_le_bytes([0, *a, *b, *c]) >> 8;
            signed as f32 / if signed > 0 { 8_388_607.0 } else { 8_388_608.0 }
        }
        [a, b, c, d] => i32::from_le_bytes([*a, *b, *c, *d]) as f32 * (1.0 / i32::MAX as f32),
        _ => unreachable!("integer PCM width was validated"),
    };
    (normalized * if normalized > 0.0 { 32767.0 } else { 32768.0 }) as i16
}

fn float_sample(bytes: &[u8]) -> Result<i16, CoreError> {
    let value = match bytes {
        [a, b, c, d] => f32::from_le_bytes([*a, *b, *c, *d]),
        [a, b, c, d, e, f, g, h] => f64::from_le_bytes([*a, *b, *c, *d, *e, *f, *g, *h]) as f32,
        _ => unreachable!("float PCM width was validated"),
    };
    if !value.is_finite() {
        return Err(decode_error("non-finite floating-point audio sample"));
    }
    // Java narrows through int before short, including finite samples outside [-1, 1].
    Ok((value * if value > 0.0 { 32767.0 } else { 32768.0 }) as i32 as i16)
}

fn alaw_sample(value: u8) -> i16 {
    let value = value ^ 0x55;
    let segment = (value & 0x70) >> 4;
    let mantissa = i16::from(value & 15) << 4;
    let magnitude = if segment == 0 {
        mantissa + 8
    } else {
        (mantissa + 0x108) << (segment - 1)
    };
    if value & 0x80 != 0 {
        magnitude
    } else {
        -magnitude
    }
}

fn mulaw_sample(value: u8) -> i16 {
    let value = !value;
    let magnitude = ((i16::from(value & 15) << 3) + 0x84) << ((value & 0x70) >> 4);
    if value & 0x80 != 0 {
        0x84 - magnitude
    } else {
        magnitude - 0x84
    }
}

fn prepare_compressed(
    encoded: &[u8],
    extension: &str,
    gapless: bool,
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<Vec<u8>, CoreError> {
    if encoded.len() > MAX_AUDIO_FILE_BYTES {
        return Err(decode_error(
            "encoded compressed audio exceeds audio preparation bound",
        ));
    }
    let mut mp3 = if extension == "mp3" {
        Some(super::mp3::Mp3Frames::new(encoded, checkpoint)?)
    } else {
        None
    };
    let mut owned = Vec::with_capacity(encoded.len());
    for chunk in encoded.chunks(64 * 1024) {
        checkpoint()?;
        owned.extend_from_slice(chunk);
    }
    let stream = MediaSourceStream::new(Box::new(Cursor::new(owned)), Default::default());
    let mut hint = Hint::new();
    hint.with_extension(extension);
    let mut format = symphonia::default::get_probe()
        .probe(&hint, stream, Default::default(), Default::default())
        .map_err(codec_error)?;
    let track = format
        .default_track(TrackType::Audio)
        .ok_or_else(|| decode_error("compressed audio has no audio track"))?;
    let parameters = track
        .codec_params
        .as_ref()
        .and_then(|parameters| parameters.audio())
        .ok_or_else(|| decode_error("compressed audio parameters are missing"))?;
    if parameters.codec
        != if extension == "mp3" {
            CODEC_ID_MP3
        } else {
            CODEC_ID_VORBIS
        }
    {
        return Err(decode_error(
            "audio codec does not match the selected format",
        ));
    }
    if parameters
        .channels
        .as_ref()
        .is_some_and(|channels| !(1..=2).contains(&channels.count()))
        || parameters
            .sample_rate
            .is_some_and(|rate| !(1..=384_000).contains(&rate))
    {
        return Err(decode_error(
            "unsupported compressed audio channel count or sample rate",
        ));
    }
    let mut decoder = symphonia::default::get_codecs()
        .make_audio_decoder(parameters, &AudioDecoderOptions::default().gapless(gapless))
        .map_err(codec_error)?;
    let track_id = track.id;
    let mut pcm = Vec::new();
    let mut output_spec = None;
    loop {
        checkpoint()?;
        let packet = if let Some(frames) = &mut mp3 {
            frames.next(track_id)?
        } else {
            format.next_packet().map_err(codec_error)?
        };
        let Some(packet) = packet else {
            break;
        };
        if packet.track_id != track_id {
            continue;
        }
        let decoded = decoder.decode(&packet).map_err(codec_error)?;
        let channels = decoded.spec().channels().count();
        let rate = decoded.spec().rate();
        if !(1..=2).contains(&channels) || !(1..=384_000).contains(&rate) {
            return Err(decode_error(
                "unsupported compressed audio channel count or sample rate",
            ));
        }
        let spec = (channels as u16, rate);
        if output_spec.is_some_and(|previous| previous != spec) {
            return Err(decode_error(
                "compressed audio format changes within sample",
            ));
        }
        output_spec = Some(spec);
        let size = decoded
            .frames()
            .checked_mul(channels * 2)
            .ok_or_else(|| decode_error("decoded compressed audio size overflow"))?;
        if size > MAX_PCM_BYTES - pcm.len() {
            return Err(decode_error(
                "decoded compressed audio exceeds audio preparation bound",
            ));
        }
        let mut packet_samples: Vec<i16> = Vec::new();
        decoded.copy_to_vec_interleaved(&mut packet_samples);
        for value in packet_samples {
            pcm.extend(value.to_le_bytes());
        }
    }
    let (channels, sample_rate) =
        output_spec.ok_or_else(|| decode_error("compressed audio contains no decoded audio"))?;
    SampleData::Wave {
        format: 1,
        channels,
        sample_rate,
        byte_rate: sample_rate * u32::from(channels) * 2,
        block_align: channels * 2,
        bits_per_sample: 16,
        pcm: &pcm,
    }
    .prepare_wav(checkpoint)
}

fn codec_error(error: symphonia::core::errors::Error) -> CoreError {
    CoreError::new(
        ErrorCode::AudioDecodeFailed,
        format!("compressed audio decode failed: {error}"),
    )
}

fn decode_error(message: &str) -> CoreError {
    CoreError::new(ErrorCode::AudioDecodeFailed, message)
}
