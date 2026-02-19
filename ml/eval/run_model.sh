#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -z "${1:-}" ]; then
    echo "Usage: run_model.sh <version-tag> [prompts-file] [extra args...]"
    echo "  e.g. run_model.sh v19"
    echo "       run_model.sh v19 data/eval/my_prompts.jsonl -l 10"
    exit 1
fi
VERSION="$1"; shift

APP="../../app/DerivedData/Ficino/Build/Products/Debug/FMPromptRunner.app/Contents/MacOS/FMPromptRunner"

if [ ! -x "$APP" ]; then
    echo "Error: FMPromptRunner not built. Build it in Xcode first."
    exit 1
fi

DATA="$(pwd)/../data"

# Optional prompts file as second arg, default to standard eval set
if [ -n "${1:-}" ] && [ -f "$1" ]; then
    PROMPTS_FILE="$1"; shift
else
    PROMPTS_FILE="$DATA/eval/prompts_top100.jsonl"
fi

OUTPUT="$DATA/eval/output_${VERSION}_$(date +%Y%m%d_%H%M%S).jsonl"
mkdir -p "$(dirname "$OUTPUT")"

INSTRUCTION="$DATA/../prompts/fm_instruction_${VERSION}.json"

if [ ! -f "$INSTRUCTION" ]; then
    echo "Error: $INSTRUCTION not found."
    exit 1
fi

"$APP" "$PROMPTS_FILE" "$INSTRUCTION" "$OUTPUT" "$@"
