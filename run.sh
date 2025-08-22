#!/bin/bash
# Orchestrate device data collection using step scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"

DEVICE_ARG=""
while [[ ${1-} ]]; do
    case "$1" in
        -d|--device)
            DEVICE_ARG="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

DEVICE=$(list_devices "$DEVICE_ARG") || exit 1
adb -s "$DEVICE" wait-for-device >/dev/null 2>&1

DEVICE_OUT="$OUTDIR/$DEVICE"
mkdir -p "$DEVICE_OUT"

LOG_FILE="$DEVICE_OUT/run_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Running on device: $DEVICE"

# Generate core datasets
"$SCRIPT_DIR/steps/generate_apk_list.sh" -d "$DEVICE"
"$SCRIPT_DIR/steps/generate_apk_metadata.sh" -d "$DEVICE"
"$SCRIPT_DIR/steps/generate_apk_hashes.sh" -d "$DEVICE"
"$SCRIPT_DIR/steps/generate_running_apps.sh" -d "$DEVICE"

# Social app report
"$SCRIPT_DIR/find_social_apps.sh" -d "$DEVICE"

# Manifest and summary
"$SCRIPT_DIR/steps/generate_manifest.sh" -d "$DEVICE" -l "$LOG_FILE"
