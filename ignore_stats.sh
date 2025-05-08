#!/bin/bash

#vi ~/ignore_stats.sh
#sh ~/ignore_stats.sh


# Find all public_html/stats directories under /home
for statsdir in /home/*/public_html/stats; do
  if [ -d "$statsdir" ]; then
    echo "Processing $statsdir"

    # Create .gitignore file with the specified content
    cat > "$statsdir/.gitignore" << 'EOF'
##### ignore this dir #####
*
**
**/*
##### ignore this dir #####
EOF

    echo "Created .gitignore in $statsdir"

    # Move to the git root (assumes statsdir is inside a Git repo)
    git_root=$(git -C "$statsdir" rev-parse --show-toplevel 2>/dev/null)

    if [ -n "$git_root" ]; then
      rel_path=${statsdir#$git_root/}  # Get relative path to the git root
      echo "Removing $rel_path from Git cache"
      git -C "$git_root" rm --cached -r "$rel_path"
    else
      echo "Not inside a Git repository: $statsdir"
    fi
  fi
done

echo "Done processing all stats directories"
