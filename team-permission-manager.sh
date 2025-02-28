#!/bin/bash

set -e

# Help text
show_help() {
    cat << EOF
GitHub Team Permission Manager
Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help                 Show this help message
    -t, --team TEAM            Organization/team name (e.g., 'org-name/team-name')
    -c, --current LEVEL        Current permission level to search for
    -n, --new LEVEL            New permission level to upgrade to
    -y, --yes                  Auto-accept all permission changes without prompting
    -d, --dry-run              Show what would be changed without making changes
    -f, --file FILE            Process multiple teams from a CSV file
                               Format: org/team,current_level,target_level
    -v, --verbose              Show more detailed output

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

# Global variables
AUTO_ACCEPT=false
DRY_RUN=false
VERBOSE=false
TEAM_NAME=""
CURRENT_LEVEL=""
TARGET_LEVEL=""
BATCH_FILE=""

# Function to confirm action
confirm_action() {
    local repo=$1
    local current_level=$2
    local target_level=$3
    
    if [ "$AUTO_ACCEPT" = true ]; then
        return 0
    fi
    
    read -p "Elevate permissions for '$repo' from '$current_level' to '$target_level'? (y/n): " choice
    case "$choice" in 
        y|Y ) return 0 ;;
        * ) return 1 ;;
    esac
}

# Function to log verbose output
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $1"
    fi
}

# Function to update repository permissions
update_repo_permission() {
    local org=$1
    local team=$2
    local repo=$3
    local current_level=$4
    local target_level=$5
    
    echo "Updating permissions for $repo..."
    
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would update $repo from $current_level to $target_level"
        return 0
    fi
    
    gh api \
        --method PUT \
        "/orgs/$org/teams/$team/repos/$org/$repo" \
        --field "permission=$target_level"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully updated permissions for $repo"
        return 0
    else
        echo "❌ Failed to update permissions for $repo"
        return 1
    fi
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--team)
            TEAM_NAME="$2"
            shift 2
            ;;
        -c|--current)
            CURRENT_LEVEL="$2"
            shift 2
            ;;
        -n|--new)
            TARGET_LEVEL="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_ACCEPT=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--file)
            BATCH_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help to show help message"
            exit 1
            ;;
    esac
done

# Function to process a single team
process_team() {
    local team_name=$1
    local current_level=$2
    local target_level=$3
    
    # Validate team name format
    if [[ ! "$team_name" =~ ^[^/]+/[^/]+$ ]]; then
        echo "Error: Team name must be in format 'org-name/team-name'"
        return 1
    fi
    
    local org_name="${team_name%%/*}"
    local team_short="${team_name#*/}"
    
    echo "Searching for repositories for team '$team_name'..."
    log_verbose "Current permission level: $current_level"
    log_verbose "Target permission level: $target_level"
    
    # Get list of repositories where the team has the specified permission level
    repos=$(gh api \
        --paginate \
        "/orgs/$org_name/teams/$team_short/repos" \
        --jq ".[] | select(.permissions.$current_level == true) | .name" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch repositories. Check if the team exists and you have sufficient permissions."
        return 1
    fi
    
    if [ -z "$repos" ]; then
        echo "No repositories found with '$current_level' access for team '$team_name'"
        return 0
    fi
    
    local repo_count=$(echo "$repos" | wc -l)
    echo -e "\nFound $repo_count repositories with '$current_level' access:"
    echo "----------------------------------------"
    echo "$repos"
    echo -e "----------------------------------------\n"
    
    if [ "$AUTO_ACCEPT" = true ]; then
        echo "Auto-accepting all permission changes..."
    fi
    
    local success_count=0
    local skipped_count=0
    local failed_count=0
    
    # Process each repository
    for repo in $repos; do
        if confirm_action "$repo" "$current_level" "$target_level"; then
            if update_repo_permission "$org_name" "$team_short" "$repo" "$current_level" "$target_level"; then
                ((success_count++))
            else
                ((failed_count++))
            fi
        else
            echo "Skipped $repo"
            ((skipped_count++))
        fi
    done
    
    echo -e "\nSummary for team '$team_name':"
    echo "  - Successfully updated: $success_count"
    echo "  - Skipped: $skipped_count"
    echo "  - Failed: $failed_count"
    echo "  - Total repositories processed: $repo_count"
}

# Function to process teams from a batch file
process_batch_file() {
    local file=$1
    
    if [ ! -f "$file" ]; then
        echo "Error: Batch file '$file' not found"
        exit 1
    fi
    
    echo "Processing teams from batch file: $file"
    
    local line_num=0
    while IFS=, read -r team current target; do
        ((line_num++))
        
        # Skip empty lines and comments
        if [[ -z "$team" || "$team" =~ ^# ]]; then
            continue
        fi
        
        # Validate input
        if [[ -z "$current" || -z "$target" ]]; then
            echo "Error on line $line_num: Missing fields. Format should be: org/team,current_level,target_level"
            continue
        fi
        
        if ! validate_permission "$current" || ! validate_permission "$target"; then
            echo "Error on line $line_num: Invalid permission level"
            continue
        fi
        
        echo -e "\n========================================="
        echo "Processing team: $team (line $line_num)"
        echo "========================================="
        process_team "$team" "$current" "$target"
    done < "$file"
}

# Main execution logic
if [ -n "$BATCH_FILE" ]; then
    # Process teams from batch file
    process_batch_file "$BATCH_FILE"
else
    # Interactive or command-line mode
    if [ -z "$TEAM_NAME" ]; then
        show_permission_levels
        read -p "Enter the organization/team name (e.g., 'org-name/team-name'): " TEAM_NAME
    fi
    
    if [ -z "$CURRENT_LEVEL" ]; then
        show_permission_levels
        while true; do
            read -p "Enter the current permission level to search for: " CURRENT_LEVEL
            if validate_permission "$CURRENT_LEVEL"; then
                break
            else
                echo "Invalid permission level. Please choose from the available levels."
                show_permission_levels
            fi
        done
    elif ! validate_permission "$CURRENT_LEVEL"; then
        echo "Error: Invalid current permission level: $CURRENT_LEVEL"
        show_permission_levels
        exit 1
    fi
    
    if [ -z "$TARGET_LEVEL" ]; then
        show_permission_levels
        while true; do
            read -p "Enter the target permission level to upgrade to: " TARGET_LEVEL
            if validate_permission "$TARGET_LEVEL"; then
                break
            else
                echo "Invalid permission level. Please choose from the available levels."
                show_permission_levels
            fi
        done
    elif ! validate_permission "$TARGET_LEVEL"; then
        echo "Error: Invalid target permission level: $TARGET_LEVEL"
        show_permission_levels
        exit 1
    fi
    
    # Process the single team
    process_team "$TEAM_NAME" "$CURRENT_LEVEL" "$TARGET_LEVEL"
fi

echo -e "\nPermission update process completed."
if [ "$DRY_RUN" = true ]; then
    echo "Note: This was a dry run. No actual changes were made."
fi
