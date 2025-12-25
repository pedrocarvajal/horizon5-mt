#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../helpers/logger.sh"

DEPLOY_TARGET="/Volumes/[C] Windows 11/Users/memeonlymellc/AppData/Roaming/MetaQuotes/Terminal/D0E8209F77C8CF37AD8BF550E51FF075/MQL5/Experts/horizon5"

log_title "DEPLOY TO METATRADER"

log_info "Target: $DEPLOY_TARGET"

if [ ! -d "$DEPLOY_TARGET" ]; then
    log_error "Destination folder does not exist"
    log_info "Make sure the Windows partition is mounted"
    exit 1
fi

log_info "Cleaning target directory..."
rm -rf "$DEPLOY_TARGET"/*

log_info "Copying files..."
cp -R ./* "$DEPLOY_TARGET/"

log_success "Deployed successfully"
