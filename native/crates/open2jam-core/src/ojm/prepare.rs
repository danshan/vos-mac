use super::OjmSampleData;
use crate::error::{CoreError, ErrorCode};
use std::io::Cursor;
use symphonia::core::{
    codecs::audio::AudioDecoderOptions,
    formats::{TrackType, probe::Hint},
    io::MediaSourceStream,
};

const MAX_PCM_BYTES: usize = 256 * 1024 * 1024;

impl OjmSampleData<'_> {
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
            return prepare_ogg(encoded, checkpoint);
        };
        if format != 1 || bits_per_sample != 16 {
            return Err(decode_error("unsupported OJM wave encoding"));
        }
        if !(1..=2).contains(&channels)
            || !(1..=384_000).contains(&sample_rate)
            || block_align != channels * 2
            || byte_rate != sample_rate * u32::from(block_align)
            || !pcm.len().is_multiple_of(usize::from(block_align))
            || pcm.is_empty()
            || pcm.len() > MAX_PCM_BYTES
        {
            return Err(decode_error("invalid or oversized OJM PCM payload"));
        }
        let mut wav = Vec::with_capacity(44 + pcm.len());
        wav.extend(b"RIFF");
        wav.extend((36 + pcm.len() as u32).to_le_bytes());
        wav.extend(b"WAVEfmt ");
        wav.extend(16_u32.to_le_bytes());
        wav.extend(1_u16.to_le_bytes());
        wav.extend(channels.to_le_bytes());
        wav.extend(sample_rate.to_le_bytes());
        wav.extend(byte_rate.to_le_bytes());
        wav.extend(block_align.to_le_bytes());
        wav.extend(16_u16.to_le_bytes());
        wav.extend(b"data");
        wav.extend((pcm.len() as u32).to_le_bytes());
        for chunk in pcm.chunks(64 * 1024) {
            checkpoint()?;
            wav.extend(chunk);
        }
        checkpoint()?;
        Ok(wav)
    }
}

fn prepare_ogg(
    encoded: &[u8],
    checkpoint: &mut impl FnMut() -> Result<(), CoreError>,
) -> Result<Vec<u8>, CoreError> {
    if encoded.len() > 64 * 1024 * 1024 {
        return Err(decode_error("encoded Ogg exceeds audio preparation bound"));
    }
    let mut owned = Vec::with_capacity(encoded.len());
    for chunk in encoded.chunks(64 * 1024) {
        checkpoint()?;
        owned.extend_from_slice(chunk);
    }
    let stream = MediaSourceStream::new(Box::new(Cursor::new(owned)), Default::default());
    let mut hint = Hint::new();
    hint.with_extension("ogg");
    let mut format = symphonia::default::get_probe()
        .probe(&hint, stream, Default::default(), Default::default())
        .map_err(codec_error)?;
    let track = format
        .default_track(TrackType::Audio)
        .ok_or_else(|| decode_error("Ogg has no audio track"))?;
    let parameters = track
        .codec_params
        .as_ref()
        .and_then(|parameters| parameters.audio())
        .ok_or_else(|| decode_error("Ogg audio parameters are missing"))?;
    if parameters
        .channels
        .as_ref()
        .is_some_and(|channels| !(1..=2).contains(&channels.count()))
        || parameters
            .sample_rate
            .is_some_and(|rate| !(1..=384_000).contains(&rate))
    {
        return Err(decode_error("unsupported Ogg channel count or sample rate"));
    }
    let mut decoder = symphonia::default::get_codecs()
        .make_audio_decoder(parameters, &AudioDecoderOptions::default())
        .map_err(codec_error)?;
    let track_id = track.id;
    let mut pcm = Vec::new();
    let mut output_spec = None;
    loop {
        checkpoint()?;
        let Some(packet) = format.next_packet().map_err(codec_error)? else {
            break;
        };
        if packet.track_id != track_id {
            continue;
        }
        let decoded = decoder.decode(&packet).map_err(codec_error)?;
        let channels = decoded.spec().channels().count();
        let rate = decoded.spec().rate();
        if !(1..=2).contains(&channels) || !(1..=384_000).contains(&rate) {
            return Err(decode_error("unsupported Ogg channel count or sample rate"));
        }
        let spec = (channels as u16, rate);
        if output_spec.is_some_and(|previous| previous != spec) {
            return Err(decode_error("Ogg audio format changes within sample"));
        }
        output_spec = Some(spec);
        let size = decoded
            .frames()
            .checked_mul(channels * 2)
            .ok_or_else(|| decode_error("decoded Ogg size overflow"))?;
        if size > MAX_PCM_BYTES - pcm.len() {
            return Err(decode_error("decoded Ogg exceeds audio preparation bound"));
        }
        let mut packet_samples: Vec<i16> = Vec::new();
        decoded.copy_to_vec_interleaved(&mut packet_samples);
        for value in packet_samples {
            pcm.extend(value.to_le_bytes());
        }
    }
    let (channels, sample_rate) =
        output_spec.ok_or_else(|| decode_error("Ogg contains no decoded audio"))?;
    OjmSampleData::Wave {
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
        format!("Ogg decode failed: {error}"),
    )
}

fn decode_error(message: &str) -> CoreError {
    CoreError::new(ErrorCode::AudioDecodeFailed, message)
}
