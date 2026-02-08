#!/bin/sh
set -euo pipefail

# Builds a minimal, LGPL-safe static ffmpeg binary for Minute.
#
# Hard constraints:
# - Must be redistributable under LGPL (NO GPL, NO nonfree)
# - Must support Minute's media import + analysis-only loudness normalization:
#   - Import video containers with audio tracks (MP4/MOV/M4A): mov demuxer + AAC/ALAC decoders
#   - Import common audio files: WAV/MP3/FLAC/OGG
#   - Output contract WAV: mono, 16 kHz, 16-bit PCM
#   - Run loudnorm filter (pass 1 + pass 2)
#   - Discard pass-1 output (null muxer)
#
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/Vendor/ffmpeg"
OUT_BIN="$OUT_DIR/ffmpeg"

# Usage:
#   scripts/build-ffmpeg-minute.sh [/path/to/ffmpeg/source]
#
# If omitted, we try common repo-relative locations. If none exist, require an explicit argument.
if [ "$#" -ge 1 ]; then
  FFMPEG_SRC="$1"
else
  if [ -d "$ROOT/ffmpeg" ] && [ -f "$ROOT/ffmpeg/configure" ]; then
    FFMPEG_SRC="$ROOT/ffmpeg"
  elif [ -d "$ROOT/../ffmpeg" ] && [ -f "$ROOT/../ffmpeg/configure" ]; then
    FFMPEG_SRC="$ROOT/../ffmpeg"
  else
    echo "error: ffmpeg source path not provided and no repo-relative default found" >&2
    echo "pass an explicit path: scripts/build-ffmpeg-minute.sh /path/to/ffmpeg" >&2
    exit 1
  fi
fi

WORK_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/minute-ffmpeg-build.XXXXXX")"
WORK_SRC="$WORK_DIR/ffmpeg-src"
PREFIX_DIR="$WORK_DIR/prefix"

echo "Building ffmpeg for Minute"
echo "- source: $FFMPEG_SRC"
echo "- build:  $WORK_SRC"
echo "- out:    $OUT_BIN"

if [ ! -d "$FFMPEG_SRC" ] || [ ! -f "$FFMPEG_SRC/configure" ]; then
  echo "error: ffmpeg source not found at: $FFMPEG_SRC" >&2
  exit 1
fi

mkdir -p "$OUT_DIR" "$PREFIX_DIR"

echo "Staging ffmpeg source (excluding .git)..."
if /usr/bin/command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude ".git" --exclude ".minute-build" --exclude ".minute-prefix" "$FFMPEG_SRC/" "$WORK_SRC/"
else
  # Fallback: ditto copies everything (including .git), but should still work.
  /usr/bin/ditto "$FFMPEG_SRC" "$WORK_SRC"
fi

cd "$WORK_SRC"

# Note: We use --disable-everything and explicitly enable only what Minute needs.
# We also disable networking and any auto-detected external libs.
CONFIG_FLAGS="\
  --prefix=$PREFIX_DIR \
  --enable-static \
  --disable-shared \
  --disable-debug \
  --disable-doc \
  --disable-autodetect \
  --disable-network \
  --disable-everything \
  --enable-ffmpeg \
  --disable-ffprobe \
  --disable-ffplay \
  --disable-gpl \
  --disable-nonfree \
  --enable-protocol=file \
  --enable-demuxer=wav \
  --enable-demuxer=mov \
  --enable-demuxer=mp3 \
  --enable-demuxer=flac \
  --enable-demuxer=ogg \
  --enable-demuxer=matroska \
  --enable-demuxer=aiff \
  --enable-demuxer=caf \
  --enable-decoder=pcm_s16le \
  --enable-decoder=aac \
  --enable-decoder=alac \
  --enable-decoder=mp3 \
  --enable-decoder=flac \
  --enable-decoder=opus \
  --enable-decoder=vorbis \
  --enable-parser=aac \
  --enable-parser=mpegaudio \
  --enable-parser=opus \
  --enable-parser=vorbis \
  --enable-parser=flac \
  --enable-muxer=wav \
  --enable-muxer=null \
  --enable-encoder=pcm_s16le \
  --enable-swresample \
  --enable-avfilter \
  --enable-filter=aresample \
  --enable-filter=loudnorm \
  --disable-iconv \
  --disable-videotoolbox \
  --disable-audiotoolbox \
  --disable-securetransport \
  --disable-zlib \
  --disable-bzlib \
  --disable-lzma \
  --disable-sdl2 \
  --disable-xlib \
  --disable-libxcb \
  --disable-asm"

echo "Configuring..."
# shellcheck disable=SC2086
./configure $CONFIG_FLAGS

CPU_COUNT="$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 4)"
make -j"$CPU_COUNT"

# Copy the binary into Vendor/ffmpeg.
# (We avoid make install to keep it simple and deterministic.)
if [ ! -f "$WORK_SRC/ffmpeg" ]; then
  echo "error: build succeeded but ffmpeg binary not found at $WORK_SRC/ffmpeg" >&2
  exit 1
fi

cp -f "$WORK_SRC/ffmpeg" "$OUT_BIN"
chmod 0755 "$OUT_BIN"

echo "Verifying ffmpeg capabilities..."

# Must have loudnorm filter
"$OUT_BIN" -hide_banner -filters | /usr/bin/grep -E "(^| )loudnorm( |$)" >/dev/null
# Must be able to read WAV
"$OUT_BIN" -hide_banner -demuxers | /usr/bin/grep -E "(^| )wav( |$)" >/dev/null
# Must be able to read MP4/MOV/M4A (ffmpeg reports this as 'mov,mp4,m4a,...')
"$OUT_BIN" -hide_banner -demuxers | /usr/bin/grep -E "(^| )mov(,| |$)" >/dev/null
# Must decode pcm_s16le
"$OUT_BIN" -hide_banner -decoders | /usr/bin/grep -E "(^| )pcm_s16le( |$)" >/dev/null
# Must decode AAC (common MP4/M4A audio codec)
"$OUT_BIN" -hide_banner -decoders | /usr/bin/grep -E "(^| )aac( |$)" >/dev/null
# Must have null muxer
"$OUT_BIN" -hide_banner -muxers | /usr/bin/grep -E "(^| )null( |$)" >/dev/null

echo "Verifying dynamic linkage (should not depend on Homebrew)..."
/usr/bin/otool -L "$OUT_BIN" | /usr/bin/grep -E "/opt/homebrew|/usr/local" >/dev/null 2>&1 && {
  echo "error: ffmpeg links to Homebrew libraries; rebuild failed the policy." >&2
  exit 1
} || true

echo "Done. Built: $OUT_BIN"
"$OUT_BIN" -hide_banner -version | head -n 3

echo "Build workspace left at: $WORK_DIR"
