#![forbid(unsafe_code)]

use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{Cursor, Read, Write};
use std::path::Path;
use std::sync::Arc;
use std::time::Instant;

use rustysynth::{SoundFont, Synthesizer, SynthesizerSettings};
use serde::Deserialize;
use serde_json::json;
use sha2::{Digest, Sha256};

const RATE: u64 = 44_100;
const FONT_HASH: &str = "9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe";

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Sample {
    division: u64,
    end_tick: u64,
    events: Vec<Event>,
}

#[derive(Deserialize)]
struct Event {
    tick: u64,
    #[serde(flatten)]
    message: Message,
}

#[derive(Clone, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
enum Message {
    Tempo {
        micros_per_quarter: u64,
    },
    Midi {
        channel: u8,
        command: u8,
        data1: u8,
        data2: u8,
    },
}

fn read_bounded(path: &Path, limit: u64) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let mut bytes = Vec::new();
    File::open(path)?.take(limit + 1).read_to_end(&mut bytes)?;
    if bytes.len() as u64 > limit {
        return Err("prototype input exceeds its resource limit".into());
    }
    Ok(bytes)
}

struct ScheduledSample {
    events: Vec<(u64, Message)>,
    frames: u64,
}

fn schedule(sample: &mut Sample) -> Result<ScheduledSample, Box<dyn std::error::Error>> {
    if sample.division == 0 || sample.division > 96_000 || sample.events.len() > 65_536 {
        return Err("invalid division or too many events for prototype".into());
    }
    if sample.end_tick > sample.division * 4096 {
        return Err("sequence outside prototype tick limit".into());
    }
    sample
        .events
        .sort_by_key(|event| (event.tick, !matches!(event.message, Message::Tempo { .. })));
    let mut tick = 0;
    let mut micros = 0_u64;
    let mut tempo = 500_000;
    let mut end = 0;
    let mut active = HashMap::new();
    let mut scheduled = Vec::new();
    for event in &sample.events {
        if event.tick > sample.end_tick {
            return Err("event outside bounded prototype sequence".into());
        }
        micros += (event.tick - tick) * tempo / sample.division;
        tick = event.tick;
        let mut send = micros;
        match event.message {
            Message::Tempo { micros_per_quarter } => {
                if !(1..=2_000_000).contains(&micros_per_quarter) {
                    return Err("tempo outside prototype range".into());
                }
                tempo = micros_per_quarter;
            }
            Message::Midi {
                channel,
                command,
                data1,
                data2,
            } => {
                if channel > 15
                    || data1 > 127
                    || data2 > 127
                    || ![0x80, 0x90, 0xB0, 0xC0, 0xE0].contains(&command)
                {
                    return Err("unsupported or invalid prototype MIDI message".into());
                }
                let key = (channel, data1);
                if command == 0x90 && data2 > 0 {
                    active.insert(key, micros);
                } else if (command == 0x80 || command == 0x90)
                    && let Some(start) = active.remove(&key)
                {
                    send = send.max(start + 60_000);
                }
                scheduled.push((send * RATE / 1_000_000, event.message.clone()));
            }
        }
        end = end.max(send);
    }
    let sequence_end = micros + (sample.end_tick - tick) * tempo / sample.division;
    let frames = (end.max(sequence_end) + 500_000) * RATE / 1_000_000;
    if frames > RATE * 600 {
        return Err("sample exceeds prototype 600 second limit".into());
    }
    scheduled.sort_by_key(|event| event.0);
    Ok(ScheduledSample {
        events: scheduled,
        frames,
    })
}

fn wav_header(file: &mut File, frames: u64) -> std::io::Result<()> {
    let size = (frames * 4) as u32;
    file.write_all(b"RIFF")?;
    file.write_all(&(36 + size).to_le_bytes())?;
    file.write_all(b"WAVEfmt ")?;
    file.write_all(&16_u32.to_le_bytes())?;
    file.write_all(&1_u16.to_le_bytes())?;
    file.write_all(&2_u16.to_le_bytes())?;
    file.write_all(&(RATE as u32).to_le_bytes())?;
    file.write_all(&(RATE as u32 * 4).to_le_bytes())?;
    file.write_all(&4_u16.to_le_bytes())?;
    file.write_all(&16_u16.to_le_bytes())?;
    file.write_all(b"data")?;
    file.write_all(&size.to_le_bytes())
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() != 3 {
        return Err("usage: vos-synth-probe SOUNDFONT REQUEST_JSON NEW_OUTPUT_DIRECTORY".into());
    }
    let started = Instant::now();
    let font_bytes = read_bounded(Path::new(&args[0]), 33_000_000)?;
    if format!("{:x}", Sha256::digest(&font_bytes)) != FONT_HASH {
        return Err("SoundFont hash differs from accepted contract".into());
    }
    let font = Arc::new(SoundFont::new(&mut Cursor::new(font_bytes))?);
    let font_seconds = started.elapsed().as_secs_f64();
    let request = read_bounded(Path::new(&args[1]), 10_000_000)?;
    let mut samples: Vec<Sample> = serde_json::from_slice(&request)?;
    if samples.is_empty() || samples.len() > 1024 {
        return Err("prototype requires 1..1024 samples".into());
    }
    let schedules: Vec<_> = samples.iter_mut().map(schedule).collect::<Result<_, _>>()?;
    let total_frames: u64 = schedules.iter().map(|sample| sample.frames).sum();
    if total_frames * 4 > 2_000_000_000 {
        return Err("prototype output exceeds 2 GB limit".into());
    }
    let directory = Path::new(&args[2]);
    fs::create_dir(directory)?;
    let mut settings = SynthesizerSettings::new(RATE as i32);
    settings.block_size = 64;
    settings.maximum_polyphony = 64;
    settings.enable_reverb_and_chorus = true;
    let mut report = Vec::new();
    for (index, ScheduledSample { events, frames }) in schedules.into_iter().enumerate() {
        // A fresh synthesizer prevents prior samples from affecting the result.
        let mut synth = Synthesizer::new(&font, &settings)?;
        synth.set_master_volume(0.5);
        let mut file = File::create(directory.join(format!("{index}.wav")))?;
        wav_header(&mut file, frames)?;
        let mut event_index = 0;
        let mut position = 0;
        let mut left = [0_f32; 4096];
        let mut right = [0_f32; 4096];
        let mut digest = Sha256::new();
        let mut clipped = 0_u64;
        let mut peak = 0_f32;
        while position < frames {
            while event_index < events.len() && events[event_index].0 <= position {
                if let Message::Midi {
                    channel,
                    command,
                    data1,
                    data2,
                } = events[event_index].1
                {
                    synth.process_midi_message(
                        channel.into(),
                        command.into(),
                        data1.into(),
                        data2.into(),
                    );
                }
                event_index += 1;
            }
            let next = events.get(event_index).map_or(frames, |event| event.0);
            let count = (next.min(frames) - position).min(left.len() as u64) as usize;
            synth.render(&mut left[..count], &mut right[..count]);
            let mut pcm = Vec::with_capacity(count * 4);
            for (&l, &r) in left[..count].iter().zip(&right[..count]) {
                for value in [l, r] {
                    if !value.is_finite() {
                        return Err("synth produced non-finite audio".into());
                    }
                    peak = peak.max(value.abs());
                    clipped += u64::from(value.abs() > 1.0);
                    let quantized = (value.clamp(-1.0, 1.0) * 32767.0).round() as i16;
                    pcm.extend_from_slice(&quantized.to_le_bytes());
                }
            }
            file.write_all(&pcm)?;
            digest.update(&pcm);
            position += count as u64;
        }
        report.push(json!({"index":index, "frames":frames, "pcm_bytes":frames*4,
            "pcm_sha256":format!("{:x}", digest.finalize()), "clipped_values":clipped, "peak":peak}));
    }
    println!(
        "{}",
        json!({"prototype":true, "synth":"rustysynth-1.3.6", "soundfont_sha256":FONT_HASH,
        "sample_rate":RATE, "block_size":64, "polyphony":64, "effects":true, "master_volume":0.5,
        "font_seconds":font_seconds, "wall_seconds":started.elapsed().as_secs_f64(),
        "total_pcm_bytes":total_frames*4, "samples":report})
    );
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("VOS synthesis prototype failed: {error}");
        std::process::exit(1);
    }
}
