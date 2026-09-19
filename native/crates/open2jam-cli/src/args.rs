use std::ffi::OsString;
use std::path::PathBuf;

#[derive(Debug)]
pub enum ParsedCommand {
    Version,
    Catalog(JobFiles),
    Bundle(JobFiles),
}
#[derive(Debug)]
pub struct JobFiles {
    pub request: PathBuf,
    pub progress: PathBuf,
    pub result: PathBuf,
}
#[derive(Debug)]
pub struct UsageError {
    message: String,
}
impl UsageError {
    pub fn message(&self) -> &str {
        &self.message
    }
    pub fn exit_code(&self) -> u8 {
        2
    }
}

pub fn parse_args(args: impl IntoIterator<Item = OsString>) -> Result<ParsedCommand, UsageError> {
    let args: Vec<_> = args.into_iter().collect();
    if args.len() == 1 && args[0] == "version" {
        return Ok(ParsedCommand::Version);
    }
    if args.len() != 7
        || args[1] != "--request"
        || args[3] != "--progress"
        || args[5] != "--result"
        || (args[0] != "catalog" && args[0] != "bundle")
    {
        return Err(UsageError { message: "usage: open2jam-converter version | catalog|bundle --request FILE --progress FILE --result FILE".to_owned() });
    }
    let files = JobFiles {
        request: PathBuf::from(&args[2]),
        progress: PathBuf::from(&args[4]),
        result: PathBuf::from(&args[6]),
    };
    Ok(if args[0] == "catalog" {
        ParsedCommand::Catalog(files)
    } else {
        ParsedCommand::Bundle(files)
    })
}
