import os

import requests
from dotenv import load_dotenv

load_dotenv()

TOKEN = os.getenv("INTERVALS_ICU_ACCESS")
URL="https://intervals.icu/api/v1"
HEADERS = {'authorization': f'Basic {TOKEN}'} #bearer only works for oauth on intervals.icu so we use an encoded username:pass where pass is the token

#request all activities based on date, filter to type: ride and return the first
def findActivity(targetDate):
    response = requests.get(
        f'{URL}/athlete/0/activities',
        headers=HEADERS,
        params={'oldest': targetDate, 'newest': targetDate},
        timeout=20
    )

    activities = response.json()

    for activity in activities:
        if activity['type'] == "Ride":
            return activity['id'], activity['name']

    print (f"No matched activity for {targetDate}")
    return None

def downloadFITFile(activityID, activityName):
    response = requests.get(
        f'{URL}/activity/{activityID}/fit-file',
        headers=HEADERS,
        timeout=20
    )

    with open(f'{activityName}.fit', "wb") as f:
        f.write(response.content)
