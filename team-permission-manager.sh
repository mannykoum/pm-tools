#!/bin/bash

# Help text
show_help() {
    cat << EOF
GitHub Team Permission Manager
Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help    Show this help message

Permission Levels (in ascending order):
    pull:     Can pull (read-only) and clone repositories
              - Can view and pull the repository
              - Can discuss in pull requests and issues
              - Can submit pull requests from forked repositories

    triage:   Basic writing permissions without code access
              - Includes all 'pull' permissions
              - Can manage issues and pull requests
              - Can apply labels and milestones
              - Cannot push to the repository

    push:     Standard developer access
              - Includes all 'triage' permissions
              - Can push to the repository
              - Can manage issues and pull requests
              - Can create and edit releases
              - Can create and delete branches

    maintain: Project management access without sensitive permissions
              - Includes all 'push' permissions
              - Can manage repositories
              - Can configure repository settings
              - Cannot access sensitive or destructive actions
              - Cannot manage access permissions

    admin:    Full repository access
              - Includes all 'maintain' permissions
              - Can manage access permissions
              - Can delete the repository
              - Can add collaborators
              - Can configure security settings

Example Usage:
    1. Run the script: ./$(basename "$0")
    2. Enter the organization/team name (e.g., 'myorg/developers')
    3. Enter current permission level to search for
    4. Enter target permission level to upgrade to
    5. Confirm each repository permission change

Requirements:
    - GitHub CLI (gh) must be installed and authenticated
    - User must have sufficient permissions to modify team access

Note: This script will only show repositories where the team has exactly
      the specified current permission level. Repositories where the team
      has higher levels of access will not be shown.
EOF
}

# Available permission levels in GitHub
declare -a PERMISSION_LEVELS=("pull" "triage" "push" "maintain" "admin")

# Function to display available permission levels
show_permission_levels() {
    echo "Available permission levels (in ascending order of access):"
    echo "--------------------------------------------------------"
    for level in "${PERMISSION_LEVELS[@]}"; do
        echo "- $level"
    done
    echo
}

# Function to validate permission level
validate_permission() {
    local permission=$1
    for level in "${PERMISSION_LEVELS[@]}"; do
        if [ "$level" == "$permission" ]; then
            return 0
        fi
    done
    return 1
}

# Function to confirm action
confirm_action() {
    local repo=$1
    local current_level=$2
    local target_level=$3
    
    read -p "Elevate permissions for '$repo' from '$current_level' to '$target_level'? (y/n): " choice
    case "$choice" in 
        y|Y ) return 0 ;;
        * ) return 1 ;;
    esac
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help to show help message"
            exit 1
            ;;
    esac
    shift
done

# Show available permission levels
show_permission_levels

# Get team name
read -p "Enter the organization/team name (e.g., 'org-name/team-name'): " team_name

# Get current permission level
while true; do
    read -p "Enter the current permission level to search for: " current_level
    if validate_permission "$current_level"; then
        break
    else
        echo "Invalid permission level. Please choose from the available levels."
        show_permission_levels
    fi
done

# Get target permission level
while true; do
    read -p "Enter the target permission level to upgrade to: " target_level
    if validate_permission "$target_level"; then
        break
    else
        echo "Invalid permission level. Please choose from the available levels."
        show_permission_levels
    fi
done

echo "Searching for repositories..."

# Get list of repositories where the team has the specified permission level
repos=$(gh api \
    --paginate \
    "/orgs/${team_name%%/*}/teams/${team_name#*/}/repos" \
    --jq ".[] | select(.permissions.$current_level == true) | .name")

if [ -z "$repos" ]; then
    echo "No repositories found with '$current_level' access for team '$team_name'"
    exit 0
fi

echo -e "\nFound repositories with '$current_level' access:"
echo "----------------------------------------"
echo "$repos"
echo -e "----------------------------------------\n"

# Process each repository
for repo in $repos; do
    if confirm_action "$repo" "$current_level" "$target_level"; then
        echo "Updating permissions for $repo..."
        gh api \
            --method PUT \
            "/orgs/${team_name%%/*}/teams/${team_name#*/}/repos/${team_name%%/*}/$repo" \
            --field "permission=$target_level" \
            && echo "Successfully updated permissions for $repo" \
            || echo "Failed to update permissions for $repo"
    else
        echo "Skipped $repo"
    fi
done

echo "Permission update process completed."
