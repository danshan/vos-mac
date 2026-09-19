use std::fs;
use std::path::PathBuf;
use std::process::{Command, Output};
use std::sync::atomic::{AtomicU64, Ordering};

use serde_json::{Value, json};

static NEXT_CASE: AtomicU64 = AtomicU64::new(0);

struct Probe {
    root: PathBuf,
}

impl Probe {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!(
            "vos-synth-probe-{}-{}",
            std::process::id(),
            NEXT_CASE.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&root).unwrap();
        Self { root }
    }

    fn invoke(&self, samples: Value) -> Output {
        let request = self.root.join("request.json");
        fs::write(&request, serde_json::to_vec(&samples).unwrap()).unwrap();
        let soundfont = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../../rewrite/assets/soundfont/payload/assets/GeneralUser-GS.sf2");
        Command::new(env!("CARGO_BIN_EXE_vos-synth-probe"))
            .arg(soundfont)
            .arg(request)
            .arg(self.root.join("audio"))
            .output()
            .unwrap()
    }

    fn render(&self, samples: Value) -> Value {
        let output = self.invoke(samples);
        assert!(
            output.status.success(),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
        serde_json::from_slice(&output.stdout).unwrap()
    }
}

#[test]
fn oversized_empty_sequence_is_rejected_without_panicking() {
    let probe = Probe::new();
    let output = probe.invoke(json!([{"division":1000,"end_tick":u64::MAX,"events":[]}]));
    assert_eq!(output.status.code(), Some(1));
    assert!(!String::from_utf8_lossy(&output.stderr).contains("panicked"));
    assert!(!probe.root.join("audio").exists());
}

#[test]
fn background_track_can_span_three_minutes() {
    let probe = Probe::new();
    let report = probe.render(json!([{"division":1000,"end_tick":360000,"events":[]}]));
    assert_eq!(report["samples"][0]["frames"], 7_960_050);
    assert_eq!(report["samples"][0]["peak"], 0.0);
}

impl Drop for Probe {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.root).unwrap();
    }
}

fn short_note() -> Value {
    json!({"division": 1000, "end_tick": 20, "events": [
        {"tick": 0, "kind": "midi", "channel": 0, "command": 144, "data1": 60, "data2": 100},
        {"tick": 20, "kind": "midi", "channel": 0, "command": 128, "data1": 60, "data2": 0}
    ]})
}

#[test]
fn short_note_has_minimum_gate_tail_and_playable_stereo_pcm() {
    let probe = Probe::new();
    let report = probe.render(json!([short_note()]));
    assert_eq!(report["samples"][0]["frames"], 24_696);
    let wav = fs::read(probe.root.join("audio/0.wav")).unwrap();
    assert_eq!(&wav[0..4], b"RIFF");
    assert_eq!(&wav[8..12], b"WAVE");
    assert_eq!(u16::from_le_bytes(wav[22..24].try_into().unwrap()), 2);
    assert_eq!(u32::from_le_bytes(wav[24..28].try_into().unwrap()), 44_100);
    assert_eq!(u16::from_le_bytes(wav[34..36].try_into().unwrap()), 16);
    assert_eq!(wav.len(), 44 + 24_696 * 4);
    assert!(wav[44..].iter().any(|byte| *byte != 0));
    assert_eq!(report["samples"][0]["clipped_values"], 0);
}

#[test]
fn tempo_changes_control_duration_and_delayed_notes_preserve_silence() {
    let sample = json!({"division":1000,"end_tick":1000,"events":[
        {"tick":200,"kind":"midi","channel":0,"command":144,"data1":60,"data2":100},
        {"tick":500,"kind":"tempo","micros_per_quarter":1000000},
        {"tick":1000,"kind":"midi","channel":0,"command":128,"data1":60,"data2":0}
    ]});
    let probe = Probe::new();
    let report = probe.render(json!([sample]));
    assert_eq!(report["samples"][0]["frames"], 55_125);
    let wav = fs::read(probe.root.join("audio/0.wav")).unwrap();
    assert!(wav[44..44 + 4410 * 4].iter().all(|byte| *byte == 0));
    assert!(wav[44 + 4410 * 4..].iter().any(|byte| *byte != 0));
}

#[test]
fn renders_are_identical_across_processes_and_reversed_sample_order() {
    let a = short_note();
    let mut b = short_note();
    b["events"][0]["data1"] = json!(72);
    b["events"][1]["data1"] = json!(72);
    let first = Probe::new();
    let repeated = Probe::new();
    let reversed = Probe::new();
    let original = first.render(json!([a, b]));
    let again = repeated.render(json!([a, b]));
    let swapped = reversed.render(json!([b, a]));
    assert_ne!(
        original["samples"][0]["pcm_sha256"],
        original["samples"][1]["pcm_sha256"]
    );
    for index in 0..2 {
        assert_eq!(
            original["samples"][index]["pcm_sha256"],
            again["samples"][index]["pcm_sha256"]
        );
        assert_eq!(
            original["samples"][index]["pcm_sha256"],
            swapped["samples"][1 - index]["pcm_sha256"]
        );
        assert_eq!(
            fs::read(first.root.join(format!("audio/{index}.wav"))).unwrap(),
            fs::read(reversed.root.join(format!("audio/{}.wav", 1 - index))).unwrap()
        );
    }
}

#[test]
fn controls_change_audio_and_silent_input_remains_silent() {
    let base = short_note();
    let mut quiet = base.clone();
    quiet["events"][0]["data2"] = json!(40);
    let mut left = base.clone();
    left["events"].as_array_mut().unwrap().insert(
        0,
        json!({"tick":0,"kind":"midi","channel":0,"command":176,"data1":10,"data2":0}),
    );
    let mut right = left.clone();
    right["events"][0]["data2"] = json!(127);
    let mut program_first = base.clone();
    program_first["events"].as_array_mut().unwrap().insert(
        0,
        json!({"tick":0,"kind":"midi","channel":0,"command":192,"data1":40,"data2":0}),
    );
    let mut program_after = base.clone();
    program_after["events"].as_array_mut().unwrap().insert(
        1,
        json!({"tick":0,"kind":"midi","channel":0,"command":192,"data1":40,"data2":0}),
    );
    let probe = Probe::new();
    let result = probe.render(json!([base,quiet,left,right,program_first,program_after,
        {"division":1000,"end_tick":0,"events":[]}]));
    assert!(
        result["samples"][1]["peak"].as_f64().unwrap()
            < result["samples"][0]["peak"].as_f64().unwrap()
    );
    assert_ne!(
        result["samples"][4]["pcm_sha256"],
        result["samples"][5]["pcm_sha256"]
    );
    assert_eq!(
        result["samples"][0]["pcm_sha256"],
        result["samples"][5]["pcm_sha256"]
    );
    for (index, dominant) in [(2, 0), (3, 1)] {
        let wav = fs::read(probe.root.join(format!("audio/{index}.wav"))).unwrap();
        let mut energy = [0_f64; 2];
        for frame in wav[44..].chunks_exact(4) {
            for channel in 0..2 {
                let value =
                    i16::from_le_bytes(frame[channel * 2..channel * 2 + 2].try_into().unwrap())
                        as f64;
                energy[channel] += value * value;
            }
        }
        assert!(energy[dominant] > 3.0 * energy[1 - dominant]);
    }
    let silent = fs::read(probe.root.join("audio/6.wav")).unwrap();
    assert!(silent[44..].iter().all(|byte| *byte == 0));
    for sample in result["samples"].as_array().unwrap() {
        assert_eq!(sample["clipped_values"], 0);
    }
}

#[test]
fn bank_selection_and_channel_controls_do_not_leak_between_channels() {
    let base = short_note();
    let mut bank = base.clone();
    bank["events"].as_array_mut().unwrap().insert(
        0,
        json!({"tick":0,"kind":"midi","channel":0,"command":176,"data1":0,"data2":12}),
    );
    let mut other_channel = base.clone();
    other_channel["events"].as_array_mut().unwrap().insert(
        0,
        json!({"tick":0,"kind":"midi","channel":1,"command":176,"data1":0,"data2":12}),
    );
    let mut zero_velocity_off = base.clone();
    zero_velocity_off["events"][1]["command"] = json!(144);
    let probe = Probe::new();
    let report = probe.render(json!([base, bank, other_channel, zero_velocity_off]));
    assert_ne!(
        report["samples"][0]["pcm_sha256"],
        report["samples"][1]["pcm_sha256"]
    );
    assert_eq!(
        report["samples"][0]["pcm_sha256"],
        report["samples"][2]["pcm_sha256"]
    );
    assert_eq!(
        report["samples"][0]["pcm_sha256"],
        report["samples"][3]["pcm_sha256"]
    );
}
