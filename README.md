# Bike Video Overlay Automation
Proof of concept to utilize AWS to automate rendering stats from a bike ride (FIT file) over a video from an Insta360Go camera. Infrastructure is built via Terraform.

![It might be ugly but it works!](/images/sample_image.jpg)

## Workflow
1. Users run a local interactive script <code>uploadtoS3.py</code> that extracts metadata from the video, then uploads both the video and a <code>json</code> file with required metadata for the next step.
2. A lambda function <code>.\lambdaFunctions\lambda_function.py</code>triggers that
    1. Downloads the <code>json</code> file to temp storage.
    2. Examines the <code>json</code> to get the date of the activity.
    3. Finds the matching activity on <code>intervals.icu</code> - the API key is stored securely in AWS Parameter Store.
    4. Downloads the <code>.fit</code> file via API.
    5. Generates a <code>.ass</code> subtitle file with the heart rate, power, cadence, and speed telemetries timed to the activities in the FIT file.
    6. Uploads the subtitle file to s3.
3. An EventBridge rule triggered by <code>.ass</code> upload starts a container <code>./container/burn_subs.sh</code> via Step Functions to render the subtitles onto the original video.
    1. The container downloads the original <code>.mp4</code> and the <code>.ass</code> telemetry subtitles to temp storage.
    2. It burns the telemetry into a new <code>.mp4</code> video.
    3. After rendering finishes it uploads the new <code>.mp4</code> to the output bucket.

## Requirements
- Locally for <code>uploadtoS3.py</code>
  ```
  pymediainfo
  AWSCLI
  See .env.example for needed environment variables
  ```


- For AWS
  ```
  Input s3 bucket
  Output s3 bucket
  Container image from ./container/ pushed to private ECR and named 'burn-subs'
  intervals.icu API code saved to '/BIKE_VIDEO/INTERVALS_ICU_ACCESS'
  See .\terraform\tfvars.example for needed variables for terraform
  ```


### To-do
- Package <code>uploadtoS3.py</code> with pyInstaller so it's portable.
- Add SNS email notification on completion.
- Terraform the <code>intervals.icu</code> API key into parameter store/reference it in tfvars.
- Fix the hard-coding of "burn-subs" in the ECS module.
- Make the stats prettier.
- Fix timing the subs to take breaks in the FIT file (due to breaks in riding!) into account.
- Change ECS type from FARGATE to EC2 (two reasons):
    - Use s3 endpoint for video data transactions.
    - Allow gpu for faster encoding (right now 8 vCPU and 32GB RAM renders 4k @ .7x - most of my videos are looong).

### Thanks
Thank you to the [Telemetry Overlay](https://goprotelemetryextractor.com/) team for spawning idea. This project was more about utilizing cloud infrastructure than the final product... mostly because there's no way in I'll ever beat out what their tool can do!
