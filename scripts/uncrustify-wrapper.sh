#!/bin/bash

if [ $# -eq 0 ]; then
    echo "No files provided"
    exit 1
fi

for file in "$@"; do
    echo "Formatting: $file"
    uncrustify -c uncrustify.cfg --replace --no-backup "$file"
    if [ $? -ne 0 ]; then
        echo "Failed to format: $file"
        exit 1
    fi
done

echo "All files formatted successfully"
exit 0
