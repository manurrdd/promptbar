#!/bin/zsh
# Builds, signs with Developer ID, notarizes and staples Promptbar.app,
# leaving a distributable Promptbar.zip.
#
# One-time setup:
#   1. A "Developer ID Application" certificate in your keychain
#      (Xcode > Settings > Accounts > Manage Certificates > + ).
#   2. Notarization credentials stored as a keychain profile:
#      xcrun notarytool store-credentials promptbar \
#        --apple-id <your-apple-id> --team-id <your-team-id>
set -e
cd "$(dirname "$0")"

PROFILE="${NOTARY_PROFILE:-promptbar}"
IDENTITY=$(security find-identity -v -p codesigning \
  | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
if [ -z "$IDENTITY" ]; then
  echo "No 'Developer ID Application' certificate found in the keychain." >&2
  exit 1
fi

./make-app.sh

echo "Signing with: $IDENTITY"
codesign --force --options runtime --timestamp --sign "$IDENTITY" Promptbar.app

ditto -c -k --keepParent Promptbar.app Promptbar.zip
echo "Submitting for notarization…"
xcrun notarytool submit Promptbar.zip --keychain-profile "$PROFILE" --wait

xcrun stapler staple Promptbar.app
ditto -c -k --keepParent Promptbar.app Promptbar.zip
echo "Done: Promptbar.zip (signed, notarized and stapled)"
