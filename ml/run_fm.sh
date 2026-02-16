#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP="../app/DerivedData/Ficino/Build/Products/Debug/FMPromptRunner.app/Contents/MacOS/FMPromptRunner"

if [ ! -x "$APP" ]; then
    echo "Error: FMPromptRunner not built. Build it in Xcode first."
    exit 1
fi

DATA="$(pwd)/data"

"$APP" "$DATA/prompts_top100.jsonl" "$DATA/fm_instruction_v1.txt" "$DATA/output_$(date +%Y%m%d_%H%M%S).jsonl"
