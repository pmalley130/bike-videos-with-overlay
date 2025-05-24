#!/bin/bash
set -e

#save from cli arguments
BUCKET="$1"
SUBS_KEY="$2"
OUTBUCKET="$3"

# Derive filenames
SUBS_FILENAME=$(basename "$SUBS_KEY")
BASE_NAME="${SUBS_FILENAME%.*}"
VIDEO_KEY="${BASE_NAME}.mp4"
OUTPUT_KEY="${BASE_NAME}_burned.mp4"

# Local file names
INPUT_VIDEO="input.mp4"
SUBS_FILE="subs.ass"
OUTPUT_VIDEO="output.mp4"

# Download files
aws s3 cp "s3://${BUCKET}/${VIDEO_KEY}" "$INPUT_VIDEO"
aws s3 cp "s3://${BUCKET}/${SUBS_KEY}" "$SUBS_FILE"

# Burn subtitles
ffmpeg -y -i "$INPUT_FILE" -vf "subtitles=${SUBS_FILE}" -c:a copy "$OUTPUT_VIDEO"

# Upload result
aws s3 cp "$OUTPUT_FILE" "s3://${OUTBUCKET}/${OUTPUT_KEY}"

echo "Output uploaded to s3://${OUTBUCKET}/${OUTPUT_KEY}"