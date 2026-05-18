# signing/config.example.sh
#
# Copy this file to `signing/config.local.sh` and fill in your real
# values. `config.local.sh` is gitignored — it never ends up in
# version control.

# REQUIRED. Full code-signing identity string. Get it from:
#   security find-identity -v -p codesigning
# Example: "Apple Development: Jane Smith (TEAMID12)"
# Any usable identity works — Apple Development, Developer ID
# Application, or a third-party signing cert.
CODE_SIGN_IDENTITY=""

# OPTIONAL. Override the app bundle identifier. The upstream value is
# net.phere.GitX. Use a different reverse-DNS prefix you control if
# you want the signed app to live alongside another GitX installation.
# Example: com.example.gitx
PRODUCT_BUNDLE_IDENTIFIER=""
