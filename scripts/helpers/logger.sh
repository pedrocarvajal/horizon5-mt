#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_debug() {
    local message="$1"
    echo -e "${CYAN}[$(_timestamp)] [DEBUG]${NC} $message"
}

log_info() {
    local message="$1"
    echo -e "${GREEN}[$(_timestamp)] [INFO]${NC} $message"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[$(_timestamp)] [WARNING]${NC} $message"
}

log_error() {
    local message="$1"
    echo -e "${RED}[$(_timestamp)] [ERROR]${NC} $message"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}${BOLD}[$(_timestamp)] [SUCCESS]${NC} $message"
}

log_title() {
    local message="$1"
    echo ""
    echo -e "${BOLD}============================================${NC}"
    echo -e "${BOLD}  $message${NC}"
    echo -e "${BOLD}============================================${NC}"
    echo ""
}

log_separator() {
    echo "============================================"
}
