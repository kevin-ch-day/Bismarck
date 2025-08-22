#!/bin/bash
# Library: output_utils.sh
# Provides helper functions for CSV output and file presence checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=utils/logging_utils.sh
source "$SCRIPT_DIR/logging_utils.sh"

# Write CSV header to a file, overwriting existing content
write_csv_header() {
    local file="$1"
    local header="$2"
    echo "$header" > "$file"
}

# Append a CSV row to a file
append_csv_row() {
    local file="$1"
    local row="$2"
    echo "$row" >> "$file"
}

# Ensure required file exists and is non-empty
require_file() {
    local file="$1"
    if [ ! -f "$file" ] || [ ! -s "$file" ]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "Required file $file missing or empty."
        else
            echo "Required file $file missing or empty." >&2
        fi
        return 1
    fi
}
