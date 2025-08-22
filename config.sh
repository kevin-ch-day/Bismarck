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
DOWNLOADS="$PROJECT_ROOT/downloads"

# Ensure required dirs exist
mkdir -p "$LOGDIR" "$OUTDIR" "$DOWNLOADS"

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

# Whether to generate derived CSV views from the master inventory
GENERATE_DERIVED=false

#####################
# APP SIGNATURES
#####################
# Canonical package filters for social media apps
SOCIAL_APPS=(
    # Core platforms
    com.facebook.katana
    com.facebook.lite
    com.facebook.orca
    com.instagram.android
    com.twitter.android
    com.twitter.android.lite
    # TikTok and variants
    com.zhiliaoapp.musically
    com.ss.android.ugc.trill
    com.ss.android.ugc.aweme
    com.ss.android.ugc.aweme.lite
    com.zhiliaoapp.musically.go
    # Messaging and others
    com.snapchat.android
    com.whatsapp
    com.whatsapp.w4b
    org.telegram.messenger
    com.reddit.frontpage
    com.linkedin.android
    com.discord
    com.pinterest
    com.tencent.mm
    jp.naver.line.android
    com.vkontakte.android
    org.thoughtcrime.securesms
    com.tinder
    tv.twitch.android.app
    com.google.android.youtube
)

# Preload/support components mapped to social family
declare -Ag SOCIAL_PRELOADS=(
    [com.facebook.appmanager]=facebook
    [com.facebook.services]=facebook
    [com.facebook.system]=facebook
)

# Heuristic keywords for social app detection
SOCIAL_KEYWORDS=(
    facebook instagram tiktok snap twitter whatsapp telegram discord reddit linkedin twitch youtube
)

#####################
# ENVIRONMENT CHECKS
#####################
# Export so all scripts can reuse
export PROJECT_ROOT LOGDIR OUTDIR DOWNLOADS
export FILTER_SOCIAL HASH_APKS PULL_APKS CHECK_ROOT VERBOSE_LOG GENERATE_DERIVED
export SOCIAL_APPS SOCIAL_KEYWORDS SOCIAL_PRELOADS
