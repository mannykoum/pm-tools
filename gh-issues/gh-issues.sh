#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

if [[ "$#" -ne 1  ]] || [[ "${1-}" =~ ^-*h(elp)?$ ]] ||
    [[ "${1: -4}" != ".csv" ]] || [[ ! -f "$1"  ]]; then
    echo 'Usage: ./gh-issues.sh FILE

This is a bash script that reads a FILE csv file and creates issues on Github
out of it. The FILE is separated into fields by comma. The first line is checked
and needs to have the following six fields:
title assignee body label milestone repo

Requires github CLI tool.

'
    exit
fi

cd "$(dirname "$0")"

check_github_login() {
    if ! gh auth status; then
        gh auth login
    fi
}

read_csv() {
    awk '
    BEGIN { FS=","; err=0; } # success status is 0
    # Check the first line for the appropriate field names
    NR==1 {
        error_msg="ERROR: Structure of the input fields should be:\n\
            title assignee body label milestone repo (project not yet supported by gh cli)";
        if ($1!="title" || $2!="assignee" || $3!="body" || $4!="label" ||
            $5!="milestone" || $6!="repo" ){
            print error_msg;
            err=1;
            exit;
        }
    }

    # Skip record if the issue exists on the repository (checks by name)
    NR>1 {
        list_cmd = "gh issue list -R infiniteorbits/" $6
        flag=0;
        while ((list_cmd | getline result) > 0) {
            if ( result ~ $1 ) {
                print "SKIP\tskipping this record because " $1 " exists"
                flag=1;
                close(list_cmd)
                break;
            }
        }
        close(list_cmd)
        if (flag)
            next
    }

    # Create issue using github cli
    NR>1 {
        cmd=sprintf("gh issue create -t \"%s\" -a \"%s\" -b \"%s\" -l \"%s\" -m "\
            "\"%s\" -R \"infiniteorbits/%s\"", $1,$2,$3,$4,$5,$6);
        err = system(cmd);
    }

    END { exit err }' $1
    if [ $? -ne 0 ]; then
        exit 1
    fi
}

main() {
    check_github_login
    read_csv $1
}

main "$@"

