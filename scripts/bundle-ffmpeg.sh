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

# Verify the bundled ffmpeg build supports the audio operations Minute needs.
# We intentionally ship a small build, but it must be able to:
# - read contract WAV input (wav demuxer + pcm_s16le decoder)
# - run loudness analysis/normalization (loudnorm filter)
# - discard pass-1 output (null muxer)
# - import common video containers with audio tracks (MP4/MOV/M4A)
if ! "$SOURCE" -hide_banner -filters | /usr/bin/grep -E "(^| )loudnorm( |$)" >/dev/null 2>&1; then
  echo "error: ffmpeg build is missing the 'loudnorm' filter."
  echo "error: rebuild ffmpeg with --enable-filter=loudnorm (and required deps)."
  exit 1
fi

if ! "$SOURCE" -hide_banner -demuxers | /usr/bin/grep -E "(^| )wav( |$)" >/dev/null 2>&1; then
  echo "error: ffmpeg build is missing the 'wav' demuxer (cannot read contract WAV input)."
  echo "error: rebuild ffmpeg with --enable-demuxer=wav."
  exit 1
fi

if ! "$SOURCE" -hide_banner -demuxers | /usr/bin/grep -E "(^| )mov(,| |$)" >/dev/null 2>&1; then
  echo "error: ffmpeg build is missing the 'mov' demuxer (cannot import MP4/MOV/M4A files)."
  echo "error: rebuild ffmpeg with --enable-demuxer=mov."
  exit 1
fi

if ! "$SOURCE" -hide_banner -decoders | /usr/bin/grep -E "(^| )pcm_s16le( |$)" >/dev/null 2>&1; then
  echo "error: ffmpeg build is missing the 'pcm_s16le' decoder (cannot decode PCM WAV input)."
  echo "error: rebuild ffmpeg with --enable-decoder=pcm_s16le."
  exit 1
fi

if ! "$SOURCE" -hide_banner -decoders | /usr/bin/grep -E "(^| )aac( |$)" >/dev/null 2>&1; then
  echo "error: ffmpeg build is missing the 'aac' decoder (cannot import common MP4/M4A audio)."
  echo "error: rebuild ffmpeg with --enable-decoder=aac."
  exit 1
fi

if ! "$SOURCE" -hide_banner -muxers | /usr/bin/grep -E "(^| )null( |$)" >/dev/null 2>&1; then
  echo "error: ffmpeg build is missing the 'null' muxer (required for loudnorm analysis pass 1)."
  echo "error: rebuild ffmpeg with --enable-muxer=null."
  exit 1
fi

if ! "$SOURCE" -hide_banner -muxers | /usr/bin/grep -E "(^| )wav( |$)" >/dev/null 2>&1; then
  echo "error: ffmpeg build is missing the 'wav' muxer (cannot write normalized analysis WAV output)."
  echo "error: rebuild ffmpeg with --enable-muxer=wav."
  exit 1
fi

if ! "$SOURCE" -hide_banner -protocols | /usr/bin/grep -E "(^| )file( |$)" >/dev/null 2>&1; then
  echo "error: ffmpeg build is missing the 'file' protocol (cannot read/write local files)."
  echo "error: rebuild ffmpeg with --enable-protocol=file."
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
  /usr/bin/codesign --force --timestamp --options runtime --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$DEST"
fi
