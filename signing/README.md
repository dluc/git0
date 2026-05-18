# Signing GitX with your Apple Developer ID

This folder is for **building GitX and re-signing the result with your
own Apple Developer identity**. Everything in it is gitignored —
your certificate name, team ID, and any build output never end up in
version control.

## How it works (in one paragraph)

The repository's Xcode project uses ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`)
for every target — GitX itself plus the bundled `Sparkle`, `ObjectiveGit`,
and `MGScopeBar` subprojects. Wiring a real identity into Xcode's
build-time signing means touching all of those subprojects' signing
settings and lining up a provisioning profile. We don't do that. Instead
`build.sh` lets the build complete with the default ad-hoc signing,
then walks the resulting `.app` and re-signs every framework, XPC
service, helper bundle, and executable with **your** identity using
`codesign` directly. The bundle identifiers and entitlements Xcode
embedded during the build pass are preserved; only the signing
identity changes.

## One-time setup

1. Make sure you have a usable code-signing identity in your keychain:

   ```bash
   security find-identity -v -p codesigning
   ```

   Any of these work:
   - `Apple Development: Your Name (TEAMID12)`
   - `Developer ID Application: Your Name (TEAMID12)`
   - A third-party signing cert (rare)

   Copy the **full string** (the part in quotes in the output).

2. Copy the template config and fill it in:

   ```bash
   cp signing/config.example.sh signing/config.local.sh
   $EDITOR signing/config.local.sh
   ```

   Required:
   - `CODE_SIGN_IDENTITY` — the full identity string from step 1.

   Optional:
   - `PRODUCT_BUNDLE_IDENTIFIER` — override the upstream
     `net.phere.GitX` bundle ID. Useful if you want your signed build to
     install alongside another GitX without conflicting.

## Usage

```bash
./signing/build.sh          # Release build, signed with your identity
./signing/build.sh debug    # Debug build, signed with your identity
./signing/build.sh verify   # Re-verify the last build's signature
./signing/build.sh open     # Reveal the signed build in Finder
```

The signed app lands at `signing/out/GitX.app`. That directory is also
gitignored.

## What gets signed

`build.sh` finds and signs, deepest-first:

- Every `.framework`, `.bundle`, `.app`, and `.xpc` inside the bundle —
  so Sparkle's XPC services, the Updater helper, ObjectiveGit, and
  MGScopeBar all get re-signed.
- The `gitx` CLI shim and `gitx_askpasswd` helper in
  `Contents/Resources/`.
- The main `GitX.app` itself, last.

Each `codesign` call uses `--options runtime --timestamp
--preserve-metadata=identifier,entitlements,flags` — that's the
hardened-runtime + Apple-timestamped pattern required for notarization
or Gatekeeper-friendly distribution.

## Notes

- This does **not** notarize. Notarization needs an Apple ID
  app-specific password and `xcrun notarytool`, which are
  environment-specific enough that bundling them here would muddy the
  script. Adding a `notarize` subcommand later is a small step when
  you actually need to distribute outside your machine.
- If `signing/config.local.sh` doesn't exist `build.sh` prints a
  one-liner pointing you back here rather than failing halfway through
  `xcodebuild`.
- If you previously tried Xcode-time signing and have a half-broken
  `signing/out/DerivedData` from that, `build.sh` wipes it at the start
  of each run so you start clean.
