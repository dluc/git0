#!/usr/bin/env bash
# signing/build.sh
#
# Build GitX with the repository's existing ad-hoc signing, then
# re-sign every binary inside the .app with your Apple Developer
# identity. This avoids fighting Xcode's per-subproject signing
# configuration (Sparkle, ObjectiveGit, MGScopeBar each have their own)
# and works with any usable code-signing identity in your keychain —
# Apple Development, Developer ID Application, or third-party.
#
# Usage:
#   ./signing/build.sh           # Release build, signed (default)
#   ./signing/build.sh debug     # Debug build, signed
#   ./signing/build.sh verify    # Re-verify the last build's signature
#   ./signing/build.sh open      # Reveal the signed build in Finder
#   ./signing/build.sh --help    # Show this help
#
# Reads signing identity from signing/config.local.sh (gitignored).
# See signing/README.md for setup.

set -euo pipefail

# Resolve to the repo root regardless of where this is run from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

CONFIG_FILE="signing/config.local.sh"
WORKSPACE="GitX.xcworkspace"
SCHEME="GitX"
OUT_DIR="$SCRIPT_DIR/out"
APP_PATH="$OUT_DIR/GitX.app"

mode="release"
if [[ $# -gt 0 ]]; then
  case "$1" in
    release|Release|--release) mode="release" ;;
    debug|Debug|--debug)       mode="debug" ;;
    verify|--verify)           mode="verify" ;;
    open|--open|reveal)        mode="open" ;;
    -h|--help)
      sed -n '2,21p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
fi

# --- verify / open shortcuts -------------------------------------------------
if [[ "$mode" == "verify" ]]; then
  if [[ ! -d "$APP_PATH" ]]; then
    echo "No signed build at $APP_PATH yet. Run ./signing/build.sh first." >&2
    exit 1
  fi
  echo "==> codesign verify"
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  echo
  echo "==> Signing summary"
  codesign --display --verbose=2 "$APP_PATH" 2>&1 | grep -E "^Identifier|^Authority|^TeamIdentifier|^Signed Time|^Timestamp"
  echo
  echo "==> spctl assess"
  spctl --assess --type execute --verbose=2 "$APP_PATH" || true
  exit 0
fi

if [[ "$mode" == "open" ]]; then
  if [[ ! -d "$APP_PATH" ]]; then
    echo "No signed build at $APP_PATH yet. Run ./signing/build.sh first." >&2
    exit 1
  fi
  open -R "$APP_PATH"
  exit 0
fi

# --- load local config -------------------------------------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing $CONFIG_FILE." >&2
  echo "Copy signing/config.example.sh -> signing/config.local.sh and fill it in." >&2
  echo "See signing/README.md for details." >&2
  exit 1
fi

# shellcheck source=signing/config.local.sh
source "$CONFIG_FILE"

: "${CODE_SIGN_IDENTITY:?Set CODE_SIGN_IDENTITY in $CONFIG_FILE}"

if [[ "$mode" == "release" ]]; then
  CONFIG="Release"
else
  CONFIG="Debug"
fi

# --- build prerequisites -----------------------------------------------------
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode and run: xcode-select --install" >&2
  exit 1
fi

# Reuse the same objective-git External/ bootstrap as run.sh.
if [[ -d External/objective-git && -z "$(ls -A External/objective-git 2>/dev/null)" ]]; then
  echo "Submodules are not initialized. Run: git submodule update --init --recursive" >&2
  exit 1
fi
OG_EXT="External/objective-git/External"
if [[ ! -f "$OG_EXT/libssh2.a" || ! -f "$OG_EXT/libcrypto.a" ]]; then
  echo "==> Bootstrapping objective-git static libs (libssh2 + libcrypto)"
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to bootstrap libssh2/openssl. See https://brew.sh" >&2
    exit 1
  fi
  ( cd External/objective-git && ./script/bootstrap )
fi

# --- 1) Build with the repository's default ad-hoc signing -------------------
# We don't override CODE_SIGN_STYLE / DEVELOPMENT_TEAM / CODE_SIGN_IDENTITY
# here — the project sets CODE_SIGN_IDENTITY="-" for every target, and that
# works fine. The real identity is applied in step 3 with codesign.
echo "==> Build configuration: $CONFIG (ad-hoc, will resign post-build)"

mkdir -p "$OUT_DIR"
# Reuse the top-level build/ DerivedData that run.sh uses. Keeping a
# separate DerivedData under signing/ caused races and stale-artefact
# issues; sharing means incremental builds work correctly between the
# dev launcher and the signing flow.
DERIVED_DATA="$PWD/build"
rm -rf "$APP_PATH"

# IMPORTANT: do NOT pass PRODUCT_BUNDLE_IDENTIFIER on the xcodebuild
# command line. xcodebuild applies command-line build settings to every
# target in every project in the workspace, which means a Sparkle
# subproject target like Updater.app would also get our override and
# end up claiming the same bundle id as the main app. That trips
# Launch Services into returning the Updater proxy when something
# looks up our id, which then crashes Scripting Bridge with
# 'unrecognized selector open:withOptions:'.
#
# We let xcodebuild run with the project's default per-target bundle
# ids and rewrite ONLY the main app's Info.plist below.
#
# Pipe xcodebuild through tail -100 so we don't drown the terminal
# while still surfacing failures.
set -o pipefail
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'platform=macOS' \
  build 2>&1 | tail -100

BUILT_APP="$DERIVED_DATA/Build/Products/$CONFIG/GitX.app"
if [[ ! -d "$BUILT_APP" ]]; then
  BUILT_APP="$(find "$DERIVED_DATA/Build/Products" -maxdepth 3 -name 'GitX.app' -print -quit 2>/dev/null || true)"
fi
if [[ ! -d "$BUILT_APP" ]]; then
  echo "Build succeeded(?) but GitX.app was not found under $DERIVED_DATA/Build/Products" >&2
  exit 1
fi

# --- 2) Copy to out/ ---------------------------------------------------------
cp -R "$BUILT_APP" "$APP_PATH"

# --- 2b) Rewrite the main app's bundle id if the user asked for one ---------
# Only the outermost Info.plist is touched. Sparkle/ObjectiveGit/MGScopeBar
# bundles keep their own identifiers. We use plutil instead of defaults so
# the change applies exactly to the file we point at (defaults caches the
# domain by absolute path and writes through the modern preference system,
# which is the wrong layer here).
if [[ -n "${PRODUCT_BUNDLE_IDENTIFIER:-}" ]]; then
  echo
  echo "==> Setting bundle identifier on the main app: $PRODUCT_BUNDLE_IDENTIFIER"
  plutil -replace CFBundleIdentifier -string "$PRODUCT_BUNDLE_IDENTIFIER" \
    "$APP_PATH/Contents/Info.plist"
fi

# --- 3) Resign everything with the user's identity --------------------------
echo
echo "==> Resigning with identity: $CODE_SIGN_IDENTITY"

# Find all signable bundles inside the .app (frameworks, helper apps,
# XPC services, plug-in bundles) and sign them deepest-first. We
# sort by path length descending — longer paths are deeper in the
# hierarchy, so they get signed before their containers.
#
# We do NOT preserve the identifier: when the user overrides
# PRODUCT_BUNDLE_IDENTIFIER we just rewrote the main app's Info.plist
# above, and codesign needs to re-read it from there. Preserving the
# identifier would carry the old ad-hoc value forward and the new
# signature would point at the wrong bundle id.
#
# We DO preserve entitlements and flags so the hardened-runtime
# entitlements Xcode embedded survive the resign.
sign_bundle() {
  local item="$1"
  codesign --force --sign "$CODE_SIGN_IDENTITY" \
    --options runtime --timestamp \
    --preserve-metadata=entitlements,flags \
    "$item"
}

while IFS= read -r item; do
  echo "    $item"
  sign_bundle "$item"
done < <(find "$APP_PATH" \
  \( -name '*.framework' -o -name '*.bundle' -o -name '*.app' -o -name '*.xpc' \) \
  -type d \
  | awk '{ print length($0), $0 }' | sort -rn | cut -d' ' -f2-)

# Sign loose helper binaries in Resources/ that aren't part of any
# bundle (GitX ships the `gitx` CLI shim and `gitx_askpasswd` here).
for tool in "$APP_PATH/Contents/Resources/gitx" "$APP_PATH/Contents/Resources/gitx_askpasswd"; do
  if [[ -f "$tool" ]]; then
    echo "    $tool"
    codesign --force --sign "$CODE_SIGN_IDENTITY" \
      --options runtime --timestamp \
      --preserve-metadata=entitlements,flags \
      "$tool"
  fi
done

# Finally sign the main .app itself.
echo "    $APP_PATH"
sign_bundle "$APP_PATH"

# --- 4) Verify ---------------------------------------------------------------
echo
echo "==> codesign verify"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo
echo "==> Signing summary"
codesign --display --verbose=2 "$APP_PATH" 2>&1 \
  | grep -E "^Identifier|^Authority|^TeamIdentifier|^Signed Time|^Timestamp" || true

echo
echo "==> Done"
echo "    $APP_PATH"
echo "    Run './signing/build.sh open'   to reveal it in Finder."
echo "    Run './signing/build.sh verify' to re-verify the signature."
