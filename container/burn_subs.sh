#!/bin/bash
set -e

#save from cli arguments
BUCKET="$1"
SUBS_KEY="$2"
OUTBUCKET="$3"

#derive filenames, input files have the same name but different extensions - we're working off the .ass file
SUBS_FILENAME=$(basename "$SUBS_KEY")
BASE_NAME="${SUBS_FILENAME%.*}"
VIDEO_KEY="${BASE_NAME}.mp4"
OUTPUT_KEY="${BASE_NAME}_burned.mp4"

#local file names for processing
INPUT_VIDEO="input.mp4"
SUBS_FILE="subs.ass"
OUTPUT_VIDEO="output.mp4"

#download from s3
#aws s3 cp "s3://${BUCKET}/${VIDEO_KEY}" "$INPUT_VIDEO"
#aws s3 cp "s3://${BUCKET}/${SUBS_KEY}" "$SUBS_FILE"

#burn subtitles
echo "$INPUT_VIDEO + $SUBS_FILE = $OUTPUT_VIDEO"
ffmpeg -y -i "$INPUT_VIDEO" -vf "subtitles=${SUBS_FILE}" -c:a copy "$OUTPUT_VIDEO"

#upload result
aws s3 cp "$OUTPUT_VIDEO" "s3://${OUTBUCKET}/${OUTPUT_KEY}"

echo "Output uploaded to s3://${OUTBUCKET}/${OUTPUT_KEY}"