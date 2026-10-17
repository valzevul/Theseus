#!/bin/bash
# capture_assets.sh - README screenshots & GIFs from the TheseusDemoSwiftUI app.
#
# PREREQUISITE: build & install the app on a booted simulator first - this
# script never builds. Run the TheseusDemoSwiftUI scheme once from Xcode, or:
#
#   xcodebuild -project TheseusDemoSwiftUI/TheseusDemoSwiftUI.xcodeproj \
#     -scheme TheseusDemoSwiftUI \
#     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
#     -derivedDataPath /tmp/theseus-dd build
#   xcrun simctl install booted \
#     /tmp/theseus-dd/Build/Products/Debug-iphonesimulator/TheseusDemoSwiftUI.app
#
# Usage:
#   ./capture_assets.sh shots                  # PNG of every README preview scene
#   ./capture_assets.sh shot <scene>           # PNG of one scene
#   ./capture_assets.sh gif <scene> [seconds]  # record a preview scene -> GIF
#   ./capture_assets.sh demo <name> [seconds]  # record a demo screen -> GIF
#                                              # (interact with the sim while it records)
#   ./capture_assets.sh drag <name> [seconds]  # record a demo with -autodrag 1
#                                              # (scripted drag: the sim HID stack
#                                              # cannot emit touch-move events)
#
# Preview scenes: hero switch slider tabbar glassview settings fallback tint27 glass27
# Demo screens:   glass27 tabbar switch slider glassview settings
# Drag demos:     glass27 (satellite melt), glassview (lens pull + balloons)
# Every preview scene honours -autodrag 1: the hero, settings and fallback lens
# follows a scripted path and the switch, slider and tab bar scenes play
# scripted touches, so no touch input is needed. The scripted lenses present
# with the Core Animation transaction, so each recorded frame carries the lens
# and what it refracts in one step. Encode the lens scenes at 20 fps (50 ms per
# frame, three display frames) and the control scenes at 25 fps.
#
# The archived README GIFs are cropped to the action region before palette
# conversion (full-screen portrait makes an 80 pt lens unreadable). Crops used
# on iPhone 17 Pro recordings (1206x2622 px):
#   drag-merge   crop=1086:660:60:810      (glass card + apron)
#   drag-lens    crop=1206:2280:0:280      (lens travel + balloon spread)
#   drag-tabbar  crop=1206:330:0:1500      (TheseusTabBar strip)
#   switch-...   crop=1206:390:0:1245      (both switch rows)
#   README preview scenes (the 400 pt square on iPhone 17 Pro): crop=1200:1200:3:753,
#   then scale=400:400.
#
# GIF conversion needs ffmpeg (brew install ffmpeg); otherwise the .mov is kept.

set -euo pipefail

BUNDLE_ID="com.example.TheseusDemoSwiftUI"
OUT="assets/captures"
PREVIEWS=(hero switch slider tabbar glassview settings fallback tint27 glass27)

mkdir -p "$OUT"

require_booted() {
    if ! xcrun simctl list devices | grep -q "(Booted)"; then
        echo "error: no booted simulator. Boot one and install the demo app first." >&2
        exit 1
    fi
}

relaunch() {
    # $@ = launch arguments
    xcrun simctl terminate booted "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch booted "$BUNDLE_ID" "$@" >/dev/null
}

to_gif() {
    # $1 = source .mov, $2 = target .gif
    if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -y -i "$1" \
            -vf "fps=20,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
            "$2" >/dev/null 2>&1
        rm -f "$1"
        echo "captured $2"
    else
        echo "ffmpeg not found - kept recording at $1"
    fi
}

record() {
    # $1 = output basename, $2 = seconds
    local mov="$OUT/$1.mov"
    xcrun simctl io booted recordVideo --codec h264 --force "$mov" &
    local rec=$!
    echo "recording for $2 s - interact with the simulator now if the scene needs it"
    sleep "$2"
    kill -INT "$rec" 2>/dev/null || true
    wait "$rec" 2>/dev/null || true
    to_gif "$mov" "$OUT/$1.gif"
}

cmd="${1:-shots}"

case "$cmd" in
    shots)
        require_booted
        for scene in "${PREVIEWS[@]}"; do
            relaunch -preview "$scene"
            sleep 3
            xcrun simctl io booted screenshot "$OUT/$scene.png" >/dev/null
            echo "captured $OUT/$scene.png"
        done
        ;;
    shot)
        require_booted
        scene="${2:?usage: $0 shot <scene>}"
        relaunch -preview "$scene"
        sleep 3
        xcrun simctl io booted screenshot "$OUT/$scene.png" >/dev/null
        echo "captured $OUT/$scene.png"
        ;;
    gif)
        require_booted
        scene="${2:?usage: $0 gif <scene> [seconds]}"
        secs="${3:-6}"
        relaunch -preview "$scene"
        sleep 3
        record "$scene" "$secs"
        ;;
    demo)
        require_booted
        name="${2:?usage: $0 demo <name> [seconds]}"
        secs="${3:-8}"
        relaunch -demo "$name"
        sleep 3
        record "demo-$name" "$secs"
        ;;
    drag)
        require_booted
        name="${2:?usage: $0 drag <glass27|glassview> [seconds]}"
        secs="${3:-10}"
        relaunch -demo "$name" -autodrag 1
        sleep 2
        record "drag-$name" "$secs"
        ;;
    *)
        echo "unknown command: $cmd (use shots | shot | gif | demo | drag)" >&2
        exit 1
        ;;
esac
