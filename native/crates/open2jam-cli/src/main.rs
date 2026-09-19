#![forbid(unsafe_code)]

fn main() {
    let code = open2jam_cli::runner::run(
        std::env::args_os().skip(1),
        &mut std::io::stdout().lock(),
        &mut std::io::stderr().lock(),
    );
    std::process::exit(i32::from(code));
}
