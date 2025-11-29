#!/usr/bin/env zsh

# Find all heic files.
find . -type f -iname "*.heic" | while read f
do
    # Convert heic to jpg.
    magick "$f" -quality 80 "$f.jpg" # Version 7.x required.

    # Delete the original heic file.
    if [ $? -eq 0 ]; then
        rm "$f"
    fi
done
