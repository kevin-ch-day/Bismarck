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

#####################
# APP SIGNATURES
#####################
# Canonical package filters for social media apps
# Format: "package:Pretty Name"
SOCIAL_APPS=(
    # Core platforms
    "com.facebook.katana:Facebook"
    "com.facebook.lite:Facebook Lite"
    "com.facebook.orca:Messenger"
    "com.instagram.android:Instagram"
    "com.twitter.android:Twitter / X"
    "com.twitter.android.lite:Twitter Lite"
    # TikTok and variants
    "com.zhiliaoapp.musically:TikTok"
    "com.ss.android.ugc.trill:TikTok"
    "com.ss.android.ugc.aweme:TikTok"
    "com.ss.android.ugc.aweme.lite:TikTok Lite"
    "com.zhiliaoapp.musically.go:TikTok Lite"
    "com.snapchat.android:Snapchat"
    "com.whatsapp:WhatsApp"
    "com.whatsapp.w4b:WhatsApp Business"
    "org.telegram.messenger:Telegram"

    # Other popular social/messaging apps
    "com.reddit.frontpage:Reddit"
    "com.linkedin.android:LinkedIn"
    "com.discord:Discord"
    "com.pinterest:Pinterest"
    "com.tencent.mm:WeChat"
    "jp.naver.line.android:LINE"
    "com.vkontakte.android:VK"
    "org.thoughtcrime.securesms:Signal"
)

#####################
# ENVIRONMENT CHECKS
#####################
# Export so all scripts can reuse
export PROJECT_ROOT LOGDIR OUTDIR DOWNLOADS
export FILTER_SOCIAL HASH_APKS PULL_APKS CHECK_ROOT VERBOSE_LOG
export SOCIAL_APPS
