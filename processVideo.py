from datetime import UTC, datetime, timedelta


#method to parse timestamps from insta go 3
#returns the date and the time
def _parseTimefromVideo(timeString):
    timeString = timeString.replace(" UTC", "")
    dt = datetime.strptime(timeString, "%Y-%m-%d %H:%M:%S.%f" if "." in timeString else "%Y-%m-%d %H:%M:%S")
    return dt.date(), dt.replace(tzinfo=UTC)

#method to save video metadata in datetime objects
def getVideoInfo(filename):
    from pymediainfo import MediaInfo

    videoinfo = MediaInfo.parse(filename)
    for track in videoinfo.tracks:
        if track.track_type == "General":
            date, startTime = _parseTimefromVideo(track.encoded_date)
            duration = timedelta(milliseconds=track.duration)
            endTime = startTime + duration
            videoMetadata = {
                "date":date,
                "startTime":startTime,
                "duration":duration,
                "endTime":endTime,
                "startEpoch":startTime.timestamp(),
                "endEpoch":endTime.timestamp()
            }
    return videoMetadata

def burnSubs(
        inputVideo,
        subsPath,
        outputPath,
):
    import subprocess
    cmd = [
        "ffmpeg", "-y",
        "-i", inputVideo,
        "-vf", f"subtitles={subsPath}",
        "-c:a", "copy",
        outputPath
    ]
    subprocess.run(cmd, check=True)

