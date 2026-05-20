#!/usr/bin/env bash
# Build git0 from source (if needed) and launch it.
#
# Usage:
#   ./run.sh             # build if stale, then launch
#   ./run.sh release     # Release config
#   ./run.sh clean       # wipe build/ then rebuild + launch
#   ./run.sh --build     # build (if stale) only, do not launch
#   ./run.sh --force     # force rebuild, even if fingerprint matches
#   ./run.sh --no-build  # never build, just launch the existing app
#
# A fingerprint of HEAD + working tree + submodule SHAs + bootstrap libs
# is stored next to the built app. If it matches the current state, the
# rebuild is skipped.
#
# Requires: Xcode + command line tools (xcodebuild).

set -euo pipefail

cd "$(dirname "$0")"

WORKSPACE="GitX.xcworkspace"
SCHEME="GitX"
CONFIG="Debug"
BUILD_DIR="$PWD/build"
LAUNCH=1
FORCE=0
SKIP_BUILD=0

for arg in "$@"; do
  case "$arg" in
    release|Release|--release) CONFIG="Release" ;;
    debug|Debug|--debug)       CONFIG="Debug" ;;
    clean|--clean)             rm -rf "$BUILD_DIR"; FORCE=1 ;;
    --build|--no-launch)       LAUNCH=0 ;;
    --force|-f)                FORCE=1 ;;
    --no-build)                SKIP_BUILD=1 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

APP_PATH="$BUILD_DIR/Build/Products/$CONFIG/git0.app"
FP_PATH="$BUILD_DIR/Build/Products/$CONFIG/.gitx-build-fingerprint"

# --- Fingerprint -------------------------------------------------------------
#
# Captures every signal that should invalidate a previous build. We hash the
# concatenation so the result is one short string we can compare.
compute_fingerprint() {
  {
    echo "config=$CONFIG"
    echo "head=$(git rev-parse HEAD 2>/dev/null || echo none)"

    # Modifications to tracked files (full diff content).
    git diff HEAD 2>/dev/null | shasum -a 256 | awk '{print "diff="$1}'

    # Untracked file list (presence/absence, not contents — adding a source
    # file requires modifying project.pbxproj which the diff above catches).
    git ls-files --others --exclude-standard 2>/dev/null | sort \
      | shasum -a 256 | awk '{print "untracked="$1}'

    # Submodule HEADs (recursive).
    git submodule status --recursive 2>/dev/null \
      | awk '{print $1, $2}' \
      | shasum -a 256 | awk '{print "submods="$1}'

    # Bootstrap static libs (objective-git links these in directly).
    for f in External/objective-git/External/libssh2.a \
             External/objective-git/External/libcrypto.a; do
      if [[ -f "$f" ]]; then
        shasum -a 256 "$f"
      else
        echo "missing $f"
      fi
    done
  } | shasum -a 256 | awk '{print $1}'
}

needs_rebuild() {
  [[ "$FORCE" -eq 1 ]] && return 0
  [[ ! -d "$APP_PATH" ]] && return 0
  [[ ! -f "$FP_PATH" ]] && return 0
  local current cached
  current=$(compute_fingerprint)
  cached=$(cat "$FP_PATH")
  [[ "$current" != "$cached" ]]
}

# --- Build dependency checks -------------------------------------------------
ensure_build_prereqs() {
  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "xcodebuild not found. Install Xcode and run: xcode-select --install" >&2
    exit 1
  fi

  # Submodules present?
  if [[ -d External/objective-git && -z "$(ls -A External/objective-git 2>/dev/null)" ]]; then
    echo "Submodules are not initialized. Run: git submodule update --init --recursive" >&2
    exit 1
  fi

  # objective-git's Xcode target links against prebuilt libssh2.a and libcrypto.a
  # living under External/objective-git/External/. Its script/bootstrap copies them
  # from Homebrew. If they're missing, run it.
  local og_ext="External/objective-git/External"
  if [[ ! -f "$og_ext/libssh2.a" || ! -f "$og_ext/libcrypto.a" ]]; then
    echo "==> Bootstrapping objective-git static libs (libssh2 + libcrypto)"
    if ! command -v brew >/dev/null 2>&1; then
      echo "Homebrew is required to bootstrap libssh2/openssl. See https://brew.sh" >&2
      exit 1
    fi
    ( cd External/objective-git && ./script/bootstrap )
  fi
}

# --- Build -------------------------------------------------------------------
do_build() {
  echo "==> Building $SCHEME ($CONFIG)"
  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'platform=macOS' \
    build | xcpretty 2>/dev/null \
  || xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'platform=macOS' \
    build

  if [[ ! -d "$APP_PATH" ]]; then
    # Fallback: search in case the products dir is named differently.
    APP_PATH="$(find "$BUILD_DIR/Build/Products" -maxdepth 3 -name 'git0.app' -print -quit 2>/dev/null || true)"
  fi

  if [[ ! -d "$APP_PATH" ]]; then
    echo "Build succeeded but git0.app was not found under $BUILD_DIR/Build/Products" >&2
    exit 1
  fi

  # Persist the fingerprint AFTER a successful build.
  mkdir -p "$(dirname "$FP_PATH")"
  compute_fingerprint > "$FP_PATH"
}

# --- Main --------------------------------------------------------------------
if [[ "$SKIP_BUILD" -eq 1 ]]; then
  if [[ ! -d "$APP_PATH" ]]; then
    echo "--no-build requested but $APP_PATH does not exist." >&2
    exit 1
  fi
  echo "==> Skipping build (--no-build)"
elif needs_rebuild; then
  ensure_build_prereqs
  do_build
else
  echo "==> Up to date, skipping build ($APP_PATH)"
fi

echo "==> $APP_PATH"

if [[ "$LAUNCH" -eq 1 ]]; then
  echo "==> Launching git0"
  open -a "$APP_PATH"
fi
