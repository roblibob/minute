#!/bin/sh
set -euo pipefail

SOURCE="$SRCROOT/Vendor/ffmpeg/ffmpeg"
LICENSE_TXT="$SRCROOT/Vendor/ffmpeg/LICENSE.txt"
LICENSE_LGPL21="$SRCROOT/Vendor/ffmpeg/COPYING.LGPLv2.1"
LICENSE_LGPL3="$SRCROOT/Vendor/ffmpeg/COPYING.LGPLv3"
NOTICE="$SRCROOT/Vendor/ffmpeg/NOTICE.txt"
DEST_DIR="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Resources"
DEST="$DEST_DIR/ffmpeg"

if [ ! -f "$SOURCE" ]; then
  echo "error: ffmpeg binary missing at $SOURCE. Build a static ffmpeg and place it there."
  exit 1
fi
LICENSE_SOURCE=""
if [ -f "$LICENSE_TXT" ]; then
  LICENSE_SOURCE="$LICENSE_TXT"
elif [ -f "$LICENSE_LGPL21" ]; then
  LICENSE_SOURCE="$LICENSE_LGPL21"
elif [ -f "$LICENSE_LGPL3" ]; then
  LICENSE_SOURCE="$LICENSE_LGPL3"
else
  echo "error: ffmpeg license missing. Provide LICENSE.txt or COPYING.LGPLv2.1 in Vendor/ffmpeg."
  exit 1
fi

mkdir -p "$DEST_DIR"
/usr/bin/install -m 0755 "$SOURCE" "$DEST"
/usr/bin/install -m 0644 "$LICENSE_SOURCE" "$DEST_DIR/ffmpeg.LICENSE.txt"

if [ -f "$NOTICE" ]; then
  /usr/bin/install -m 0644 "$NOTICE" "$DEST_DIR/ffmpeg.NOTICE.txt"
else
  /bin/cat <<'EOF' > "$DEST_DIR/ffmpeg.NOTICE.txt"
This app bundles the FFmpeg executable.
FFmpeg is licensed under the GNU Lesser General Public License.
See ffmpeg.LICENSE.txt for details.
EOF
fi

if /usr/bin/otool -L "$SOURCE" | /usr/bin/grep -E "/opt/homebrew|/usr/local" >/dev/null 2>&1; then
  echo "error: ffmpeg links to Homebrew libraries. Rebuild ffmpeg with --disable-autodetect and --disable-xlib."
  exit 1
fi

if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$DEST"
fi
