#this one goes in container, should probably be bash instead

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
