# Bike Video Overlay Automation
Proof of concept to automate rendering stats from a FIT file over a video from an action camera. Nowhere near done.

## Requires
ffmpeg
MediaInfo
pymediainfo
pysub2
fitparse

### To-do
Methods to do:
  - all of the below is done but I need to refactor into epoch time
    - extract time metadata from mp4 to generate date, start, duration
      - this is going to prove tricky to do cheaply - date/start are at the top of the file but duration is at the end. may need two methods down the road. for now just grabbing the whole file
    - extract data from FIT file according to above metadata
      - eventually grab FIT from strava based on date
    - generate ASS subtitle file based on FIT data
  - render ASS subtitle onto video

Put the whole thing in a container and write Lambda functions for AWS to handle it upon uploading a video to S3
  
