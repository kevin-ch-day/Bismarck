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
    awk -F, 'NR>1 {if($1=="") next; cur=tolower($1); if(prev && cur<prev){exit 1}; prev=cur}' "$file" || {
        echo "validate_csv: Package column not sorted in $file" >&2
        return 1
    }
    awk -F, 'NR>1 && $1=="" {exit 1}' "$file" || {
        echo "validate_csv: blank Package in $file" >&2
        return 1
    }
}
