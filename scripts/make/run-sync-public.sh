#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../helpers/logger.sh"

PUBLIC_REPO="/Users/memeonlymellc/horizon5-mt"

SYNC_EXCLUDES=(
    --exclude='.git'
    --exclude='strategies/'
    --exclude='assets/'
    --exclude='.env*'
    --exclude='*.ex5'
)

log_title "SYNC TO PUBLIC REPOSITORY"

log_info "Source: $(pwd)"
log_info "Target: $PUBLIC_REPO"

log_separator
echo ""
log_warning "Excluded from sync:"
echo "  - strategies/"
echo "  - assets/"
echo "  - .env*"
echo "  - *.ex5"
echo ""
log_separator

log_info "Preview of changes:"
echo ""
rsync -avn --delete "${SYNC_EXCLUDES[@]}" ./ "$PUBLIC_REPO/" | head -50
echo ""

log_separator
read -p "Are you sure you want to sync to public repo? (y/n): " confirm

if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    log_info "Syncing files..."
    rsync -av --delete "${SYNC_EXCLUDES[@]}" ./ "$PUBLIC_REPO/"

    log_info "Committing changes..."
    cd "$PUBLIC_REPO"
    git add .

    if git diff --cached --quiet; then
        log_warning "No changes to commit"
    else
        git commit -m "Update: $(date +%Y-%m-%d)"
        log_info "Pushing to remote..."
        git push
        log_success "Sync completed successfully"
    fi
else
    log_warning "Sync cancelled"
fi
