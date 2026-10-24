#!/usr/bin/env bash
# Story Starter: first install on a Mac, from one line, with no browser.
#
#   Public version (once one is published):
#     curl -fsSL https://medialabs-93.github.io/story-starter-updates/install.sh | bash
#   Developer version:
#     curl -fsSL https://medialabs-93.github.io/story-starter-updates/install.sh | bash -s -- --channel developer
#
# It reads the update feed over HTTPS, downloads the disk image from the Story Starter updates releases,
# checks its size and SHA-256 against the feed, checks the app's Apple signature, copies the app to
# Applications and opens it. After that one install the app updates itself, inside the app.
#
# Honest limits: the checksum comes from the same GitHub account as the file, so this protects against a
# damaged or swapped download, not a compromised account (the app's own updater also checks a signature
# made with a key that is not on GitHub). Not yet run on a real Mac as of 2026-10-24; the control flow
# is tested with stand-ins for the Mac tools (test/update/install_scripts_test.dart).
set -eu

CHANNEL="stable"
ALLOW_UNSIGNED=0
NO_START=0
FEED_URL="${SS_FEED_URL:-https://medialabs-93.github.io/story-starter-updates/latest.json}"
PREFIX="${SS_ALLOWED_PREFIX:-https://github.com/medialabs-93/story-starter-updates/releases/download/}"
DEST_DIR="${SS_DEST_DIR:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --channel) CHANNEL="${2:-}"; shift 2 ;;
    --allow-unsigned) ALLOW_UNSIGNED=1; shift ;;
    --no-start) NO_START=1; shift ;;
    *) echo "Story Starter installer: unknown option $1" >&2; exit 2 ;;
  esac
done

fail() { echo "Story Starter installer: $1" >&2; exit 1; }

case "$CHANNEL" in stable|developer) ;; *) fail "the channel must be stable or developer" ;; esac
[ "$(uname)" = "Darwin" ] || fail "this installer is for a Mac. On Windows use install.ps1."

work="$(mktemp -d)"
mnt=""
cleanup() {
  if [ -n "$mnt" ] && [ -d "$mnt" ]; then hdiutil detach "$mnt" -quiet >/dev/null 2>&1 || true; fi
  rm -rf "$work"
}
trap cleanup EXIT

echo "Looking up the newest Story Starter ($CHANNEL) ..."
curl -fsSL --proto '=https,file' "$FEED_URL?t=$(( $(date +%s) / 60 ))" -o "$work/latest.json" \
  || fail "could not read the update information. Check your internet connection."

extract() { plutil -extract "$1" raw -o - "$work/latest.json" 2>/dev/null || true; }
url="$(extract "channels.$CHANNEL.downloads.mac.url")"
sha="$(extract "channels.$CHANNEL.downloads.mac.sha256" | tr 'A-F' 'a-f')"
size="$(extract "channels.$CHANNEL.downloads.mac.size")"
version="$(extract "channels.$CHANNEL.version")"
build="$(extract "channels.$CHANNEL.build")"

[ -n "$url" ] || fail "no Mac version has been published on the '$CHANNEL' channel yet."
case "$url" in "$PREFIX"*) ;; *) fail "the download address is not one of the Story Starter releases, so it was not used." ;; esac
case "$url" in *..*|*\?*|*\#*) fail "the download address looks wrong, so it was not used." ;; esac
printf '%s' "$sha" | grep -Eq '^[0-9a-f]{64}$' || fail "the update information has no checksum for the disk image, so it was not used."
printf '%s' "$size" | grep -Eq '^[0-9]+$' || fail "the update information has no size for the disk image, so it was not used."

dmg="$work/$(basename "$url")"
echo "Downloading Story Starter $version build $build ($(( size / 1048576 )) MB) ..."
curl -fL --proto '=https,file' --tlsv1.2 -o "$dmg" "$url" || fail "the download failed."

got_size="$(wc -c < "$dmg" | tr -d ' ')"
got_sha="$(shasum -a 256 "$dmg" | cut -d' ' -f1)"
if [ "$got_size" != "$size" ] || [ "$got_sha" != "$sha" ]; then
  fail "the downloaded file did not match its checksum, so nothing was installed."
fi
echo "Checked: the file matches the published checksum."

mnt="$work/mount"
mkdir -p "$mnt"
hdiutil attach -nobrowse -readonly -noverify -mountpoint "$mnt" "$dmg" -quiet >/dev/null \
  || fail "could not open the disk image."
app="$(find "$mnt" -maxdepth 2 -name '*.app' -type d | head -n 1)"
[ -n "$app" ] || fail "the disk image has no app in it."

if ! codesign --verify --deep --strict "$app" >/dev/null 2>&1; then
  if [ "$ALLOW_UNSIGNED" = "1" ]; then
    echo "WARNING: the app is not validly signed by Apple's rules; continuing because of --allow-unsigned." >&2
  else
    fail "the app is not validly signed, so it was not installed (use --allow-unsigned only for a test build)."
  fi
else
  echo "Checked: the app's Apple signature is valid."
fi

name="$(basename "$app")"
if [ -z "$DEST_DIR" ]; then
  if [ -w /Applications ]; then DEST_DIR="/Applications"; else DEST_DIR="$HOME/Applications"; fi
fi
mkdir -p "$DEST_DIR"
if pgrep -x "${name%.app}" >/dev/null 2>&1; then
  fail "Story Starter is running. Quit it (Story Starter > Quit), then run this again."
fi
rm -rf "$DEST_DIR/$name"
ditto "$app" "$DEST_DIR/$name" || fail "could not copy the app to $DEST_DIR."
echo "Installed: $DEST_DIR/$name"

if [ "$NO_START" = "1" ]; then
  echo "Not opened (--no-start)."
else
  open "$DEST_DIR/$name"
  echo "Opened Story Starter. From now on it updates itself."
fi
