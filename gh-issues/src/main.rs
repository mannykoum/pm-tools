use std::path::PathBuf;
// use std::collections::HashMap;
use std::error::Error;
use std::io;
use std::process;

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
    
    for result in rd.deserialize() {
        let record: Issue = result?;
        println!("{:?}", record)
    }
    
    return Ok(())
}
