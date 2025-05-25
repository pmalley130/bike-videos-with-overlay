import json
import os
import re
from datetime import UTC, timedelta

import boto3
import requests
from fitparse import FitFile

#create clients to retrieve intervals.icu API key from parameter store and handle s3 transfers
ssm = boto3.client("ssm")
s3 = boto3.client('s3')

#####GET FIT FILE HELPERS#####
#download and open the json file from s3
def loadJSON(bucket, key, jsonPath):
    s3.download_file(bucket, key, jsonPath)
    print(f"Downloaded file from s3://{bucket}/{key} to {jsonPath}")
    with open(jsonPath) as f:
        jsonFile = f.read()

    #load the jsonfile
    metadataJSON = json.loads(jsonFile)

    return metadataJSON

#retrieve token
def getToken():
    response = ssm.get_parameter(
        Name='/BIKE_VIDEO/INTERVALS_ICU_ACCESS',
        WithDecryption=True
    )
    return response['Parameter']['Value']

#set API endpoint
URL= "https://intervals.icu/api/v1"

#request all activities based on date, filter to type: ride and return the first
def findActivity(targetDate, headers):
    response = requests.get(
        f'{URL}/athlete/0/activities',
        headers=headers,
        params={'oldest': targetDate, 'newest': targetDate},
        timeout=20
    )

    response.raise_for_status()
    activities = response.json()

    for activity in activities:
        if activity['type'] == "Ride":
            return activity['id'], activity['name']

    print (f"No matched activity for {targetDate}")
    return None, None

#download file from intervals.icu
def downloadFITFile(activityID, activityName, headers):
    response = requests.get(
        f'{URL}/activity/{activityID}/fit-file',
        headers=headers,
        timeout=20
    )

    response.raise_for_status()

    fitPath = f"/tmp/{activityName}.fit"  # noqa: S108
    with open(fitPath, "wb") as f:
        f.write(response.content)

    return fitPath

#####CREATE SUBTITLE FILE HELPERS#####
#text at the top of ass header (replace with pysubs2 maybe?)
ASS_HEADER = """[Script Info]
Title: FIT Overlay
ScriptType: v4.00+
Collisions: Normal
PlayDepth: 0
Timer: 100.0000

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,24,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,1.5,0,2,50,50,50,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""

#helper to format time delta into something readable for subs file
def _formatASSTime(seconds):
    t = timedelta(seconds=seconds)
    totalSeconds = int(t.total_seconds())
    ms = int((t.total_seconds() - totalSeconds) * 100)
    hours = totalSeconds // 3600
    minutes = (totalSeconds % 3600) // 60
    seconds = totalSeconds % 60
    return f"{hours}:{minutes:02}:{seconds:02}.{ms:02}"

def generateASSFromFit(
        fitFile,
        assFileName,
        startEpoch,
        endEpoch,
        subsInterval = 1
):
    stats = FitFile(fitFile)
    records = []

    #save data from FIT file into list
    for record in stats.get_messages("record"):
        fields = {f.name: f.value for f in record}
        timestamp = fields.get("timestamp")
        #add timezone to timestamp, adjust for local time
        if timestamp is not None and timestamp.tzinfo is None:
            timestamp = timestamp.replace(tzinfo=UTC)
            timestamp = timestamp - timedelta(hours=4)
            timestampEpoch = timestamp.timestamp()

        if timestamp and startEpoch <= timestampEpoch <= endEpoch:
            deltaSeconds = timestampEpoch - startEpoch
            fields["deltaSeconds"] = deltaSeconds #save relative time from start of video as well
            records.append(fields)

    #build ass file
    lines = [ASS_HEADER]

    lastOverlay = -subsInterval

    for r in records:
        t = r["deltaSeconds"]

        #if it's been longer than the interval time make a new subs line
        if t - lastOverlay >= subsInterval:
            start = _formatASSTime(t)
            end = _formatASSTime(t + subsInterval)

            r['speed'] = r['speed'] * 2.23694 #convert m/s to mph

            text = ( #generate stats for the line
                f"Speed: {r.get('speed', 'N/A'):.1f} mph  "
                f"HR: {r.get('heart_rate', 'N/A')} bpm  "
                f"Cadence: {r.get('cadence', 'N/A')}  "
                f"Power: {r.get('power', 'N/A')} watts"
            )

            #write this intervals stats to subs
            dialogue = f"Dialogue: 0,{start},{end},Default,,0,0,0,,{text}\n"
            lines.append(dialogue)
            lastOverlay = t

    #write subs to file
    assPath = f"/tmp/{assFileName}.ass"  # noqa: S108

    with open(assPath, "w") as f:
        f.writelines(lines)

    print(f"Generated {assPath} with {len(records)} records")

    return assPath

#upload sub file to s3
def uploadToS3(filePath, bucket, key):
    with open(filePath, "rb") as f:
        s3.upload_fileobj(f, bucket, key)
    print(f"Uploaded {key} to bucket {bucket}")

####MAIN####
def lambda_handler(event, context):

    #get bucket and key from s3 event
    record = event['Records'][0]
    bucket = record['s3']['bucket']['name']
    key = record['s3']['object']['key']

    jsonPath = f"/tmp/{os.path.basename(key)}"  # noqa: S108

    #load
    metadataJSON = loadJSON(bucket, key, jsonPath)

    #create headers for intervals.icu API calls
    token = getToken()
    headers = {'authorization': f'Basic {token}'}

    #find the correct activity from intervals.icu
    activityID, activityName = findActivity(metadataJSON['date'], headers)

    #download the FIT file
    fitfilePath = downloadFITFile(activityID, activityName, headers)

    #get the name of the key sans extension for .ass file name
    match = re.search(r'([^/\\]+)\.[^./\\]+$', key)
    assFileName = match.group(1)
    assKey = assFileName + ".ass"

    #create the subtitle file
    assPath = generateASSFromFit(
        fitfilePath,
        assFileName,
        metadataJSON['startEpoch'],
        metadataJSON['endEpoch']
    )

    #upload subs to s3
    uploadToS3(assPath, bucket, assKey)
