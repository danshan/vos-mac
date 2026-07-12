#![forbid(unsafe_code)]

use std::ffi::OsStr;
use std::io::{self, Write};

use open2jam_core::version::VersionInfo;

fn main() {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() == 1 && args[0] == OsStr::new("version") {
        let stdout = io::stdout();
        let mut output = stdout.lock();
        if let Err(error) = serde_json::to_writer(&mut output, &VersionInfo::current())
            .and_then(|_| output.write_all(b"\n").map_err(serde_json::Error::io))
        {
            eprintln!("version output failed: {error}");
            std::process::exit(4);
        }
        return;
    }
    eprintln!("usage: open2jam-converter version|catalog|bundle");
    std::process::exit(2);
}
