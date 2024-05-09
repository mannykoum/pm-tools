#!/usr/bin/env bash
# This script is used to fork a private repo to another private repo by cloning
# the source repo, creating the new one on github, setting the second one as 
# the upstream repo, and pushing the original files to the upstream  
# Usage: repo_shadow_fork.sh <organization>/<repo_name> <organization>/<new_repo_name>
# Example: repo_shadow_fork.sh my_private_repo my_public_repo
# Note: This script requires that you have the github cli installed and configured

# Check for required arguments
if [ $# -ne 2 ]; then
    echo "Usage: repo_shadow_fork.sh <organization>/<repo_name> <organization>/<new_repo_name>"
    exit 1
fi

# Get the repo name and new repo name
repo_name=$1
new_repo_name=$2

# Test if gh auth status is valid, else login
if ! gh auth status; then
    gh auth login
fi

# Clone the source repo and exit if failure
echo "Cloning " $repo_name
if ! gh repo clone $repo_name; then
    echo "Failed to clone $repo_name"
    exit 1
fi

# Create the new repo and exit if failure
if ! gh repo create $new_repo_name; then
    echo "Failed to create $new_repo_name"
    exit 1
fi

# Set the new repo as the upstream
cd $repo_name
git remote add upstream $new_repo_name
git push upstream

