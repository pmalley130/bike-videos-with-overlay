#base image
FROM ubuntu:22.04

#install ffmpeg and awscli
RUN apt-get update && \
    apt-get install -y ffmpeg curl unzip python3-pip && \
    pip3 install awscli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#set working directory
WORKDIR /app

#copy bash script into the image
COPY burn_subs.sh .

#make it executable
RUN chmod +x burn_subs.sh

#start here
ENTRYPOINT ["./burn_subs.sh"]