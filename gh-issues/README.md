# gh-issues

A tool to make my life easier. 
Lets me pass an input file with records of issues parameters and then uses Github CLI (gh) 
to create issues on the appropriate repository/project.

## Prerequisites

You will need to have rust installed on your system 
([Rust installation guide](https://www.rust-lang.org/tools/install)).

You will also need the Github CLI tool 
([gh-cli installation instructions](https://github.com/cli/cli#installation)).

## Build and run

To build use
`cargo build --release`

then the executable should be in the target directory

## Usage 

1. Navigate to the directory where the release executable is
2. Run `./gh-issues --help` to see this message

```bash
gh-issues 0.1.0

USAGE:
    gh-issues [OPTIONS] <SUBCOMMAND>

OPTIONS:
    -d, --debug      Turn debugging information on
    -h, --help       Print help information
    -V, --version    Print version information

SUBCOMMANDS:
    create    creates gh-issues based on input file
    help      Print this message or the help of the given subcommand(s)
```
