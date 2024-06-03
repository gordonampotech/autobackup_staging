#!/bin/bash

# Check if two arguments are given
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path/to/archive.tar> <path/to/file.json>"
    exit 1
fi

# Tar file path from the first argument
tar1="$1"
# JSON file path from the second argument
json2="$2"

# Define an array of fields to ignore
declare -a ignore_fields=("slug" "date" "size")

# Convert the array into jq's format for deleting multiple fields
delete_fields=$(printf ".%s," "${ignore_fields[@]}")
delete_fields=${delete_fields%,} # Remove the trailing comma

# Compare backup.json from tar archive and the JSON file, ignoring specific fields
# Use cmp -s for silent comparison, just to check if files are different
if cmp -s <(tar -xf "$tar1" -O ./backup.json | jq "walk(if type == \"object\" then del(${delete_fields}) else . end)") <(jq "walk(if type == \"object\" then del(${delete_fields}) else . end)" "$json2"); then
    echo "False" # No differences
    exit 0
else
    echo "True" # Differences found
    exit 1
fi
