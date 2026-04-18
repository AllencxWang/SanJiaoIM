#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INPUT="$ROOT/Vendor/3corner.cin"
OUTPUT="$ROOT/App/Resources/Lexicon.bin"

mkdir -p "$(dirname "$OUTPUT")"
cd "$ROOT/Tools/sanjiao-builder"
swift run -c release sanjiao-builder "$INPUT" "$OUTPUT"
ls -lh "$OUTPUT"
