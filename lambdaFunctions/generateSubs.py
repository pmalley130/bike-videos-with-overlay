from datetime import UTC, timedelta

from fitparse import FitFile

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
        assFile,
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
    with open(assFile, "w") as f:
        f.writelines(lines)

    print(f"Generated {assFile} with {len(records)} records")
