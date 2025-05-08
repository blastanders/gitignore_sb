#!/bin/bash

## commands need to be run is prefixed with ### for easy identification
# steps to create the ssh key 
# SSH onto the vm
### ssh-keygen
# do not set a password for the key
### cat ~/.ssh/id_rsa.pub
# Go to git.bonntech.com.au, login as aaron.zheng
# Go to user settings, SSH keys, Add new key
# Paste the key from the cat command
# Usage type: Authentication & Signing, Expiration: never

# make sure git is installed
### yum install git -y
### vi /git_cron.sh
### sh /git_cron.sh


# ---------------------- AUTOMATED CRONTAB INSTALLATION /START/ ---------------------- #
CRON_CMD='echo -e "\n--------------------$(date)--------------------" >> /git_cron.log && sh /git_cron.sh >> /git_cron.log 2>&1'
# Extract the VM name (everything before the first dot)
VM_NAME=$(hostname | cut -d '.' -f1)

# Extract the VM number from the name (e.g., vm12 → 12)
VM_NUM=$(echo "$VM_NAME" | grep -o '[0-9]\+')

# If the VM name does not contain a number, default to VM1
if [[ -z "$VM_NUM" ]]; then
    VM_NUM=1
fi

# Calculate staggered start time
MINUTES=$(( ( (VM_NUM - 1) * 20 ) % 60 ))
HOURS=$(( 1 + ( (VM_NUM - 1) * 20 ) / 60 ))

# Construct the crontab entry
CRON_ENTRY="$MINUTES $HOURS * * * $CRON_CMD"

# Check if the crontab entry already exists
crontab -l 2>/dev/null | grep -qF "$CRON_CMD"

if [[ $? -eq 0 ]]; then
    echo "Crontab entry already exists, skipping installation."
else
    echo "Adding crontab entry..."
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo "Crontab entry added: $CRON_ENTRY"
fi

# ---------------------- AUTOMATED CRONTAB INSTALLATION /END/  ---------------------- #


# Define the directories to look for (just the names, not the full paths)
target_dirs=("var" "vendor" "img" "cache" "log" "logs" "ci_sessions" "wflogs" "stats")

# Define the content for the .gitignore file
ignore_content="##### ignore this dir #####
*
**
**/*
##### ignore this dir #####
"

# Ensure the script is running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Exiting."
   exit 1
fi



# Loop through each directory under /home/
for user_dir in /home/*/; do
    # Get the current user directory name
    current_dir_name=$(basename "$user_dir")
    echo "Processing user directory: $current_dir_name"

    # Check if .git exists in the user directory
    if [ -d "$user_dir/.git" ]; then
        echo "Git repository already exists in $user_dir. Skipping."

        cd "$user_dir" || exit
        git add .
        git commit -m "automated commit $(date +'%Y-%m-%d %H:%M:%S%z')"
        git push --set-upstream origin --all
        echo "Git add and push completed for $current_dir_name."

        continue
    fi

     # Skip directories named vm[0-9]
    if [[ $current_dir_name =~ ^vm[0-9]+$ ]]; then
        echo "Skipping directory $current_dir_name (matches vm[0-9]+)."
        continue
    fi


    # Check if public_html exists in the user directory
    base_dir="${user_dir}public_html"
    if [ -d "$base_dir" ]; then
        echo "Found public_html for $current_dir_name. Searching for target directories..."

        # Search for target directories and create .gitignore
        for dir_name in "${target_dirs[@]}"; do
            dirs=$(find "$base_dir" -type d -name "$dir_name" 2>/dev/null)
            for dir in $dirs; do
                echo "Directory found: $dir"
                # Create .gitignore file with the specified content
                echo "$ignore_content" > "$dir/.gitignore"
                echo "Created .gitignore in $dir"
            done
        done

        # Change to the base directory for Git initialization
        cd "$user_dir" || exit

        # Download the .gitignore file from the provided URL and append it to the current directory's .gitignore
        gitignore_url="https://raw.githubusercontent.com/blastanders/gitignore_sb/main/gitignore"
        curl -o .gitignore_temp "$gitignore_url" && echo "Downloaded .gitignore from $gitignore_url"
        cat .gitignore_temp >> .gitignore && echo "Appended downloaded .gitignore to the current directory's .gitignore"
        rm .gitignore_temp  # Clean up temporary file

        # Initialize Git
        echo "Initializing Git repository for $current_dir_name..."
        git init
        git add .
        git config --global user.email "vm0_gituser@bonntech.com.au"
        git config --global user.name "vm0_gituser"
        git config --global --add safe.directory '*'
        git commit -m "initial load"
        git remote add origin "ssh://git@git.bonntech.com.au:2222/${VM_NAME}/${current_dir_name}.git"
        git push --set-upstream origin --all

        echo "Git repository initialized and remote added for $current_dir_name."
    else
        echo "No public_html directory found for $current_dir_name. Skipping."
    fi
done

echo "Script completed for all user directories under /home/."
