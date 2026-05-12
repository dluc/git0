#!/usr/bin/env bash
# Compile GitX from source without launching it.
#
# Usage:
#   ./compile.sh             # Debug build
#   ./compile.sh release     # Release build
#   ./compile.sh clean       # wipe build/ then build
#
# Thin wrapper around run.sh. Same args, just adds --build (no launch).

set -euo pipefail
cd "$(dirname "$0")"

exec ./run.sh --build "$@"
