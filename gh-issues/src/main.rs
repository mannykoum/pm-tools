use std::path::PathBuf;
use std::process::Command;
// use std::collections::HashMap;
use std::error::Error;
use std::io;
use std::process;
use log::{debug, error, log_enabled, info, Level};

use serde::Deserialize;
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[clap(author, version, about, long_about = None)]
struct Args {
    /// Turn debugging information on
    #[clap(short, long, action = clap::ArgAction::Count)]
    debug: u8,
    
    #[clap(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// creates gh-issues based on input file
    Create {
        /// Input file extension, options: csv, yaml
        #[clap(short, long, value_parser, default_value="csv")]
        ext: String,

        /// Input filepath
        #[clap(short, long, value_parser)]
        input: PathBuf,
    },
}

#[derive(Debug, Deserialize)]
struct Issue {
        title: String,
        label: Option<String>,
        milestone: Option<String>,
        assignee: String,
        body: String,

}

fn main() {
    let args = Args::parse();
    
    println!("Debug level: {:?}", args.debug);
    if args.debug == 1 { Level = "debug" }

    match &args.command {
        Commands::Create {ext, input} => {
            if args.debug > 0 {
                println!("cmd: gh-issues create --input {:?} --ext {}", input, ext)
            }

            // Match filetype with parser
            if ext == "csv" {
                if let Err(err) = create_issues_from_csv(input) {
                    println!("error running create_issues_from_csv: {}", err);
                    process::exit(1);
                }
            } else { unimplemented!() }
        }
    }

    
}

fn create_issues_from_csv(input:&PathBuf) -> Result<(), Box<dyn Error>> {
    let mut rd = csv::Reader::from_path(input)?;
    let mut records: Vec<Issue> = Vec::new();

    for result in rd.deserialize() {
        let record: Issue = result?;
        debug!("{:?}", record);
        records.push(record);
    }

    let cmd = Command::new("gh issue create");;
    cmd.args(format!("-a {}", records[0].assignee))
        .args(format!("-t {}", records[0].title))
        .args(format!("-b {}", records[0].body))
        .args(format!("-l {}", records[0].label))
        .args(format!("-m {}", records[0].milestone));
    let output = cmd.output();
    println!("{:?}", output);
    
    return Ok(())
}
