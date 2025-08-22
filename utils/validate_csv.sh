#!/bin/bash
# Utility: validate_csv.sh
# Checks CSV header and Package-sorted order

validate_csv() {
    local file="$1"
    local expected="$2"
    if [[ ! -f "$file" ]]; then
        echo "validate_csv: missing $file" >&2
        return 1
    fi
    local header
    header=$(head -n1 "$file")
    if [[ "$header" != "$expected" ]]; then
        echo "validate_csv: header mismatch in $file" >&2
        return 1
    fi
    awk -F, 'NR==2{prev=tolower($1);next} NR>2{cur=tolower($1); if(cur<prev){exit 1} prev=cur}' "$file" || {
        echo "validate_csv: Package column not sorted in $file" >&2
        return 1
    }
}
