import json
import os
import re
from datetime import UTC, datetime, timedelta

import boto3
from dotenv import load_dotenv

load_dotenv()

#method to parse timestamps from insta go 3
#returns the date and the time
def _parseTimefromVideo(timeString):
    timeString = timeString.replace(" UTC", "")
    dt = datetime.strptime(timeString, "%Y-%m-%d %H:%M:%S.%f" if "." in timeString else "%Y-%m-%d %H:%M:%S")
    return dt.date(), dt.replace(tzinfo=UTC)

#method to get video metadata in datetime objects
def getVideoInfo(filename):
    from pymediainfo import MediaInfo

    videoinfo = MediaInfo.parse(filename)
    for track in videoinfo.tracks:
        if track.track_type == "General":
            date, startTime = _parseTimefromVideo(track.encoded_date)
            duration = timedelta(milliseconds=track.duration)
            endTime = startTime + duration
            videoMetadata = {
                "date":date.isoformat(),
                "startTime":startTime.isoformat(),
                "duration":track.duration,
                "endTime":endTime.isoformat(),
                "startEpoch":startTime.timestamp(),
                "endEpoch":endTime.timestamp()
            }
    return videoMetadata

def uploadtoS3(filename, bucket, key):
    s3 = boto3.client('s3')

    with open(filename, "rb") as f:
        s3.upload_fileobj(f, bucket, key)
    print (f"Uploaded {filename} to s3://{bucket}/{key}")

def main():
    bucket = os.getenv("UPLOAD_BUCKET_NAME") #set bucket name
    print("Using bucket:", bucket)

    videoPath = input("Please enter full video path: ") #ask for filepath and validate it
    if not os.path.isfile(videoPath):
        raise FileNotFoundError(f"Video file '{videoPath}' does not exist.")

    match = re.search(r'([^/\\]+)\.[^./\\]+$', videoPath) #extract video name
    videoName = match.group(1)

    videoMetadata = getVideoInfo(videoPath) #get metadata

    metadataPath = f"{videoName}.json" #write metadata file
    print(metadataPath)
    with open(metadataPath, 'w') as f:
       json.dump(videoMetadata, f)

    #uploadtoS3(videoPath, bucket, f"{videoName}.mp4")
    #uploadtoS3(metadataPath, bucket, metadataPath)

if __name__ == "__main__":
    main()

