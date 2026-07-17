#!/bin/sh
set -eu

# Use --static to run repository validators, unit contracts, formatting, and
# shell syntax without invoking XcodeGen, simctl, xcodebuild, or IPA packaging.
# With no arguments, every production CI gate runs.
usage() {
  echo "usage: ci_validate_tvos.sh [--static]" >&2
  exit 2
}

MODE=full
case $# in
  0) ;;
  1) [ "$1" = "--static" ] || usage; MODE=static ;;
  *) usage ;;
esac

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT_DIR=${SIDELOAD_OUTPUT_DIR:-"$ROOT/artifacts"}
case "$OUTPUT_DIR" in
  /*) ;;
  *) OUTPUT_DIR="$ROOT/$OUTPUT_DIR" ;;
esac

TOOLS="python3 swift-format"
if [ "$MODE" = full ]; then
  TOOLS="$TOOLS xcodegen xcodebuild xcrun"
fi
for tool in $TOOLS; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: missing required tool: $tool" >&2
    exit 1
  }
done

cd "$ROOT"

echo "==> Validating project contracts"
python3 scripts/validate_project.py

echo "==> Running Python contract tests"
python3 -m unittest discover -s scripts/tests -v

echo "==> Linting Swift sources"
swift-format lint --recursive VelyraTV VelyraTVTests Shared VelyraTopShelf

if [ "$MODE" = static ]; then
  sh -n "$ROOT/scripts/ci_validate_tvos.sh" "$ROOT/scripts/build_sideload_ipa.sh"
  echo "Velyra tvOS static validation passed"
  exit 0
fi

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Resolving an available tvOS Simulator"
SIMULATOR_JSON=$(xcrun simctl list devices available -j)
if DEVICE_ID=$(printf '%s' "$SIMULATOR_JSON" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    if "tvOS" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and device.get("udid"):
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(1)
'); then
  :
else
  echo "ERROR: no available tvOS Simulator found; available-device JSON follows" >&2
  printf '%s\n' "$SIMULATOR_JSON" >&2
  exit 1
fi

echo "==> Testing on tvOS Simulator"
xcodebuild \
  -project Velyra.xcodeproj \
  -scheme VelyraTV \
  -sdk appletvsimulator \
  -destination "platform=tvOS Simulator,id=$DEVICE_ID" \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  test

echo "==> Building all VelyraTV targets for generic tvOS"
xcodebuild \
  -project Velyra.xcodeproj \
  -scheme VelyraTV \
  -configuration Release \
  -destination 'generic/platform=tvOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

echo "==> Packaging unsigned sideload IPA"
SIDELOAD_OUTPUT_DIR=$OUTPUT_DIR
export SIDELOAD_OUTPUT_DIR
"$ROOT/scripts/build_sideload_ipa.sh"

IPA="$OUTPUT_DIR/Velyra-sideload.ipa"
CHECKSUM="$OUTPUT_DIR/Velyra-sideload.ipa.sha256"
[ -s "$IPA" ] || { echo "ERROR: missing or empty IPA: $IPA" >&2; exit 1; }
[ -s "$CHECKSUM" ] || { echo "ERROR: missing or empty checksum: $CHECKSUM" >&2; exit 1; }

echo "Velyra tvOS validation passed"
echo "IPA: $OUTPUT_DIR/Velyra-sideload.ipa"
echo "SHA256: $OUTPUT_DIR/Velyra-sideload.ipa.sha256"
