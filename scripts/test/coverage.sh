#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

MIN_COVERAGE="${COVERAGE_MIN:-15}"
IGNORE_REGEX='(\.build/|Tests/|MacMicWidgetApp.swift|MenuBarView.swift|CoreAudioMicrophoneBackend.swift)'

swift test --enable-code-coverage

PROFDATA_PATH=""
for path in .build/*/codecov/default.profdata; do
  if [[ -f "$path" ]]; then
    PROFDATA_PATH="$path"
    break
  fi
done

if [[ -z "$PROFDATA_PATH" ]]; then
  echo "Coverage profile not found under .build/*/codecov/default.profdata" >&2
  exit 1
fi

BIN_PATH="$(swift build --show-bin-path)"
TEST_BINARY="$BIN_PATH/MacMicWidgetPackageTests.xctest/Contents/MacOS/MacMicWidgetPackageTests"
APP_BINARY="$BIN_PATH/MacMicWidget"

if [[ ! -x "$TEST_BINARY" ]]; then
  echo "Test binary not found: $TEST_BINARY" >&2
  exit 1
fi

if [[ ! -x "$APP_BINARY" ]]; then
  echo "App binary not found: $APP_BINARY" >&2
  exit 1
fi

mkdir -p coverage

xcrun llvm-cov export \
  -format=text \
  -instr-profile "$PROFDATA_PATH" \
  "$TEST_BINARY" \
  -object "$APP_BINARY" \
  -ignore-filename-regex "$IGNORE_REGEX" > coverage/coverage-summary.txt

xcrun llvm-cov report \
  -instr-profile "$PROFDATA_PATH" \
  "$TEST_BINARY" \
  -object "$APP_BINARY" \
  -ignore-filename-regex "$IGNORE_REGEX" > coverage/coverage-report.txt

TOTAL_LINE="$(awk '/^TOTAL/ { print; exit }' coverage/coverage-report.txt)"
TOTAL_PERCENT="$(echo "$TOTAL_LINE" | awk '{print $10}' | tr -d '%')"

if [[ -z "$TOTAL_PERCENT" ]]; then
  echo "Failed to parse total line coverage from coverage-report.txt" >&2
  exit 1
fi

echo "Total line coverage: ${TOTAL_PERCENT}%"
echo "Coverage report: coverage/coverage-report.txt"
echo "Coverage summary: coverage/coverage-summary.txt"

if awk "BEGIN { exit !($TOTAL_PERCENT < $MIN_COVERAGE) }"; then
  echo "Coverage ${TOTAL_PERCENT}% is below threshold ${MIN_COVERAGE}%." >&2
  exit 1
fi

echo "Coverage threshold check passed (>= ${MIN_COVERAGE}%)."
