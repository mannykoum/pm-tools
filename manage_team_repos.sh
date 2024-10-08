#!/bin/bash

# Function to remove a team from repositories matching a substring
remove_team_from_repos() {
    local org_name="$1"
    local team_slug="$2"
    local substring="$3"

    # Input validation
    if [[ -z "$org_name" || -z "$team_slug" || -z "$substring" ]]; then
        echo "Error: Missing arguments for removing team from repos."
        echo "Usage: remove_team_from_repos <org_name> <team_slug> <substring>"
        return 1
    fi

    echo "Removing team '$team_slug' from repositories matching '$substring' in organization '$org_name'..."

    # Get the list of repositories and filter by substring
    repos=$(gh repo list "$org_name" --limit 100 --json name -q '.[].name' | grep "$substring")

    if [[ -z "$repos" ]]; then
        echo "No repositories found matching '$substring'."
        return 0
    fi

    for repo in $repos; do
        echo "Removing team from repo: $repo"
        gh api -X DELETE /orgs/"$org_name"/teams/"$team_slug"/repos/"$org_name"/"$repo" \
        && echo "Removed team from $repo" \
        || echo "Failed to remove team from $repo"
    done
}

# Function to add a team to repositories matching a substring
add_team_to_repos() {
    local org_name="$1"
    local team_slug="$2"
    local substring="$3"
    local permission="$4"

    # Input validation
    if [[ -z "$org_name" || -z "$team_slug" || -z "$substring" || -z "$permission" ]]; then
        echo "Error: Missing arguments for adding team to repos."
        echo "Usage: add_team_to_repos <org_name> <team_slug> <substring> <permission>"
        return 1
    fi

    echo "Adding team '$team_slug' to repositories matching '$substring' in organization '$org_name' with '$permission' permission..."

    # Get the list of repositories and filter by substring
    repos=$(gh repo list "$org_name" --limit 100 --json name -q '.[].name' | grep "$substring")

    if [[ -z "$repos" ]]; then
        echo "No repositories found matching '$substring'."
        return 0
    fi

    for repo in $repos; do
        echo "Adding team to repo: $repo"
        gh api -X PUT /orgs/"$org_name"/teams/"$team_slug"/repos/"$org_name"/"$repo" \
        -f permission="$permission" \
        && echo "Added team to $repo" \
        || echo "Failed to add team to $repo"
    done
}

# Main function
main() {
    if [[ "$#" -lt 4 ]]; then
        echo "Usage: $0 {remove|add} <org_name> <team_slug> <substring> [permission]"
        echo "  remove: Remove team from repositories matching the substring."
        echo "  add: Add team to repositories matching the substring."
        echo "  permission: Required only for the add operation (pull, push, admin)."
        exit 1
    fi

    local action="$1"
    local org_name="$2"
    local team_slug="$3"
    local substring="$4"
    local permission="$5"

    case "$action" in
        remove)
            remove_team_from_repos "$org_name" "$team_slug" "$substring"
            ;;
        add)
            if [[ -z "$permission" ]]; then
                echo "Error: Permission argument is required for the add operation."
                echo "Usage: $0 add <org_name> <team_slug> <substring> <permission>"
                exit 1
            fi
            add_team_to_repos "$org_name" "$team_slug" "$substring" "$permission"
            ;;
        *)
            echo "Invalid action: $action"
            echo "Usage: $0 {remove|add} <org_name> <team_slug> <substring> [permission]"
            exit 1
            ;;
    esac
}

# Run the main function with the given arguments
main "$@"

