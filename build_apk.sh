#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$project_dir/../output"
godot --headless --path "$project_dir" --editor --import --quit
godot --headless --path "$project_dir" --export-release Android "$project_dir/../output/VESPER-1.0.apk"
