#!/usr/bin/env bash
# Call from the existing authorized build before compiling the device artifact.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT="${1:-$SCRIPT_DIR/artifacts}"
if [[ "$OUTPUT" != /* ]]; then OUTPUT="$PWD/$OUTPUT"; fi
if [[ "$(uname -s)" != Darwin ]]; then
    printf '%s\n' 'This runner requires macOS with Xcode and an already installed iPhone Simulator runtime.' >&2
    exit 2
fi
for tool in xcrun codesign python3; do
    command -v "$tool" >/dev/null || { printf 'Missing tool: %s\n' "$tool" >&2; exit 2; }
done
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
if [[ -e "$OUTPUT/report.json" || -e "$OUTPUT/verification.json" ]]; then
    printf 'Use a fresh output directory to avoid stale simulator evidence: %s\n' "$OUTPUT" >&2
    exit 2
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dopamine-uikit.XXXXXX")"
UDID=""
collect_logs() {
    [[ -n "$UDID" ]] || return 0
    set +e
    python3 "$SCRIPT_DIR/verify.py" bounded 10 -- xcrun simctl spawn "$UDID" log show \
        --last 5m --style compact --info --debug \
        --predicate 'process == "DopamineLayoutHarness"' >"$OUTPUT/simulator.log" 2>"$OUTPUT/simulator-log.stderr.log"
    local status=$?
    printf '%s\n' "$status" >"$OUTPUT/simulator-log-status.txt"
    set -e
}
cleanup() {
    local status=$?
    trap - EXIT INT TERM
    set +e
    if [[ -n "$UDID" ]]; then
        [[ -f "$OUTPUT/simulator.log" ]] || collect_logs
        python3 "$SCRIPT_DIR/verify.py" bounded 8 -- xcrun simctl terminate "$UDID" dev.dopamine.layout-harness >/dev/null 2>&1
        python3 "$SCRIPT_DIR/verify.py" bounded 15 -- xcrun simctl shutdown "$UDID" >/dev/null 2>&1
        python3 "$SCRIPT_DIR/verify.py" bounded 15 -- xcrun simctl delete "$UDID" >/dev/null 2>&1
    fi
    rm -rf "$WORK"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

python3 "$SCRIPT_DIR/prepare.py" --repo "$REPO" --output "$WORK" | tee "$OUTPUT/staging.log"
cp "$WORK/source-manifest.json" "$OUTPUT/source-manifest.json"
xcrun --sdk iphonesimulator --show-sdk-path >"$WORK/sdk.txt"
SDK="$(cat "$WORK/sdk.txt")"
xcrun --sdk iphonesimulator --show-sdk-version >"$OUTPUT/sdk-version.txt"
ARCH="$(uname -m)"
case "$ARCH" in arm64|x86_64) ;; *) printf 'Unsupported simulator host architecture: %s\n' "$ARCH" >&2; exit 2 ;; esac
xcrun --sdk iphonesimulator clang -isysroot "$SDK" -target "$ARCH-apple-ios15.0-simulator" \
    -mios-simulator-version-min=15.0 -fobjc-arc -fblocks -O0 -g \
    -Wall -Wextra -Wno-unused-parameter -Werror=implicit-function-declaration \
    -I"$WORK/src" "$WORK/src/"*.m \
    -framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics -framework CoreImage \
    -o "$WORK/DopamineLayoutHarness.app/DopamineLayoutHarness" >"$OUTPUT/compile.log" 2>&1 || {
        cat "$OUTPUT/compile.log" >&2; exit 1;
    }
codesign --force --sign - --timestamp=none "$WORK/DopamineLayoutHarness.app" >"$OUTPUT/codesign.log" 2>&1
xcrun simctl list --json >"$OUTPUT/simulators.json"
python3 "$SCRIPT_DIR/verify.py" choose "$OUTPUT/simulators.json" >"$WORK/selection.txt"
DEVICE_TYPE="$(sed -n '1p' "$WORK/selection.txt")"
RUNTIME="$(sed -n '2p' "$WORK/selection.txt")"
UDID="$(xcrun simctl create "DopamineUIKit-$(basename "$WORK")" "$DEVICE_TYPE" "$RUNTIME")"
printf 'deviceType=%s\nruntime=%s\nudid=%s\n' "$DEVICE_TYPE" "$RUNTIME" "$UDID" >"$OUTPUT/selected-simulator.txt"
xcrun simctl boot "$UDID"
python3 "$SCRIPT_DIR/verify.py" bounded 120 -- xcrun simctl bootstatus "$UDID" -b >"$OUTPUT/boot.log" 2>&1
xcrun simctl status_bar "$UDID" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
python3 "$SCRIPT_DIR/verify.py" bounded 30 -- xcrun simctl install "$UDID" "$WORK/DopamineLayoutHarness.app" >"$OUTPUT/install.log" 2>&1
: >"$OUTPUT/app.stdout.log"
: >"$OUTPUT/app.stderr.log"
SIMCTL_CHILD_OS_ACTIVITY_MODE=enable python3 "$SCRIPT_DIR/verify.py" bounded 15 -- xcrun simctl launch \
    --terminate-running-process --stdout="$OUTPUT/app.stdout.log" --stderr="$OUTPUT/app.stderr.log" \
    "$UDID" dev.dopamine.layout-harness >"$OUTPUT/launch.log" 2>&1
python3 "$SCRIPT_DIR/verify.py" poll "$UDID" "$OUTPUT" >"$WORK/container.txt"
CONTAINER="$(cat "$WORK/container.txt")"
cp "$CONTAINER/Documents/report.json" "$OUTPUT/report.json"
for image in "$CONTAINER/Documents/"*.png; do
    [[ -f "$image" ]] && cp "$image" "$OUTPUT/"
done
python3 "$SCRIPT_DIR/verify.py" bounded 10 -- xcrun simctl io "$UDID" screenshot "$OUTPUT/simulator-screen.png" >"$OUTPUT/screenshot.log" 2>&1
# Termination flushes app console output before log and sentinel validation.
xcrun simctl terminate "$UDID" dev.dopamine.layout-harness
collect_logs
python3 "$SCRIPT_DIR/verify.py" check "$OUTPUT"
printf 'UIKit simulator regression evidence: %s\n' "$OUTPUT"
