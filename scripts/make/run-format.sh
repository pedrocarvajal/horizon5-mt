#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../helpers/logger.sh"

log_title "FORMAT MQL5 FILES"

log_info "Finding MQL5 files..."
FILES=$(find . -type f \( -name '*.mqh' -o -name '*.mq5' \) ! -name '._*')
FILE_COUNT=$(echo "$FILES" | wc -l | tr -d ' ')

log_info "Found $FILE_COUNT files to format"

log_info "Running uncrustify..."
bash "$SCRIPT_DIR/../uncrustify-wrapper.sh" $FILES

log_success "Format completed"
