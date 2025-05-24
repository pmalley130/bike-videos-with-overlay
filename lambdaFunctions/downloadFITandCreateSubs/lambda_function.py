import json
import os

import boto3
import requests

#create client to retrieve intervals.icu API key from parameter store
ssm = boto3.client("ssm")
s3 = boto3.client('s3')

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



def lambda_handler(event, context):

    #get bucket and key from s3 event
    record = event['Records'][0]
    bucket = record['s3']['bucket']['name']
    key = record['s3']['object']['key']

    jsonPath = f"/tmp/{os.path.basename(key)}"  # noqa: S108

    #download and open the json file from s3
    s3.download_file(bucket, key, jsonPath)
    print(f"Downloaded file from s3://{bucket}/{key} to {jsonPath}")
    with open(jsonPath) as f:
        jsonFile = f.read()

    #load the jsonfile
    metadataJSON = json.loads(jsonFile)

    token = getToken()
    headers = {'authorization': f'Basic {token}'}

    activityID, activityName = findActivity(metadataJSON['date'], headers)

    filePath = downloadFITFile(activityID, activityName, headers)

    print(filePath)
