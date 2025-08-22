#!/bin/bash
# config.sh
# Centralized configuration for the Android APK Tool project

#####################
# PATHS
#####################
# Project root (always resolve relative to script location)
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Directories
LOGDIR="$PROJECT_ROOT/logs"
OUTDIR="$PROJECT_ROOT/output"
TMPDIR="$PROJECT_ROOT/tmp"
DOWNLOADS="$PROJECT_ROOT/downloads"

# Ensure required dirs exist
mkdir -p "$LOGDIR" "$OUTDIR" "$TMPDIR" "$DOWNLOADS"

#####################
# TIMESTAMPED FILES
#####################
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

LOGFILE="$LOGDIR/run_$TIMESTAMP.log"
APK_LIST="$OUTDIR/apk_list_$TIMESTAMP.csv"
SOCIALFILE="$OUTDIR/social_apps_$TIMESTAMP.csv"
HASH_MANIFEST="$OUTDIR/apk_hashes_$TIMESTAMP.csv"
METADATAFILE="$OUTDIR/apk_metadata_$TIMESTAMP.csv"
ROOT_STATUS="$OUTDIR/root_status_$TIMESTAMP.txt"

#####################
# BEHAVIOR FLAGS
#####################
# Whether to filter for social apps
FILTER_SOCIAL=true

# Whether to compute APK hashes via adb shell (can be slow)
HASH_APKS=true

# Whether to attempt pulling APKs of interest
PULL_APKS=true

# Whether to check root status automatically
CHECK_ROOT=true

# Whether to enable verbose adb command logging
VERBOSE_LOG=false

#####################
# APP SIGNATURES
#####################
# Canonical package filters for social media apps
SOCIAL_APPS=(
    # Core platforms
    "com.facebook.katana"      # Facebook
    "com.facebook.orca"        # Messenger
    "com.instagram.android"    # Instagram
    "com.twitter.android"      # Twitter / X
    "com.twitter.android.lite" # Twitter Lite
    "com.zhiliaoapp.musically" # TikTok
    "com.ss.android.ugc.trill" # TikTok (alt)
    "com.snapchat.android"     # Snapchat
    "com.whatsapp"             # WhatsApp
    "com.whatsapp.w4b"         # WhatsApp Business
    "org.telegram.messenger"   # Telegram
    "com.facebook.appmanager"  # Facebook App Manager (system)
    "com.facebook.services"    # Facebook Services (system)
    "com.facebook.system"      # Facebook Installer (system)

    # Other popular social/messaging apps
    "com.reddit.frontpage"     # Reddit
    "com.linkedin.android"     # LinkedIn
    "com.discord"              # Discord
    "com.pinterest"            # Pinterest
    "com.wechat"               # WeChat
)

#####################
# ENVIRONMENT CHECKS
#####################
# Export so all scripts can reuse
export PROJECT_ROOT LOGDIR OUTDIR TMPDIR DOWNLOADS
export LOGFILE APK_LIST SOCIALFILE HASH_MANIFEST METADATAFILE ROOT_STATUS
export FILTER_SOCIAL HASH_APKS PULL_APKS CHECK_ROOT VERBOSE_LOG
export SOCIAL_APPS
