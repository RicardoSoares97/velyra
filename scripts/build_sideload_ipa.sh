#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

for tool in python3 xcodegen xcodebuild swift-format; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: missing required tool: $tool" >&2
    exit 1
  }
done

for tool in /usr/bin/ditto /usr/bin/unzip /usr/libexec/PlistBuddy /usr/bin/codesign /usr/bin/shasum /usr/bin/grep; do
  [ -x "$tool" ] || {
    echo "ERROR: missing required tool: $tool" >&2
    exit 1
  }
done

if [ "${SIDELOAD_BUILD_ROOT+x}" = x ]; then
  BUILD_ROOT_INPUT=$SIDELOAD_BUILD_ROOT
else
  BUILD_ROOT_INPUT="$ROOT/.sideload-build"
fi
if [ "${SIDELOAD_OUTPUT_DIR+x}" = x ]; then
  OUTPUT_DIR_INPUT=$SIDELOAD_OUTPUT_DIR
else
  OUTPUT_DIR_INPUT="$ROOT/artifacts"
fi

[ -n "$BUILD_ROOT_INPUT" ] || { echo "ERROR: unsafe empty SIDELOAD_BUILD_ROOT" >&2; exit 1; }
[ -n "$OUTPUT_DIR_INPUT" ] || { echo "ERROR: unsafe empty SIDELOAD_OUTPUT_DIR" >&2; exit 1; }
case "$BUILD_ROOT_INPUT" in /*) ;; *) BUILD_ROOT_INPUT="$ROOT/$BUILD_ROOT_INPUT" ;; esac
case "$OUTPUT_DIR_INPUT" in /*) ;; *) OUTPUT_DIR_INPUT="$ROOT/$OUTPUT_DIR_INPUT" ;; esac
BUILD_ROOT=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$BUILD_ROOT_INPUT")
OUTPUT_DIR=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$OUTPUT_DIR_INPUT")
case "$BUILD_ROOT" in /|"$ROOT") echo "ERROR: unsafe SIDELOAD_BUILD_ROOT: $BUILD_ROOT" >&2; exit 1 ;; esac
case "$OUTPUT_DIR" in /|"$ROOT") echo "ERROR: unsafe SIDELOAD_OUTPUT_DIR: $OUTPUT_DIR" >&2; exit 1 ;; esac

DEFAULT_BUILD_ROOT="$ROOT/.sideload-build"
BUILD_ROOT_MARKER="$BUILD_ROOT/.velyra-sideload-build-root"
if [ -e "$BUILD_ROOT" ] && [ ! -d "$BUILD_ROOT" ]; then
  echo "ERROR: SIDELOAD_BUILD_ROOT is not a directory: $BUILD_ROOT" >&2
  exit 1
fi
if [ -d "$BUILD_ROOT" ] && [ "$BUILD_ROOT" != "$DEFAULT_BUILD_ROOT" ]; then
  if [ ! -f "$BUILD_ROOT_MARKER" ] || [ -L "$BUILD_ROOT_MARKER" ]; then
    echo "ERROR: refusing to clean unowned SIDELOAD_BUILD_ROOT: $BUILD_ROOT" >&2
    exit 1
  fi
fi

ARCHIVE="$BUILD_ROOT/VelyraSideload.xcarchive"
PACKAGE="$BUILD_ROOT/package"
IPA="$OUTPUT_DIR/Velyra-sideload.ipa"
CHECKSUM="$OUTPUT_DIR/Velyra-sideload.ipa.sha256"
STAGING_DIR="$OUTPUT_DIR/.velyra-sideload-staging.$$"
STAGED_IPA="$STAGING_DIR/Velyra-sideload.ipa"
STAGED_CHECKSUM="$STAGING_DIR/Velyra-sideload.ipa.sha256"
IPA_BACKUP="$OUTPUT_DIR/.Velyra-sideload.ipa.backup.$$"
CHECKSUM_BACKUP="$OUTPUT_DIR/.Velyra-sideload.ipa.sha256.backup.$$"
PROVIDER_XCCONFIG="$BUILD_ROOT/providers.xcconfig"
STAGING_CREATED=0
PUBLISH_STARTED=0
PUBLISH_COMPLETE=0
IPA_BACKED_UP=0
CHECKSUM_BACKED_UP=0
NEW_IPA_PUBLISHED=0
NEW_CHECKSUM_PUBLISHED=0

rollback_publication() {
  if [ "$PUBLISH_STARTED" -eq 1 ] && [ "$PUBLISH_COMPLETE" -eq 0 ]; then
    [ "$NEW_CHECKSUM_PUBLISHED" -eq 0 ] || /bin/rm -f "$CHECKSUM"
    [ "$NEW_IPA_PUBLISHED" -eq 0 ] || /bin/rm -f "$IPA"
    if [ "$IPA_BACKED_UP" -eq 1 ] && [ -e "$IPA_BACKUP" ]; then
      /bin/mv "$IPA_BACKUP" "$IPA"
    fi
    if [ "$CHECKSUM_BACKED_UP" -eq 1 ] && [ -e "$CHECKSUM_BACKUP" ]; then
      /bin/mv "$CHECKSUM_BACKUP" "$CHECKSUM"
    fi
  fi
}

cleanup() {
  status=$?
  trap - 0 HUP INT TERM
  rollback_publication
  [ -z "${PROVIDER_XCCONFIG-}" ] || /bin/rm -f "$PROVIDER_XCCONFIG"
  [ "$STAGING_CREATED" -eq 0 ] || /bin/rm -rf "$STAGING_DIR"
  if [ "$PUBLISH_COMPLETE" -eq 1 ]; then
    [ "$IPA_BACKED_UP" -eq 0 ] || /bin/rm -f "$IPA_BACKUP"
    [ "$CHECKSUM_BACKED_UP" -eq 0 ] || /bin/rm -f "$CHECKSUM_BACKUP"
  fi
  exit "$status"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

publish_artifacts() {
  PUBLISH_STARTED=1
  if [ -e "$IPA" ]; then
    IPA_BACKED_UP=1
    /bin/mv "$IPA" "$IPA_BACKUP"
  fi
  if [ -e "$CHECKSUM" ]; then
    CHECKSUM_BACKED_UP=1
    /bin/mv "$CHECKSUM" "$CHECKSUM_BACKUP"
  fi
  NEW_IPA_PUBLISHED=1
  /bin/mv "$STAGED_IPA" "$IPA"
  NEW_CHECKSUM_PUBLISHED=1
  /bin/mv "$STAGED_CHECKSUM" "$CHECKSUM"
  PUBLISH_COMPLETE=1
  [ "$IPA_BACKED_UP" -eq 0 ] || /bin/rm -f "$IPA_BACKUP"
  [ "$CHECKSUM_BACKED_UP" -eq 0 ] || /bin/rm -f "$CHECKSUM_BACKUP"
}

validate_provider_value() {
  name=$1
  value=$2
  case "$value" in
    *'
'*) echo "ERROR: $name must not contain newlines" >&2; exit 1 ;;
    *[!A-Za-z0-9._~+=-]*) echo "ERROR: $name contains unsafe characters" >&2; exit 1 ;;
  esac
}

TRAKT_CLIENT_ID_VALUE=${TRAKT_CLIENT_ID-}
TRAKT_CLIENT_SECRET_VALUE=${TRAKT_CLIENT_SECRET-}
TMDB_READ_ACCESS_TOKEN_VALUE=${TMDB_READ_ACCESS_TOKEN-}
validate_provider_value TRAKT_CLIENT_ID "$TRAKT_CLIENT_ID_VALUE"
validate_provider_value TRAKT_CLIENT_SECRET "$TRAKT_CLIENT_SECRET_VALUE"
validate_provider_value TMDB_READ_ACCESS_TOKEN "$TMDB_READ_ACCESS_TOKEN_VALUE"

/bin/rm -rf "$BUILD_ROOT"
/bin/mkdir -p "$BUILD_ROOT" "$OUTPUT_DIR"
printf '%s\n' 'Velyra sideload build root' > "$BUILD_ROOT_MARKER"
/bin/mkdir "$STAGING_DIR"
STAGING_CREATED=1
umask 077
{
  printf 'TRAKT_CLIENT_ID = %s\n' "$TRAKT_CLIENT_ID_VALUE"
  printf 'TRAKT_CLIENT_SECRET = %s\n' "$TRAKT_CLIENT_SECRET_VALUE"
  printf 'TMDB_READ_ACCESS_TOKEN = %s\n' "$TMDB_READ_ACCESS_TOKEN_VALUE"
} > "$PROVIDER_XCCONFIG"
chmod 600 "$PROVIDER_XCCONFIG"
unset TRAKT_CLIENT_ID TRAKT_CLIENT_SECRET TMDB_READ_ACCESS_TOKEN
unset TRAKT_CLIENT_ID_VALUE TRAKT_CLIENT_SECRET_VALUE TMDB_READ_ACCESS_TOKEN_VALUE

cd "$ROOT"
echo "==> Validating project"
python3 scripts/validate_project.py
echo "==> Linting Swift sources"
swift-format lint --recursive VelyraTV VelyraTVTests Shared VelyraTopShelf
echo "==> Generating Xcode project"
xcodegen generate
echo "==> Archiving unsigned sideload app"
xcodebuild \
  -project Velyra.xcodeproj \
  -scheme VelyraTVSideload \
  -configuration Release \
  -destination 'generic/platform=tvOS' \
  -archivePath "$ARCHIVE" \
  -xcconfig "$PROVIDER_XCCONFIG" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive

ARCHIVE_APP="$ARCHIVE/Products/Applications/Velyra.app"
[ -d "$ARCHIVE_APP" ] || { echo "ERROR: archive app missing: $ARCHIVE_APP" >&2; exit 1; }

echo "==> Packaging IPA"
/bin/mkdir -p "$PACKAGE/Payload"
/usr/bin/ditto "$ARCHIVE_APP" "$PACKAGE/Payload/Velyra.app"
(
  cd "$PACKAGE"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent Payload "$STAGED_IPA"
)

ZIP_LIST="$BUILD_ROOT/ipa-entries.txt"
/usr/bin/unzip -Z1 "$STAGED_IPA" > "$ZIP_LIST"
/usr/bin/grep -Fx 'Payload/Velyra.app/Info.plist' "$ZIP_LIST" >/dev/null || {
  echo "ERROR: IPA is missing Payload/Velyra.app/Info.plist" >&2
  exit 1
}
while IFS= read -r entry; do
  case "$entry" in
    Payload|Payload/|Payload/Velyra.app|Payload/Velyra.app/|Payload/Velyra.app/*) ;;
    *) echo "ERROR: unexpected IPA entry: $entry" >&2; exit 1 ;;
  esac
  case "$entry" in
    *.appex|*.appex/*) echo "ERROR: IPA contains an app extension" >&2; exit 1 ;;
    */embedded.mobileprovision) echo "ERROR: IPA contains embedded.mobileprovision" >&2; exit 1 ;;
    */_CodeSignature|*/_CodeSignature/*) echo "ERROR: IPA contains a _CodeSignature directory" >&2; exit 1 ;;
  esac
done < "$ZIP_LIST"

PACKAGED_APP="$PACKAGE/Payload/Velyra.app"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PACKAGED_APP/Info.plist")
[ "$BUNDLE_ID" = "pt.ricardosoares.velyra.sideload" ] || {
  echo "ERROR: unexpected CFBundleIdentifier" >&2
  exit 1
}

if /usr/bin/codesign -d "$PACKAGED_APP" >/dev/null 2>&1; then
  ENTITLEMENTS="$BUILD_ROOT/codesign-entitlements.plist"
  /usr/bin/codesign -d --entitlements :- "$PACKAGED_APP" > "$ENTITLEMENTS" 2>/dev/null || {
    echo "ERROR: unable to inspect signature entitlements" >&2
    exit 1
  }
  for key in \
    com.apple.developer.icloud-container-identifiers \
    com.apple.developer.icloud-services \
    com.apple.developer.ubiquity-kvstore-identifier \
    com.apple.security.application-groups
  do
    if /usr/bin/grep -F "$key" "$ENTITLEMENTS" >/dev/null; then
      echo "ERROR: signed app contains restricted entitlement: $key" >&2
      exit 1
    fi
  done
else
  echo "==> App is unsigned, as expected"
fi

(
  cd "$STAGING_DIR"
  /usr/bin/shasum -a 256 Velyra-sideload.ipa > Velyra-sideload.ipa.sha256
)
publish_artifacts
printf '%s\n' "$IPA"
printf '%s\n' "$CHECKSUM"
